/**
 * Cliente do Jev (TypeSafe via OpenRouter, POST /api/alpha/decisions), isolado da UI.
 * Contrato: C:\SAP IA\zpoc_jev\jev-api.md
 *
 *  - buildRequest(oPedido): { state, questions }. O `model` e a chave sao definidos no SERVIDOR
 *    (ui5-middleware/jevProxy.js); o navegador nunca ve URL real nem chave.
 *    `state` em ingles, snake_case, agrupado (supplier, order, velocity, buyer, baseline), com
 *    fatos ja rotulados ao lado dos numeros. Lista branca: nunca SupplierName, Supplier,
 *    CreatedByUser, numero do pedido ou qualquer identificador.
 *  - parseResponse(oJson): valida a forma da resposta (type esperado e campos presentes) e
 *    mapeia para os parametros da acao registrarAvaliacao (4 casas). Qualquer desvio -> erro
 *    -> o chamador grava INDISPONIVEL. Nunca usa default.
 *  - avaliar(oPedido): POST na rota relativa /jev/decisions, timeout 1500 ms, max. 3 simultaneas.
 *    HTTP 4xx/5xx -> INDISPONIVEL:HTTP_<codigo>.
 */
sap.ui.define([], function () {
	"use strict";

	var TIMEOUT_MS = 1500;
	var MAX_CONCORRENTES = 3;
	var DEFAULT_ENDPOINT = "/jev/";
	var PATH_DECISIONS = "decisions";

	var CHAVES_NOUL = {
		fornecedor_ficticio: "ProbFornecedorFicticio",
		desvio_pagamento: "ProbDesvioPagamento",
		sobrepreco: "ProbSobrepreco",
		fracionamento: "ProbFracionamento",
		fraude_interna: "ProbFraudeInterna"
	};
	var OPCOES_ACAO = ["liberar", "aprovacao", "bloquear"];
	var NIVEIS_ATIPICIDADE = 5;
	/**
	 * Minimo de pedidos anteriores do fornecedor (24 meses) para que razoes/z-score/participacao
	 * sejam comparaveis. Abaixo disso o rotulo vira "insufficient_history" (o numero cru e mantido).
	 */
	var MIN_PEDIDOS_HISTORICO = 3;
	var SEM_HISTORICO = "insufficient_history";

	// ---------------------------------------------------------------- helpers puros

	function toNumber(v) {
		if (v === null || v === undefined || v === "") {
			return 0;
		}
		var n = typeof v === "number" ? v : parseFloat(v);
		return isFinite(n) ? n : 0;
	}

	function toInt(v) {
		return Math.round(toNumber(v));
	}

	// Edm.Boolean chega como boolean; Pedido.MaterialNewForSupplier chega como Edm.String(1) "X"/"".
	function toBool(v) {
		return v === true || v === "X" || v === "x" || v === "true";
	}

	function round4(v) {
		return Math.round(toNumber(v) * 10000) / 10000;
	}

	function round2(v) {
		return Math.round(toNumber(v) * 100) / 100;
	}

	/** Decimal(5,4) para o OData V4 (IEEE754Compatible): string com 4 casas. */
	function dec4(n) {
		return round4(n).toFixed(4);
	}

	/**
	 * Rotula uma razao vs referencia: 0 -> "not_comparable"; +-5% -> "in_line";
	 * ate 2x -> "20_pct_above" / "15_pct_below"; >= 2x -> "3.5x_reference".
	 */
	function rotuloRazao(r) {
		r = toNumber(r);
		if (r <= 0) {
			return "not_comparable";
		}
		if (r >= 2) {
			return Math.round(r * 10) / 10 + "x_reference";
		}
		var pct = Math.round((r - 1) * 100);
		if (Math.abs(pct) <= 5) {
			return "in_line";
		}
		return pct > 0 ? pct + "_pct_above" : -pct + "_pct_below";
	}

	function rotuloIdade(d) {
		d = toInt(d);
		if (d < 90) {
			return "under_90_days";
		}
		if (d < 365) {
			return "90_to_365_days";
		}
		return d < 1095 ? "1_to_3_years" : "over_3_years";
	}

	function rotuloZ(z) {
		z = toNumber(z);
		if (z === 0) {
			return "not_available_or_average";
		}
		var a = Math.abs(z);
		var s = a < 1 ? "within_1_std_dev" : a < 2 ? "1_to_2_std_dev" : a < 3 ? "2_to_3_std_dev" : "over_3_std_dev";
		return s + (z > 0 ? "_above" : "_below");
	}

	// ---------------------------------------------------------------- request

	/** state em ingles, so com indicadores (lista branca). */
	function rotuloParticipacao(pct) {
		pct = toNumber(pct);
		return pct < 20 ? "under_20_pct" : pct < 50 ? "20_to_50_pct" : pct < 80 ? "50_to_80_pct" : "over_80_pct";
	}

	function buildState(p) {
		var iDias = toInt(p.DaysSinceLastMDChange);
		var iMudancas = toInt(p.MasterDataChanges30d);
		// Historico do fornecedor curto demais: valor vs media, z-score e participacao no comprador
		// nao sao comparaveis. Nao ha contagem de pedidos do comprador no servico; usa o mesmo criterio.
		var bHistorico = toInt(p.SuplrHistPOCount) >= MIN_PEDIDOS_HISTORICO;
		return {
			supplier: {
				registration_age_days: toInt(p.SupplierAgeDays),
				registration_age: rotuloIdade(p.SupplierAgeDays),
				created_by_same_user_as_order: toBool(p.SupplierCreatorIsPOCreator),
				bank_or_address_changes_last_30_days: iMudancas,
				last_bank_or_address_change:
					iDias < 0 ? "none_in_last_30_days" : iDias <= 7 ? "within_7_days_of_order" : "8_to_30_days_before_order",
				bank_account_shared_with_other_suppliers: toBool(p.SharedBankAccount),
				other_suppliers_with_same_bank_account: toInt(p.SharedBankOtherCount)
			},
			order: {
				amount_vs_supplier_average_ratio: round4(p.AmountToSuplrAvgRatio),
				amount_vs_supplier_average: bHistorico ? rotuloRazao(p.AmountToSuplrAvgRatio) : SEM_HISTORICO,
				amount_z_score: round4(p.AmountZScore),
				amount_deviation: bHistorico ? rotuloZ(p.AmountZScore) : SEM_HISTORICO,
				price_vs_info_record_ratio: round4(p.MaxPriceToInfoRecordRatio),
				price_vs_info_record: rotuloRazao(p.MaxPriceToInfoRecordRatio),
				price_vs_material_history_ratio: round4(p.MaxPriceToMaterialAvgRatio),
				price_vs_material_history: rotuloRazao(p.MaxPriceToMaterialAvgRatio),
				quantity_vs_history_ratio: round4(p.MaxQtyToHistRatio),
				quantity_vs_history: rotuloRazao(p.MaxQtyToHistRatio),
				material_never_bought_from_supplier: toBool(p.MaterialNewForSupplier),
				payment_terms_differ_from_supplier_default: toBool(p.PaymentTermsDiverge),
				invoice_dated_before_order_creation: toBool(p.InvoiceBeforePO)
			},
			velocity: {
				other_orders_same_supplier_last_24h: toInt(p.SuplrPOCount24h),
				other_orders_same_supplier_last_7_days: toInt(p.SuplrPOCount7d)
			},
			buyer: {
				supplier_share_of_buyer_purchases_pct: round2(p.BuyerSupplierSharePct),
				supplier_share_of_buyer_purchases: bHistorico ? rotuloParticipacao(p.BuyerSupplierSharePct) : SEM_HISTORICO,
				buyer_posted_goods_receipt_for_this_order: toBool(p.CreatorPostedGR)
			},
			baseline: {
				supplier_prior_orders_24_months: toInt(p.SuplrHistPOCount),
				supplier_average_order_amount: round2(p.SuplrHistAvgAmount),
				supplier_order_amount_std_dev: round2(p.SuplrHistStdDevAmount),
				ratio_meaning: "ratio 1.0 = in line with history; 0 = no comparable history",
				insufficient_history_meaning:
					"insufficient_history = fewer than " + MIN_PEDIDOS_HISTORICO + " prior orders; the related number is not comparable and is not a deviation",
				history_window: "24 months before the order, same currency"
			}
		};
	}

	/** As 7 perguntas (chaves fixas em portugues = contrato com o ABAP; textos em ingles). */
	function buildQuestions() {
		return {
			fornecedor_ficticio: {
				type: "noul",
				instructions: {
					question: "Is the supplier likely a fictitious (shell) vendor created to divert money?",
					focus: "`supplier.registration_age`, `supplier.created_by_same_user_as_order`, `supplier.bank_account_shared_with_other_suppliers`, `supplier.other_suppliers_with_same_bank_account`, `baseline.supplier_prior_orders_24_months`"
				},
				criteria: {
					true: {
						what: "Supplier profile matches a shell vendor: recently registered, little or no history, bank account shared with other suppliers, or registered by the same user who orders from it.",
						examples: ["registration_age under_90_days and created_by_same_user_as_order true", "bank_account_shared_with_other_suppliers true with several other suppliers"]
					},
					false: {
						what: "Established supplier with order history, own bank account and independent registration.",
						not_for: "Do not answer true only because the order amount or price is unusual; that is a different question."
					}
				}
			},
			desvio_pagamento: {
				type: "noul",
				instructions: {
					question: "Is there a risk that the payment for this order is being diverted to a different beneficiary?",
					focus: "`supplier.bank_or_address_changes_last_30_days`, `supplier.last_bank_or_address_change`, `order.payment_terms_differ_from_supplier_default`, `supplier.bank_account_shared_with_other_suppliers`"
				},
				criteria: {
					true: {
						what: "Recent bank or address changes close to the order, payment terms changed from the supplier default, or a bank account shared with other suppliers.",
						examples: ["last_bank_or_address_change within_7_days_of_order", "payment_terms_differ_from_supplier_default true and recent bank change"]
					},
					false: {
						what: "No recent bank or address changes, standard payment terms and an exclusive bank account.",
						not_for: "Price or quantity anomalies alone do not indicate payment diversion."
					}
				}
			},
			sobrepreco: {
				type: "noul",
				instructions: {
					question: "Is the order overpriced compared with the reference prices?",
					focus: "`order.price_vs_info_record`, `order.price_vs_material_history`, `order.amount_deviation`",
					compare: "Compare the order price labels with the reference (in_line = normal)."
				},
				criteria: {
					true: {
						what: "Unit price clearly above the purchasing info record or the material price history.",
						examples: ["price_vs_info_record 20_pct_above", "price_vs_material_history 1.5x_reference"]
					},
					false: {
						what: "Price in line with or below the references, or no comparable reference.",
						not_for: "A high total amount caused by a large quantity is not overpricing."
					}
				}
			},
			fracionamento: {
				type: "noul",
				instructions: {
					question: "Is this order likely part of a purchase split into several smaller orders to avoid approval limits?",
					focus: "`velocity.other_orders_same_supplier_last_24h`, `velocity.other_orders_same_supplier_last_7_days`, `order.quantity_vs_history`"
				},
				criteria: {
					true: {
						what: "Several other orders to the same supplier within days, especially with quantities below the usual.",
						examples: ["other_orders_same_supplier_last_7_days 3 or more", "other_orders_same_supplier_last_24h 1 or more with quantity_vs_history below normal"]
					},
					false: {
						what: "Isolated order with no other recent orders to the same supplier.",
						not_for: "Regular recurring orders with normal quantities spread over time."
					}
				}
			},
			fraude_interna: {
				type: "noul",
				instructions: {
					question: "Is there a sign of internal fraud or collusion by the buyer who created the order?",
					focus: "`buyer.buyer_posted_goods_receipt_for_this_order`, `order.invoice_dated_before_order_creation`, `supplier.created_by_same_user_as_order`, `buyer.supplier_share_of_buyer_purchases`"
				},
				criteria: {
					true: {
						what: "Segregation-of-duties breaks: the buyer also posted the goods receipt, registered the supplier, or the invoice predates the order; high concentration of the buyer's purchases in this supplier reinforces it.",
						examples: ["buyer_posted_goods_receipt_for_this_order true", "invoice_dated_before_order_creation true"]
					},
					false: {
						what: "Duties are segregated and the document flow is in the normal order.",
						not_for: "High supplier share alone is not enough, and `buyer.supplier_share_of_buyer_purchases` = insufficient_history is not a signal at all (too few orders to compare)."
					}
				}
			},
			atipicidade: {
				type: "score",
				instructions: {
					question: "How atypical is this purchase order compared with the supplier and material history in `baseline` and the labels in `order` and `velocity`?",
					inspect: "Any label equal to insufficient_history (see `baseline.insufficient_history_meaning`) means there is not enough history to compare: it is NOT a deviation and must not raise the level. Large raw ratios next to insufficient_history are not comparable."
				},
				criteria: [
					{ what: "Typical: all indicators in line with history." },
					{ what: "Slightly unusual: one minor deviation." },
					{ what: "Unusual: one clear deviation or a few minor ones." },
					{ what: "Highly unusual: several clear deviations." },
					{ what: "Extremely atypical: many strong deviations at once." }
				]
			},
			// acao: SO SINAL DE COMPARACAO. A classificacao oficial (LIBERA/APROVACAO/BLOQUEIA) e
			// calculada no ABAP pelos limiares sobre as 5 probabilidades; a sugestao do modelo e apenas
			// gravada (JevAcaoSugerida/JevProb*) para comparar com a regra. Nunca decide nada.
			acao: {
				type: "choice",
				instructions: "Which handling would a procurement fraud analyst recommend for this purchase order, given all indicators in the state?",
				criteria: {
					liberar: { what: "Release: no relevant risk signal.", not_for: "Orders with any strong fraud signal." },
					aprovacao: { what: "Send to additional approval: some risk signals that a human should review." },
					bloquear: { what: "Block for investigation: strong or combined fraud signals.", examples: ["shared bank account plus recent bank change", "buyer posted goods receipt and invoice predates order"] }
				}
			}
		};
	}

	/**
	 * Monta o corpo enviado ao proxy /jev (sem `model`: o servidor define).
	 * @param {object} p propriedades do Pedido (OData V4)
	 */
	function buildRequest(p) {
		return { state: buildState(p || {}), questions: buildQuestions() };
	}

	// ---------------------------------------------------------------- response

	function erro(s) {
		return new Error("RESPOSTA_INVALIDA: " + s);
	}

	function probValida(v, sNome) {
		if (typeof v !== "number" || !isFinite(v) || v < 0 || v > 1) {
			throw erro(sNome + " fora de 0..1");
		}
		return v;
	}

	/**
	 * Valida a resposta 200 do Jev e mapeia para os parametros da acao (jev-api.md, "Mapeamento").
	 * @throws {Error} qualquer desvio de forma
	 */
	function parseResponse(j) {
		if (!j || typeof j !== "object" || !j.answers || typeof j.answers !== "object") {
			throw erro("sem answers");
		}
		if (typeof j.model !== "string" || !j.model) {
			throw erro("sem model");
		}
		var a = j.answers;
		var m = { JevDisponivel: true };

		Object.keys(CHAVES_NOUL).forEach(function (k) {
			var r = a[k];
			if (!r || r.type !== "noul") {
				throw erro(k + " nao e noul");
			}
			m[CHAVES_NOUL[k]] = dec4(probValida(r.noul, k));
		});

		var s = a.atipicidade;
		if (!s || s.type !== "score" || typeof s.score !== "number" || !isFinite(s.score)) {
			throw erro("atipicidade nao e score");
		}
		var iAtip = Math.round(s.score) + 1;
		if (iAtip < 1 || iAtip > NIVEIS_ATIPICIDADE) {
			throw erro("atipicidade fora de 0..4");
		}
		m.Atipicidade = iAtip;

		var c = a.acao;
		if (!c || c.type !== "choice" || OPCOES_ACAO.indexOf(c.choice) < 0 || !c.probabilities) {
			throw erro("acao nao e choice valido");
		}
		m.JevAcaoSugerida = c.choice.toUpperCase();
		m.JevProbLiberar = dec4(probValida(c.probabilities.liberar, "acao.liberar"));
		m.JevProbAprovacao = dec4(probValida(c.probabilities.aprovacao, "acao.aprovacao"));
		m.JevProbBloquear = dec4(probValida(c.probabilities.bloquear, "acao.bloquear"));

		m.JevModeloVersao = j.model.slice(0, 30);
		return m;
	}

	/** Custo (USD) informado em usage.cost, ou null. */
	function extrairCusto(j) {
		var n = j && j.usage && j.usage.cost;
		return typeof n === "number" && isFinite(n) ? n : null;
	}

	/** Parametros da acao quando o Jev esta indisponivel (ou nao deve ser chamado). */
	function parametrosIndisponivel(sMotivo) {
		return {
			JevDisponivel: false,
			ProbFornecedorFicticio: "0.0000",
			ProbDesvioPagamento: "0.0000",
			ProbSobrepreco: "0.0000",
			ProbFracionamento: "0.0000",
			ProbFraudeInterna: "0.0000",
			Atipicidade: 0,
			JevAcaoSugerida: "",
			JevProbLiberar: "0.0000",
			JevProbAprovacao: "0.0000",
			JevProbBloquear: "0.0000",
			JevModeloVersao: String(sMotivo || "INDISPONIVEL").slice(0, 30)
		};
	}

	// ---------------------------------------------------------------- limite de concorrencia

	function createLimiter(iMax) {
		var iAtivos = 0;
		var aFila = [];
		function proximo() {
			if (iAtivos >= iMax || aFila.length === 0) {
				return;
			}
			var oJob = aFila.shift();
			iAtivos++;
			Promise.resolve()
				.then(oJob.fn)
				.then(oJob.resolve, oJob.reject)
				.then(function () {
					iAtivos--;
					proximo();
				});
		}
		return {
			run: function (fn) {
				return new Promise(function (resolve, reject) {
					aFila.push({ fn: fn, resolve: resolve, reject: reject });
					proximo();
				});
			}
		};
	}

	var oLimiter = createLimiter(MAX_CONCORRENTES);
	var sEndpoint = DEFAULT_ENDPOINT;
	var mHeadersExtra = {};

	/**
	 * Chama o Jev. Resolve com { ok:true, params, custoUsd, latenciaMs, request, response }
	 * ou { ok:false, motivo, detalhe, latenciaMs, request } - nunca rejeita (falha segura).
	 * motivo: TIMEOUT | HTTP_<status> | RESPOSTA_INVALIDA | ERRO_REDE
	 */
	function avaliar(oPedido, mOpcoes) {
		mOpcoes = mOpcoes || {};
		var oRequest = buildRequest(oPedido);
		var fnFetch = mOpcoes.fetch || (typeof fetch === "function" ? fetch : null);
		var iTimeout = mOpcoes.timeoutMs || TIMEOUT_MS;

		return oLimiter.run(function () {
			var t0 = Date.now();
			if (!fnFetch) {
				return { ok: false, motivo: "SEM_FETCH", latenciaMs: 0, request: oRequest };
			}
			var oCtrl = new AbortController();
			var hTimer = setTimeout(function () {
				oCtrl.abort();
			}, iTimeout);
			var mHeaders = Object.assign({ "Content-Type": "application/json", Accept: "application/json" }, mHeadersExtra);

			return fnFetch(sEndpoint + PATH_DECISIONS, {
				method: "POST",
				headers: mHeaders,
				body: JSON.stringify(oRequest),
				signal: oCtrl.signal,
				credentials: "same-origin"
			})
				.then(function (oResp) {
					if (!oResp.ok) {
						var e = new Error("HTTP_" + oResp.status);
						e.motivo = "HTTP_" + oResp.status;
						throw e;
					}
					return oResp.json().catch(function () {
						throw erro("corpo nao e JSON");
					});
				})
				.then(function (oJson) {
					return {
						ok: true,
						params: parseResponse(oJson),
						custoUsd: extrairCusto(oJson),
						latenciaMs: Date.now() - t0,
						request: oRequest,
						response: oJson
					};
				})
				.catch(function (oErr) {
					var sMsg = String((oErr && oErr.message) || "");
					var sMotivo;
					if ((oErr && oErr.name === "AbortError") || oCtrl.signal.aborted) {
						sMotivo = "TIMEOUT";
					} else if (oErr && oErr.motivo) {
						sMotivo = oErr.motivo;
					} else if (sMsg.indexOf("RESPOSTA_INVALIDA") === 0) {
						sMotivo = "RESPOSTA_INVALIDA";
					} else {
						sMotivo = "ERRO_REDE";
					}
					return { ok: false, motivo: sMotivo, detalhe: sMsg, latenciaMs: Date.now() - t0, request: oRequest };
				})
				.finally(function () {
					clearTimeout(hTimer);
				});
		});
	}

	return {
		TIMEOUT_MS: TIMEOUT_MS,
		MAX_CONCORRENTES: MAX_CONCORRENTES,
		MIN_PEDIDOS_HISTORICO: MIN_PEDIDOS_HISTORICO,
		buildRequest: buildRequest,
		buildState: buildState,
		parseResponse: parseResponse,
		extrairCusto: extrairCusto,
		parametrosIndisponivel: parametrosIndisponivel,
		createLimiter: createLimiter,
		avaliar: avaliar,
		rotuloRazao: rotuloRazao,
		/** Endpoint relativo (manifest, dataSource jevApi) e headers extras (so o simulador os usa). */
		configure: function (m) {
			if (m && m.endpoint) {
				sEndpoint = m.endpoint.charAt(m.endpoint.length - 1) === "/" ? m.endpoint : m.endpoint + "/";
			}
			if (m && m.headers) {
				mHeadersExtra = Object.assign({}, m.headers);
			}
		}
	};
});

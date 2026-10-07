/**
 * Explica a ULTIMA AVALIACAO GRAVADA de um pedido em linguagem simples (secao "Jev (modo sombra)").
 *
 * Modulo puro (sem controles nem OData): roda no navegador e no Node (test/unit/Explicacao.test.js).
 * Nao contem textos: devolve CHAVES do i18n + argumentos; o controller resolve com o ResourceBundle.
 * Assim os textos ficam no i18n (pt-BR) e a logica fica testavel.
 */
sap.ui.define(["zpocjev/antifraude/jev/JevClient"], function (JevClient) {
	"use strict";

	var LIMIAR_APROVACAO_PADRAO = 0.2;
	var LIMIAR_BLOQUEIO_PADRAO = 0.6;
	var LIMIAR_PRECO_ACIMA = 1.05; // mesmo corte do semaforo PriceCriticality (amarelo)
	var LIMIAR_VALOR_VS_MEDIA = 1.5;
	var IDADE_FORNECEDOR_NOVO_DIAS = 90;

	/** Classificacao ABAP -> veredito. estado = sap.ui.core.ValueState; cor = sap.ui.core.IconColor. */
	var VEREDITOS = {
		LIBERA: { titulo: "vereditoLibera", etiqueta: "etiquetaLibera", estado: "Success", cor: "Positive", icone: "sap-icon://sys-enter-2" },
		APROVACAO: { titulo: "vereditoAprovacao", etiqueta: "etiquetaAprovacao", estado: "Warning", cor: "Critical", icone: "sap-icon://alert" },
		BLOQUEIA: { titulo: "vereditoBloqueia", etiqueta: "etiquetaBloqueia", estado: "Error", cor: "Negative", icone: "sap-icon://error" },
		BLOQUEIO_REGRA: { titulo: "vereditoBloqueioRegra", etiqueta: "etiquetaBloqueioRegra", estado: "Error", cor: "Negative", icone: "sap-icon://locked" },
		INDISPONIVEL: { titulo: "vereditoIndisponivel", etiqueta: "etiquetaIndisponivel", estado: "Information", cor: "Neutral", icone: "sap-icon://message-information" }
	};

	/** ChaveRiscoMax / chave do risco -> [campo da Avaliacao, chave i18n do rotulo simples]. */
	var RISCOS = [
		{ chave: "FORNECEDOR_FICTICIO", campo: "ProbFornecedorFicticio", rotulo: "riscoFornecedorFicticio" },
		{ chave: "DESVIO_PAGAMENTO", campo: "ProbDesvioPagamento", rotulo: "riscoDesvioPagamento" },
		{ chave: "SOBREPRECO", campo: "ProbSobrepreco", rotulo: "riscoSobrepreco" },
		{ chave: "FRACIONAMENTO", campo: "ProbFracionamento", rotulo: "riscoFracionamento" },
		{ chave: "FRAUDE_INTERNA", campo: "ProbFraudeInterna", rotulo: "riscoFraudeInterna" }
	];

	var SUGESTOES = {
		LIBERAR: { rotulo: "sugestaoLiberar", campo: "JevProbLiberar" },
		APROVACAO: { rotulo: "sugestaoAprovacao", campo: "JevProbAprovacao" },
		BLOQUEAR: { rotulo: "sugestaoBloquear", campo: "JevProbBloquear" }
	};

	// ---------------------------------------------------------------- helpers

	function num(v) {
		var n = typeof v === "number" ? v : parseFloat(v);
		return isFinite(n) ? n : 0;
	}

	function bool(v) {
		return v === true || v === "X" || v === "x" || v === "true";
	}

	/** 0..1 -> inteiro 0..100 */
	function pct(p) {
		return Math.round(num(p) * 100);
	}

	/** Numero com 1 casa e virgula decimal (pt-BR). */
	function dec1(n) {
		return (Math.round(num(n) * 10) / 10).toFixed(1).replace(".", ",");
	}

	function t(sKey, aArgs) {
		return { key: sKey, args: aArgs || [] };
	}

	function limiares(oAval) {
		var a = num(oAval && oAval.LimiarAprovacaoUsado);
		var b = num(oAval && oAval.LimiarBloqueioUsado);
		return {
			aprovacao: a > 0 ? a : LIMIAR_APROVACAO_PADRAO,
			bloqueio: b > 0 ? b : LIMIAR_BLOQUEIO_PADRAO
		};
	}

	// ---------------------------------------------------------------- veredito

	/** @returns {{titulo,etiqueta,estado,cor,icone}} (desconhecida -> como INDISPONIVEL) */
	function veredito(sClassificacao) {
		return VEREDITOS[sClassificacao] || VEREDITOS.INDISPONIVEL;
	}

	/**
	 * Motivo amigavel de uma avaliacao INDISPONIVEL, a partir do JevModeloVersao
	 * gravado pelo front ("INDISPONIVEL:TIMEOUT", "INDISPONIVEL:HTTP_402", ...).
	 * @returns {{key,args}|null}
	 */
	function motivoIndisponivel(sModeloVersao) {
		var s = String(sModeloVersao || "");
		var m = /HTTP_(\d{3})/.exec(s);
		if (s.indexOf("TIMEOUT") >= 0) {
			return t("motivoTimeout");
		}
		if (m) {
			var c = Number(m[1]);
			if (c === 402) {
				return t("motivoSemCreditos");
			}
			if (c === 401 || c === 403) {
				return t("motivoAcesso");
			}
			if (c === 429) {
				return t("motivoLimite");
			}
			if (c >= 500) {
				return t("motivoServicoFora");
			}
			return t("motivoPedidoRecusado");
		}
		if (s.indexOf("ERRO_REDE") >= 0 || s.indexOf("SEM_FETCH") >= 0) {
			return t("motivoRede");
		}
		if (s.indexOf("RESPOSTA_INVALIDA") >= 0) {
			return t("motivoRespostaInvalida");
		}
		return t("motivoDesconhecido");
	}

	/** A avaliacao tem probabilidades do Jev (LIBERA/APROVACAO/BLOQUEIA)? */
	function temRiscos(oAval) {
		return !!oAval && ["LIBERA", "APROVACAO", "BLOQUEIA"].indexOf(oAval.Classificacao) >= 0;
	}

	// ---------------------------------------------------------------- riscos

	/** Cor da barra pelos limiares gravados: < aprovacao verde; <= bloqueio amarelo; acima vermelho. */
	function estadoBarra(p, nAprovacao, nBloqueio) {
		p = num(p);
		if (p < nAprovacao) {
			return "Success";
		}
		return p <= nBloqueio ? "Warning" : "Error";
	}

	/** Os 5 riscos, do maior para o menor (empate: ordem fixa). */
	function riscos(oAval) {
		var l = limiares(oAval);
		return RISCOS.map(function (r, i) {
			var p = num(oAval[r.campo]);
			return { chave: r.chave, rotulo: r.rotulo, prob: p, pct: pct(p), estado: estadoBarra(p, l.aprovacao, l.bloqueio), ordem: i };
		}).sort(function (a, b) {
			return b.prob - a.prob || a.ordem - b.ordem;
		});
	}

	/** Legenda com os limiares reais: [pct aprovacao, pct bloqueio]. */
	function legenda(oAval) {
		var l = limiares(oAval);
		return t("legendaRiscos", [pct(l.aprovacao), pct(l.bloqueio)]);
	}

	/**
	 * Frase do "por que". Usa ChaveRiscoMax/RiscoMax gravados pelo ABAP.
	 * @returns {{key,args,rotulo}|null} rotulo = chave i18n do risco (o controller resolve e injeta em args[0])
	 */
	function porQue(oAval) {
		if (!temRiscos(oAval)) {
			return null;
		}
		var r = RISCOS.filter(function (x) {
			return x.chave === oAval.ChaveRiscoMax;
		})[0];
		if (!r) {
			return null;
		}
		var nRisco = oAval.RiscoMax !== undefined && oAval.RiscoMax !== null ? num(oAval.RiscoMax) : num(oAval[r.campo]);
		var sKey = oAval.Classificacao === "LIBERA" ? "porQueLibera" : "porQuePrincipal";
		return { key: sKey, args: [null, pct(nRisco)], rotulo: r.rotulo };
	}

	/** Sugestao do modelo (so informativa) -> {rotulo, pct} ou null. */
	function sugestao(oAval) {
		var s = oAval && SUGESTOES[String(oAval.JevAcaoSugerida || "").toUpperCase()];
		if (!s || !bool(oAval.JevDisponivel)) {
			return null;
		}
		return { rotulo: s.rotulo, pct: pct(oAval[s.campo]) };
	}

	// ---------------------------------------------------------------- sinais do pedido

	/** Campos do Pedido usados nos sinais (para o $select do controller). */
	var CAMPOS_SINAIS = [
		"SupplierAgeDays",
		"SupplierCreatorIsPOCreator",
		"SharedBankAccount",
		"SharedBankOtherCount",
		"MasterDataChanges30d",
		"MaxPriceToInfoRecordRatio",
		"MaxPriceToMaterialAvgRatio",
		"SuplrPOCount7d",
		"SuplrPOCount24h",
		"MaterialNewForSupplier",
		"PaymentTermsDiverge",
		"InvoiceBeforePO",
		"CreatorPostedGR",
		"AmountToSuplrAvgRatio",
		"SuplrHistPOCount"
	];

	function plural(n, sSingular, sPlural, aArgs) {
		return t(n === 1 ? sSingular : sPlural, aArgs);
	}

	/**
	 * Sinais que "acenderam" nos indicadores do Pedido, em linguagem simples.
	 * @returns {Array<{key,args}>} vazio = nenhum sinal
	 */
	function sinais(p) {
		p = p || {};
		var a = [];
		var n;

		var iIdade = Math.round(num(p.SupplierAgeDays));
		if (p.SupplierAgeDays !== undefined && iIdade < IDADE_FORNECEDOR_NOVO_DIAS) {
			a.push(iIdade <= 0 ? t("sinalFornecedorNovo0") : plural(iIdade, "sinalFornecedorNovo1", "sinalFornecedorNovo", [iIdade]));
		}
		if (bool(p.SupplierCreatorIsPOCreator)) {
			a.push(t("sinalMesmaPessoaFornecedor"));
		}
		if (bool(p.SharedBankAccount)) {
			n = Math.round(num(p.SharedBankOtherCount));
			a.push(n > 0 ? plural(n, "sinalContaCompartilhada1", "sinalContaCompartilhada", [n]) : t("sinalContaCompartilhadaSemN"));
		}
		n = Math.round(num(p.MasterDataChanges30d));
		if (n > 0) {
			a.push(plural(n, "sinalAlteracoesCadastro1", "sinalAlteracoesCadastro", [n]));
		}
		if (num(p.MaxPriceToInfoRecordRatio) > LIMIAR_PRECO_ACIMA) {
			a.push(t("sinalPrecoRegistroInfo", [Math.round((num(p.MaxPriceToInfoRecordRatio) - 1) * 100)]));
		}
		if (num(p.MaxPriceToMaterialAvgRatio) > LIMIAR_PRECO_ACIMA) {
			a.push(t("sinalPrecoMediaMaterial", [Math.round((num(p.MaxPriceToMaterialAvgRatio) - 1) * 100)]));
		}
		var n7 = Math.round(num(p.SuplrPOCount7d));
		var n24 = Math.round(num(p.SuplrPOCount24h));
		if (n24 > 0) {
			a.push(t(n24 === 1 ? "sinalPedidos24h1" : "sinalPedidos24h", [n24, n7]));
		} else if (n7 > 0) {
			a.push(plural(n7, "sinalPedidos7d1", "sinalPedidos7d", [n7]));
		}
		if (bool(p.MaterialNewForSupplier)) {
			a.push(t("sinalMaterialNovo"));
		}
		if (bool(p.PaymentTermsDiverge)) {
			a.push(t("sinalCondicaoPagamento"));
		}
		if (bool(p.InvoiceBeforePO)) {
			a.push(t("sinalFaturaAntes"));
		}
		if (bool(p.CreatorPostedGR)) {
			a.push(t("sinalCriadorEntrada"));
		}
		// valor vs media do fornecedor: so com historico suficiente (mesma regra do payload do Jev)
		if (num(p.SuplrHistPOCount) >= JevClient.MIN_PEDIDOS_HISTORICO && num(p.AmountToSuplrAvgRatio) >= LIMIAR_VALOR_VS_MEDIA) {
			a.push(t("sinalValorMedia", [dec1(p.AmountToSuplrAvgRatio)]));
		}
		return a;
	}

	return {
		CAMPOS_SINAIS: CAMPOS_SINAIS,
		LIMIAR_PRECO_ACIMA: LIMIAR_PRECO_ACIMA,
		veredito: veredito,
		motivoIndisponivel: motivoIndisponivel,
		temRiscos: temRiscos,
		estadoBarra: estadoBarra,
		riscos: riscos,
		legenda: legenda,
		porQue: porQue,
		sugestao: sugestao,
		sinais: sinais,
		pct: pct
	};
});

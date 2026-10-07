/**
 * Extensao da Object Page do Pedido: botao "Avaliar com Jev" (modo sombra) e a secao
 * "Jev (modo sombra)", que explica a ULTIMA AVALIACAO GRAVADA no S/4 em linguagem simples.
 *
 * Hooks: onInit e routing.onAfterBinding (Routing controller extension do FE, publico desde 1.90).
 * O handler onAvaliar e referenciado no manifest como
 * ".extension.zpocjev.antifraude.ext.controller.ObjectPageExt.onAvaliar".
 * A logica de explicacao fica em jev/Explicacao.js (pura, testada em Node).
 */
sap.ui.define(
	[
		"sap/ui/core/mvc/ControllerExtension",
		"sap/ui/model/json/JSONModel",
		"sap/ui/model/Sorter",
		"sap/ui/core/format/DateFormat",
		"sap/m/MessageToast",
		"sap/m/MessageBox",
		"sap/base/Log",
		"zpocjev/antifraude/jev/JevClient",
		"zpocjev/antifraude/jev/AvaliacaoService",
		"zpocjev/antifraude/jev/Explicacao"
	],
	function (ControllerExtension, JSONModel, Sorter, DateFormat, MessageToast, MessageBox, Log, JevClient, AvaliacaoService, Explicacao) {
		"use strict";

		var CAMPOS_AVALIACAO = [
			"EvaluationUUID",
			"EvaluatedAt",
			"EvaluatedBy",
			"Classificacao",
			"ChaveRiscoMax",
			"RiscoMax",
			"LimiarAprovacaoUsado",
			"LimiarBloqueioUsado",
			"JevDisponivel",
			"ProbFornecedorFicticio",
			"ProbDesvioPagamento",
			"ProbSobrepreco",
			"ProbFracionamento",
			"ProbFraudeInterna",
			"Atipicidade",
			"JevAcaoSugerida",
			"JevProbLiberar",
			"JevProbAprovacao",
			"JevProbBloquear",
			"JevModeloVersao"
		];

		var oFormatoDataHora = DateFormat.getDateTimeInstance({ style: "medium" });

		function estadoInicial() {
			return {
				busy: false,
				carregando: false,
				carregado: false,
				avaliado: false,
				veredito: null,
				porQue: "",
				mostrarRiscos: false,
				riscos: [],
				legenda: "",
				sinais: [],
				rodape: "",
				ultima: null,
				timeoutMs: JevClient.TIMEOUT_MS
			};
		}

		return ControllerExtension.extend("zpocjev.antifraude.ext.controller.ObjectPageExt", {
			override: {
				onInit: function () {
					this.base.getView().setModel(new JSONModel(estadoInicial()), "jev");
					var sEndpoint = this.base.getAppComponent().getManifestEntry("/sap.app/dataSources/jevApi/uri");
					// ?jev-sim=timeout|erro|ok na URL forca o comportamento do SIMULADOR (demonstracao)
					var sSim = new URLSearchParams(window.location.search).get("jev-sim");
					JevClient.configure({ endpoint: sEndpoint, headers: sSim ? { "X-Jev-Sim": sSim } : {} });
				},
				routing: {
					onAfterBinding: function (oContext) {
						this._carregarExplicacao(oContext);
					}
				}
			},

			_texto: function (sKey, aArgs) {
				var oView = this.base.getView();
				var oModel = oView.getModel("i18n") || this.base.getAppComponent().getModel("i18n");
				return oModel.getResourceBundle().getText(sKey, aArgs);
			},

			_t: function (o) {
				return o ? this._texto(o.key, o.args) : "";
			},

			/** Le a ultima avaliacao gravada + indicadores do pedido e monta o modelo "jev". */
			_carregarExplicacao: function (oContext, bNovaTentativa) {
				var that = this;
				var oJev = this.base.getView().getModel("jev");
				if (!oContext || !oContext.getPath) {
					return Promise.resolve();
				}
				var sPath = oContext.getPath();
				var iSeq = (this._iSeq = (this._iSeq || 0) + 1);
				var oModel = oContext.getModel();
				// Preserva os detalhes tecnicos da sessao so para o mesmo pedido
				var oUltima = this._sPathUltima === sPath ? oJev.getProperty("/ultima") : null;
				oJev.setData(Object.assign(estadoInicial(), { carregando: true, busy: oJev.getProperty("/busy"), ultima: oUltima }));

				var oLista = oModel.bindList(sPath + "/_Avaliacao", null, [new Sorter("EvaluatedAt", true)], [], {
					$select: CAMPOS_AVALIACAO.join(","),
					$$groupId: "$direct"
				});
				var oPedidoBinding = oModel.bindContext(sPath, null, {
					$select: Explicacao.CAMPOS_SINAIS.join(","),
					$$groupId: "$direct"
				});

				return Promise.all([oLista.requestContexts(0, 1), oPedidoBinding.requestObject()])
					.then(function (aRes) {
						var oAval = aRes[0].length ? aRes[0][0].getObject() : null;
						var oPedido = aRes[1];
						if (iSeq !== that._iSeq) {
							return; // outra navegacao ja comecou
						}
						if (!oPedido) {
							throw new Error("pedido sem dados");
						}
						that._montar(oAval, oPedido);
					})
					.catch(function (oErr) {
						Log.warning("Jev: falha ao carregar a ultima avaliacao", String(oErr), "zpocjev.antifraude");
						// 1a carga numa sessao nova do S/4 pode tomar 403 transitorio: tenta de novo uma vez
						if (!bNovaTentativa && iSeq === that._iSeq) {
							return new Promise(function (resolve) {
								setTimeout(resolve, 1500);
							}).then(function () {
								return iSeq === that._iSeq ? that._carregarExplicacao(oContext, true) : undefined;
							});
						}
						if (iSeq === that._iSeq) {
							oJev.setProperty("/carregando", false);
							oJev.setProperty("/erroCarga", that._texto("erroCarga"));
						}
					})
					.finally(function () {
						oLista.destroy();
						oPedidoBinding.destroy();
					});
			},

			_montar: function (oAval, oPedido) {
				var that = this;
				var oJev = this.base.getView().getModel("jev");
				var aSinais = Explicacao.sinais(oPedido).map(function (s) {
					return { texto: that._t(s) };
				});
				var mDados = {
					carregando: false,
					carregado: true,
					avaliado: !!oAval,
					sinais: aSinais
				};

				if (oAval) {
					var v = Explicacao.veredito(oAval.Classificacao);
					var oMotivo = oAval.Classificacao === "INDISPONIVEL" ? Explicacao.motivoIndisponivel(oAval.JevModeloVersao) : null;
					mDados.veredito = {
						titulo: this._texto(v.titulo),
						etiqueta: this._texto(v.etiqueta),
						estado: v.estado,
						cor: v.cor,
						icone: v.icone,
						motivo: this._t(oMotivo)
					};

					var oPorQue = Explicacao.porQue(oAval);
					if (oPorQue) {
						oPorQue.args[0] = this._texto(oPorQue.rotulo).toLowerCase();
						mDados.porQue = this._t(oPorQue);
					}

					mDados.mostrarRiscos = Explicacao.temRiscos(oAval);
					if (mDados.mostrarRiscos) {
						mDados.riscos = Explicacao.riscos(oAval).map(function (r) {
							return { rotulo: that._texto(r.rotulo), pct: r.pct, estado: r.estado, valor: r.pct + "%" };
						});
						mDados.legenda = this._t(Explicacao.legenda(oAval));
					}

					var sQuando = oAval.EvaluatedAt ? oFormatoDataHora.format(new Date(oAval.EvaluatedAt)) : "";
					var aPartes = [this._texto("rodapeAvaliado", [sQuando, oAval.EvaluatedBy || "-"])];
					if (mDados.mostrarRiscos && Number(oAval.Atipicidade) >= 1) {
						aPartes.push(this._texto("rodapeAtipicidade", [oAval.Atipicidade]));
					}
					var oSug = Explicacao.sugestao(oAval);
					if (oSug) {
						aPartes.push(this._texto("rodapeSugestao", [this._texto(oSug.rotulo), oSug.pct]));
					}
					mDados.rodape = aPartes.join(" · ");
				}
				Object.keys(mDados).forEach(function (k) {
					oJev.setProperty("/" + k, mDados[k]);
				});
			},

			onAvaliar: function () {
				var that = this;
				var oView = this.base.getView();
				var oExtensionAPI = this.base.getExtensionAPI();
				var oContext = oExtensionAPI.getBindingContext();
				var oJev = oView.getModel("jev");
				if (!oContext || oJev.getProperty("/busy")) {
					return;
				}
				oJev.setProperty("/busy", true);

				AvaliacaoService.avaliarPedido(oContext)
					.then(function (oRes) {
						that._sPathUltima = oContext.getPath();
						oJev.setProperty("/ultima", {
							status: oRes.status,
							motivo: oRes.motivo || "",
							latenciaMs: oRes.latenciaMs || 0,
							modelo: oRes.modelo || "",
							custo: typeof oRes.custoUsd === "number" ? "US$ " + oRes.custoUsd.toFixed(6) : "",
							quando: new Date().toLocaleTimeString(),
							payload: oRes.request ? JSON.stringify(oRes.request, null, 2) : ""
						});
						if (oRes.status === "BLOQUEIO_REGRA") {
							MessageBox.information(that._texto("msgBloqueioRegra", [oRes.pedido]));
						} else if (oRes.status === "INDISPONIVEL") {
							MessageToast.show(that._texto("msgIndisponivel"));
						} else {
							MessageToast.show(that._texto("msgAvaliado"));
						}
						return oExtensionAPI.refresh().then(function () {
							return that._carregarExplicacao(oContext);
						});
					})
					.catch(function (oErr) {
						MessageBox.error(that._texto("msgErroAcao", [(oErr && oErr.message) || ""]));
					})
					.finally(function () {
						oJev.setProperty("/busy", false);
					});
			}
		});
	}
);

/**
 * Extensao da List Report: acao de tabela "Avaliar selecionados com Jev" (modo sombra).
 * Processa os pedidos selecionados com no maximo 3 em paralelo; cada um segue o mesmo fluxo
 * da Object Page (AvaliacaoService). Falhas do Jev viram INDISPONIVEL, nunca bloqueiam.
 */
sap.ui.define(
	[
		"sap/ui/core/mvc/ControllerExtension",
		"sap/ui/model/json/JSONModel",
		"sap/m/MessageBox",
		"zpocjev/antifraude/jev/JevClient",
		"zpocjev/antifraude/jev/AvaliacaoService"
	],
	function (ControllerExtension, JSONModel, MessageBox, JevClient, AvaliacaoService) {
		"use strict";

		var MAX_PEDIDOS_POR_LOTE = 50;

		return ControllerExtension.extend("zpocjev.antifraude.ext.controller.ListReportExt", {
			override: {
				onInit: function () {
					this.base.getView().setModel(new JSONModel({ busy: false }), "jevLista");
					var sEndpoint = this.base.getAppComponent().getManifestEntry("/sap.app/dataSources/jevApi/uri");
					var sSim = new URLSearchParams(window.location.search).get("jev-sim");
					JevClient.configure({ endpoint: sEndpoint, headers: sSim ? { "X-Jev-Sim": sSim } : {} });
					this.base.getExtensionAPI().setCustomMessage({
						message: this._texto("msgModoSombraLista"),
						type: "Information"
					});
				}
			},

			_texto: function (sKey, aArgs) {
				// no onInit o modelo i18n ainda nao propagou para a view: usar o do AppComponent
				return this.base.getAppComponent().getModel("i18n").getResourceBundle().getText(sKey, aArgs);
			},

			onAvaliarSelecionados: function () {
				var that = this;
				var oExtensionAPI = this.base.getExtensionAPI();
				var oModel = this.base.getView().getModel("jevLista");
				var aContextos = oExtensionAPI.getSelectedContexts() || [];
				if (!aContextos.length || oModel.getProperty("/busy")) {
					return;
				}
				if (aContextos.length > MAX_PEDIDOS_POR_LOTE) {
					MessageBox.warning(this._texto("msgLoteGrande", [MAX_PEDIDOS_POR_LOTE]));
					return;
				}
				oModel.setProperty("/busy", true);

				var oLimiter = JevClient.createLimiter(JevClient.MAX_CONCORRENTES);
				var aPromessas = aContextos.map(function (oCtx) {
					return oLimiter.run(function () {
						return AvaliacaoService.avaliarPedido(oCtx);
					});
				});

				Promise.allSettled(aPromessas)
					.then(function (aRes) {
						var m = { AVALIADO: 0, INDISPONIVEL: 0, BLOQUEIO_REGRA: 0, ERRO: 0 };
						var aErros = [];
						aRes.forEach(function (r) {
							if (r.status === "fulfilled") {
								m[r.value.status]++;
							} else {
								m.ERRO++;
								aErros.push((r.reason && r.reason.message) || String(r.reason));
							}
						});
						var sResumo = that._texto("msgResumoLote", [m.AVALIADO, m.INDISPONIVEL, m.BLOQUEIO_REGRA, m.ERRO]);
						if (m.ERRO) {
							MessageBox.warning(sResumo, { details: aErros.join("\n") });
						} else {
							MessageBox.success(sResumo);
						}
						return oExtensionAPI.refresh();
					})
					.finally(function () {
						oModel.setProperty("/busy", false);
					});
			}
		});
	}
);

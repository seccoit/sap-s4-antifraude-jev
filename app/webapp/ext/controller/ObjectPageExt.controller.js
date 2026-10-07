/**
 * Extensao da Object Page do Pedido: botao "Avaliar com Jev" (modo sombra).
 * So onInit/onExit sao sobrescritos (unicos hooks extensiveis do FE V4).
 * O handler onAvaliar e referenciado no manifest como
 * ".extension.zpocjev.antifraude.ext.controller.ObjectPageExt.onAvaliar".
 */
sap.ui.define(
	[
		"sap/ui/core/mvc/ControllerExtension",
		"sap/ui/model/json/JSONModel",
		"sap/m/MessageToast",
		"sap/m/MessageBox",
		"zpocjev/antifraude/jev/JevClient",
		"zpocjev/antifraude/jev/AvaliacaoService"
	],
	function (ControllerExtension, JSONModel, MessageToast, MessageBox, JevClient, AvaliacaoService) {
		"use strict";

		function textoI18n(oView, sKey, aArgs) {
			var oModel = oView.getModel("i18n") || oView.getController().getAppComponent().getModel("i18n");
			var oBundle = oModel.getResourceBundle();
			return oBundle.getText(sKey, aArgs);
		}

		return ControllerExtension.extend("zpocjev.antifraude.ext.controller.ObjectPageExt", {
			override: {
				onInit: function () {
					var oView = this.base.getView();
					oView.setModel(
						new JSONModel({
							busy: false,
							ultima: null,
							timeoutMs: JevClient.TIMEOUT_MS,
							maxConcorrentes: JevClient.MAX_CONCORRENTES
						}),
						"jev"
					);
					var oComponent = this.base.getAppComponent();
					var sEndpoint = oComponent.getManifestEntry("/sap.app/dataSources/jevApi/uri");
					// ?jev-sim=timeout|erro na URL forca falha no SIMULADOR (demonstracao da falha segura)
					var sSim = new URLSearchParams(window.location.search).get("jev-sim");
					JevClient.configure({ endpoint: sEndpoint, headers: sSim ? { "X-Jev-Sim": sSim } : {} });
				}
			},

			onAvaliar: function () {
				var oView = this.base.getView();
				var oExtensionAPI = this.base.getExtensionAPI();
				var oContext = oExtensionAPI.getBindingContext();
				var oJevModel = oView.getModel("jev");
				if (!oContext || oJevModel.getProperty("/busy")) {
					return;
				}
				oJevModel.setProperty("/busy", true);

				AvaliacaoService.avaliarPedido(oContext)
					.then(function (oRes) {
						oJevModel.setProperty("/ultima", {
							status: oRes.status,
							motivo: oRes.motivo || "",
							latenciaMs: oRes.latenciaMs || 0,
							acaoSugerida: oRes.acaoSugerida || "",
							modelo: oRes.modelo || "",
							custo: typeof oRes.custoUsd === "number" ? "US$ " + oRes.custoUsd.toFixed(6) : "",
							quando: new Date().toLocaleTimeString(),
							payload: oRes.request ? JSON.stringify(oRes.request, null, 2) : ""
						});
						if (oRes.status === "BLOQUEIO_REGRA") {
							MessageBox.information(textoI18n(oView, "msgBloqueioRegra", [oRes.pedido]));
						} else if (oRes.status === "INDISPONIVEL") {
							MessageToast.show(textoI18n(oView, "msgIndisponivel", [oRes.motivo]));
						} else {
							MessageToast.show(textoI18n(oView, "msgAvaliado", [oRes.acaoSugerida]));
						}
						return oExtensionAPI.refresh();
					})
					.catch(function (oErr) {
						MessageBox.error(textoI18n(oView, "msgErroAcao", [(oErr && oErr.message) || ""]));
					})
					.finally(function () {
						oJevModel.setProperty("/busy", false);
					});
			}
		});
	}
);

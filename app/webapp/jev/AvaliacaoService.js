/**
 * Orquestra a avaliacao de UM pedido em modo sombra:
 *   1. le (GET dedicado, $select da lista branca) os indicadores do Pedido;
 *   2. RuleClassification = BLOQUEIO_REGRA -> NAO chama o Jev; registra com JevDisponivel=false;
 *   3. senao chama o Jev (JevClient: timeout 1500 ms, max. 3 simultaneas);
 *   4. sucesso -> acao registrarAvaliacao com as probabilidades (4 casas);
 *      falha/timeout -> acao com JevDisponivel=false (INDISPONIVEL). Nada e bloqueado.
 * Usado pelas duas extensoes (Object Page e List Report).
 */
sap.ui.define(["zpocjev/antifraude/jev/JevClient"], function (JevClient) {
	"use strict";

	var ACAO = "com.sap.gateway.srvd.zui_poc_jev.v0001.registrarAvaliacao";

	// Lista branca: unicos campos lidos para montar o payload do Jev (sem SupplierName/Supplier/CreatedByUser).
	var CAMPOS_INDICADORES = [
		"PurchaseOrder",
		"RuleClassification",
		"SupplierAgeDays",
		"SupplierCreatorIsPOCreator",
		"MasterDataChanges30d",
		"DaysSinceLastMDChange",
		"SharedBankAccount",
		"SharedBankOtherCount",
		"SuplrHistPOCount",
		"SuplrHistAvgAmount",
		"SuplrHistStdDevAmount",
		"AmountToSuplrAvgRatio",
		"AmountZScore",
		"MaxPriceToInfoRecordRatio",
		"MaxPriceToMaterialAvgRatio",
		"MaxQtyToHistRatio",
		"MaterialNewForSupplier",
		"PaymentTermsDiverge",
		"InvoiceBeforePO",
		"SuplrPOCount24h",
		"SuplrPOCount7d",
		"BuyerSupplierSharePct",
		"CreatorPostedGR"
	];

	function lerIndicadores(oContext) {
		var oModel = oContext.getModel();
		var oBinding = oModel.bindContext(oContext.getPath(), null, {
			$select: CAMPOS_INDICADORES.join(","),
			$$groupId: "$direct"
		});
		return oBinding.requestObject().then(function (oDados) {
			oBinding.destroy();
			return oDados || {};
		});
	}

	function executarAcao(oContext, mParams) {
		var oModel = oContext.getModel();
		var oOperation = oModel.bindContext(ACAO + "(...)", oContext);
		Object.keys(mParams).forEach(function (sNome) {
			oOperation.setParameter(sNome, mParams[sNome]);
		});
		// invoke() substitui execute() (deprecated desde 1.123) - mesma chamada da acao bound.
		return oOperation.invoke().then(
			function (oRetorno) {
				oOperation.destroy();
				return oRetorno;
			},
			function (oErr) {
				oOperation.destroy();
				throw oErr;
			}
		);
	}

	/**
	 * @param {sap.ui.model.odata.v4.Context} oContext contexto de um Pedido
	 * @returns {Promise<object>} { pedido, status: "AVALIADO"|"INDISPONIVEL"|"BLOQUEIO_REGRA",
	 *   motivo?, latenciaMs?, acaoSugerida?, request? } - rejeita apenas se a acao OData falhar
	 */
	function avaliarPedido(oContext) {
		return lerIndicadores(oContext).then(function (oPedido) {
			var sPedido = oPedido.PurchaseOrder;

			if (oPedido.RuleClassification === "BLOQUEIO_REGRA") {
				return executarAcao(oContext, JevClient.parametrosIndisponivel("NAO_CHAMADO:BLOQUEIO_REGRA")).then(function () {
					return { pedido: sPedido, status: "BLOQUEIO_REGRA" };
				});
			}

			return JevClient.avaliar(oPedido).then(function (oRes) {
				var mParams = oRes.ok ? oRes.params : JevClient.parametrosIndisponivel("INDISPONIVEL:" + oRes.motivo);
				return executarAcao(oContext, mParams).then(function () {
					return {
						pedido: sPedido,
						status: oRes.ok ? "AVALIADO" : "INDISPONIVEL",
						motivo: oRes.motivo,
						latenciaMs: oRes.latenciaMs,
						custoUsd: oRes.ok ? oRes.custoUsd : null,
						modelo: oRes.ok ? oRes.params.JevModeloVersao : "",
						acaoSugerida: oRes.ok ? oRes.params.JevAcaoSugerida : "",
						request: oRes.request,
						params: mParams
					};
				});
			});
		});
	}

	return {
		ACAO: ACAO,
		CAMPOS_INDICADORES: CAMPOS_INDICADORES,
		avaliarPedido: avaliarPedido
	};
});

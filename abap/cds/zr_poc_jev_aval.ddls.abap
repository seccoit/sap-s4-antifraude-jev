@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - avaliacao do pedido'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_POC_JEV_AVAL
  as select from zpoc_jev_aval
  association to parent ZR_POC_JEV_PEDIDO as _Pedido on $projection.PurchaseOrder = _Pedido.PurchaseOrder
{
  key aval_uuid                as EvaluationUUID,
      purchase_order           as PurchaseOrder,
      aval_ts                  as EvaluatedAt,
      aval_user                as EvaluatedBy,
      snap_idade_forn_dias     as SnapSupplierAgeDays,
      snap_alter_cad_30d       as SnapMDChanges30d,
      snap_conta_compart       as SnapSharedBankOtherCount,
      snap_razao_valor_media   as SnapAmountToSuplrAvgRatio,
      snap_zscore_valor        as SnapAmountZScore,
      snap_razao_preco_ri      as SnapPriceToInfoRecordRatio,
      snap_razao_preco_hist    as SnapPriceToMaterialAvgRatio,
      snap_razao_qtd_hist      as SnapQtyToHistRatio,
      snap_mat_novo_forn       as SnapMaterialNewForSupplier,
      snap_zterm_diverge       as SnapPaymentTermsDiverge,
      snap_pedido_pos_fatura   as SnapInvoiceBeforePO,
      snap_criador_registra_em as SnapCreatorPostedGR,
      snap_criador_forn_igual  as SnapSupplierCreatorIsPOCreator,
      snap_ped_forn_24h        as SnapSuplrPOCount24h,
      snap_ped_forn_7d         as SnapSuplrPOCount7d,
      snap_part_forn_comprador as SnapBuyerSupplierSharePct,
      jev_disponivel           as JevDisponivel,
      prob_forn_ficticio       as ProbFornecedorFicticio,
      prob_desvio_pagto        as ProbDesvioPagamento,
      prob_sobrepreco          as ProbSobrepreco,
      prob_fracionamento       as ProbFracionamento,
      prob_fraude_interna      as ProbFraudeInterna,
      atipicidade              as Atipicidade,
      jev_acao_sugerida        as JevAcaoSugerida,
      jev_prob_liberar         as JevProbLiberar,
      jev_prob_aprovacao       as JevProbAprovacao,
      jev_prob_bloquear        as JevProbBloquear,
      jev_modelo_versao        as JevModeloVersao,
      risco_max                as RiscoMax,
      chave_risco_max          as ChaveRiscoMax,
      classificacao            as Classificacao,
      case classificacao
        when 'BLOQUEIA'       then 1
        when 'BLOQUEIO_REGRA' then 1
        when 'APROVACAO'      then 2
        when 'LIBERA'         then 3
        else 0 end             as ClassificacaoCriticality,
      limiar_aprov_usado       as LimiarAprovacaoUsado,
      limiar_bloq_usado        as LimiarBloqueioUsado,
      modo_sombra              as ModoSombra,
      decisao_aprovador        as DecisaoAprovador,
      aprovador                as Aprovador,
      decisao_ts               as DecisaoTimestamp,
      decisao_obs              as DecisaoObservacao,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at    as LocalLastChangedAt,

      _Pedido
}

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - pedido com indicadores'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_POC_JEV_PEDIDO
  as select from         ekko
    inner join           ZI_POC_JEV_FORNIND                             as forn on forn.PurchaseOrder = ekko.ebeln
    left outer to one join ZTF_POC_JEV_HIST( p_clnt: $session.client ) as hist on hist.PurchaseOrder = ekko.ebeln
    left outer to one join ZI_POC_JEV_ALTCAD                           as alt  on alt.PurchaseOrder = ekko.ebeln
    left outer to one join ZI_POC_JEV_FLUXODOC                         as flx  on flx.PurchaseOrder = ekko.ebeln
  composition [0..*] of ZR_POC_JEV_AVAL as _Avaliacao
  association [0..1] to I_Supplier       as _Supplier on $projection.Supplier = _Supplier.Supplier
{
  key ekko.ebeln                                                     as PurchaseOrder,
      ekko.lifnr                                                     as Supplier,
      _Supplier.SupplierName                                         as SupplierName,
      ekko.ernam                                                     as CreatedByUser,
      ekko.aedat                                                     as CreationDate,
      ekko.bukrs                                                     as CompanyCode,
      ekko.ekorg                                                     as PurchasingOrganization,
      ekko.ekgrp                                                     as PurchasingGroup,
      ekko.zterm                                                     as PaymentTerms,
      forn.SupplierDefaultPaymentTerms                               as SupplierDefaultPaymentTerms,
      ekko.waers                                                     as DocumentCurrency,
      hist.POTotalAmount                                             as POTotalAmount,

      /* Fornecedor */
      forn.SupplierAgeDays                                           as SupplierAgeDays,
      forn.SupplierCreatorIsPOCreator                                as SupplierCreatorIsPOCreator,
      forn.SupplierIsBlocked                                         as SupplierIsBlocked,
      coalesce( alt.MasterDataChanges30d, 0 )                        as MasterDataChanges30d,
      case when alt.LastMasterDataChangeDate is null then -1
           else dats_days_between( alt.LastMasterDataChangeDate, ekko.aedat )
      end                                                            as DaysSinceLastMDChange,
      case when forn.SharedBankOtherBPs > forn.SharedBankOtherSuppliers
           then forn.SharedBankOtherBPs
           else forn.SharedBankOtherSuppliers end                    as SharedBankOtherCount,
      case when forn.SharedBankOtherBPs > 0 or forn.SharedBankOtherSuppliers > 0
           then cast( 'X' as abap_boolean preserving type )
           else cast( '' as abap_boolean preserving type ) end        as SharedBankAccount,
      hist.SuplrHistPOCount                                          as SuplrHistPOCount,
      hist.SuplrHistAvgAmount                                        as SuplrHistAvgAmount,
      hist.SuplrHistStdDevAmount                                     as SuplrHistStdDevAmount,

      /* Pedido */
      hist.AmountToSuplrAvgRatio                                     as AmountToSuplrAvgRatio,
      hist.AmountZScore                                              as AmountZScore,
      coalesce( flx.MaxPriceToMaterialAvgRatio, cast( 0 as abap.dec(15,4) ) ) as MaxPriceToMaterialAvgRatio,
      coalesce( flx.MaxPriceToInfoRecordRatio, cast( 0 as abap.dec(15,4) ) )  as MaxPriceToInfoRecordRatio,
      coalesce( flx.MaxQtyToHistRatio, cast( 0 as abap.dec(15,4) ) )          as MaxQtyToHistRatio,
      coalesce( flx.MaterialNewForSupplier, cast( '' as abap_boolean preserving type ) )
                                                                     as MaterialNewForSupplier,
      forn.PaymentTermsDiverge                                       as PaymentTermsDiverge,
      case when coalesce( flx.InvoiceBeforePOCount, 0 ) > 0
           then cast( 'X' as abap_boolean preserving type )
           else cast( '' as abap_boolean preserving type ) end        as InvoiceBeforePO,

      /* Velocidade */
      hist.SuplrPOCount24h                                           as SuplrPOCount24h,
      hist.SuplrPOCount7d                                            as SuplrPOCount7d,

      /* Comprador */
      hist.BuyerSupplierSharePct                                     as BuyerSupplierSharePct,
      case when coalesce( flx.GRByPOCreatorCount, 0 ) > 0
           then cast( 'X' as abap_boolean preserving type )
           else cast( '' as abap_boolean preserving type ) end        as CreatorPostedGR,

      /* Regra dura */
      case when forn.SupplierIsBlocked = 'X'
           then cast( 'BLOQUEIO_REGRA' as abap.char(15) )
           else cast( 'AVALIAR_JEV' as abap.char(15) ) end           as RuleClassification,

      /* Ultima avaliacao */
      hist.LastAvalTimestamp                                         as LastAvalTimestamp,
      hist.LastClassificacao                                         as LastClassification,
      hist.LastRiscoMax                                              as LastRiskMax,
      hist.AvaliacaoCount                                            as EvaluationCount,

      /* Semaforos: 1 vermelho, 2 amarelo, 3 verde, 0 neutro */
      case when forn.SupplierAgeDays < 90  then 1
           when forn.SupplierAgeDays < 365 then 2
           else 3 end                                                as SupplierAgeCriticality,
      case when coalesce( alt.MasterDataChanges30d, 0 ) > 0 then 1 else 3 end
                                                                     as MDChangeCriticality,
      case when forn.SharedBankOtherBPs > 0 or forn.SharedBankOtherSuppliers > 0 then 1 else 3 end
                                                                     as SharedBankCriticality,
      case when coalesce( flx.MaxPriceToInfoRecordRatio, 0 ) * 100 > 120
             or coalesce( flx.MaxPriceToMaterialAvgRatio, 0 ) * 100 > 120 then 1
           when coalesce( flx.MaxPriceToInfoRecordRatio, 0 ) * 100 > 105
             or coalesce( flx.MaxPriceToMaterialAvgRatio, 0 ) * 100 > 105 then 2
           when coalesce( flx.MaxPriceToInfoRecordRatio, 0 ) = 0
            and coalesce( flx.MaxPriceToMaterialAvgRatio, 0 ) = 0 then 0
           else 3 end                                                as PriceCriticality,
      case when forn.SupplierIsBlocked = 'X' then 1 else 3 end       as RuleCriticality,
      case hist.LastClassificacao
           when 'BLOQUEIA'       then 1
           when 'BLOQUEIO_REGRA' then 1
           when 'APROVACAO'      then 2
           when 'LIBERA'         then 3
           else 0 end                                                as ClassificationCriticality,

      _Avaliacao,
      _Supplier
}
where
      ekko.bstyp = 'F'
  and ekko.bsart = 'NB'
  and ekko.reswk = ''
  and ekko.loekz = ''

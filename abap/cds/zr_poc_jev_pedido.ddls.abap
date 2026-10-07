@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - pedido com indicadores'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_POC_JEV_PEDIDO
  as select from           I_PurchaseOrderAPI01   as po
    inner join             ZI_POC_JEV_FORNIND     as forn on  forn.PurchaseOrder = po.PurchaseOrder
    left outer to one join ZI_POC_JEV_PEDIDOVALOR as val  on  val.PurchaseOrder = po.PurchaseOrder
    left outer to one join ZI_POC_JEV_HISTFORN    as hf   on  hf.PurchaseOrder = po.PurchaseOrder
    left outer to one join ZI_POC_JEV_COMPRADOR   as cmp  on  cmp.PurchaseOrder = po.PurchaseOrder
    left outer to one join ZI_POC_JEV_ALTCAD      as alt  on  alt.PurchaseOrder = po.PurchaseOrder
    left outer to one join ZI_POC_JEV_FLUXODOC    as flx  on  flx.PurchaseOrder = po.PurchaseOrder
    left outer to one join ZI_POC_JEV_ULTAVAL     as ult  on  ult.PurchaseOrder = po.PurchaseOrder
    left outer to one join zpoc_jev_aval          as lav  on  lav.purchase_order = ult.PurchaseOrder
                                                          and lav.aval_ts        = ult.LastAvalTimestamp
  composition [0..*] of ZR_POC_JEV_AVAL as _Avaliacao
  association [0..1] to I_Supplier       as _Supplier on $projection.Supplier = _Supplier.Supplier
{
  key po.PurchaseOrder                                               as PurchaseOrder,
      po.Supplier                                                    as Supplier,
      _Supplier.SupplierName                                         as SupplierName,
      po.CreatedByUser                                               as CreatedByUser,
      po.CreationDate                                                as CreationDate,
      po.CompanyCode                                                 as CompanyCode,
      po.PurchasingOrganization                                      as PurchasingOrganization,
      po.PurchasingGroup                                             as PurchasingGroup,
      po.PaymentTerms                                                as PaymentTerms,
      forn.SupplierDefaultPaymentTerms                               as SupplierDefaultPaymentTerms,
      po.DocumentCurrency                                            as DocumentCurrency,
      val.POTotalAmount                                              as POTotalAmount,

      /* Fornecedor */
      forn.SupplierAgeDays                                           as SupplierAgeDays,
      forn.SupplierCreatorIsPOCreator                                as SupplierCreatorIsPOCreator,
      forn.SupplierIsBlocked                                         as SupplierIsBlocked,
      coalesce( alt.MasterDataChanges30d, 0 )                        as MasterDataChanges30d,
      case when alt.LastMasterDataChangeDate is null then -1
           else dats_days_between( alt.LastMasterDataChangeDate, po.CreationDate )
      end                                                            as DaysSinceLastMDChange,
      forn.SharedBankOtherBPs                                        as SharedBankOtherCount,
      case when forn.SharedBankOtherBPs > 0
           then cast( 'X' as abap_boolean preserving type )
           else cast( '' as abap_boolean preserving type ) end        as SharedBankAccount,
      coalesce( hf.SuplrHistPOCount, 0 )                             as SuplrHistPOCount,
      /* Medias e razoes truncadas (nao arredondadas), como o CAST DECIMAL do HANA na antiga AMDP */
      case when coalesce( hf.SuplrHistPOCount, 0 ) > 0
           then cast( division( cast( floor( division( hf.SuplrHistSumAmount * 100, hf.SuplrHistPOCount, 6 ) )
                                      as abap.dec(21,0) ), 100, 2 ) as abap.dec(15,2) )
           else cast( 0 as abap.dec(15,2) ) end                      as SuplrHistAvgAmount,
      /* base do desvio padrao e do z-score (calculados em ABAP, ZCL_POC_JEV_STATS) */
      coalesce( hf.SuplrHistSumAmount, cast( 0 as abap.dec(15,2) ) ) as SuplrHistSumAmount,
      coalesce( hf.SuplrHistSumSqAmount, cast( 0 as abap.fltp ) )    as SuplrHistSumSqAmount,

      /* Pedido */
      case when hf.SuplrHistSumAmount > 0
           then cast( division( cast( floor( division( cast( val.POTotalAmount * hf.SuplrHistPOCount as abap.dec(17,2) ) * 10000,
                                                       hf.SuplrHistSumAmount, 6 ) )
                                      as abap.dec(21,0) ), 10000, 4 ) as abap.dec(11,4) )
           else cast( 0 as abap.dec(11,4) ) end                      as AmountToSuplrAvgRatio,
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
      coalesce( hf.SuplrPOCount24h, 0 )                              as SuplrPOCount24h,
      coalesce( hf.SuplrPOCount7d, 0 )                               as SuplrPOCount7d,

      /* Comprador */
      case when cmp.BuyerTotal12m > 0
           then cast( division( cast( floor( division( cmp.BuyerSupplierAmount12m * 10000, cmp.BuyerTotal12m, 6 ) )
                                      as abap.dec(21,0) ), 100, 2 ) as abap.dec(7,2) )
           else cast( 0 as abap.dec(7,2) ) end                       as BuyerSupplierSharePct,
      case when coalesce( flx.GRByPOCreatorCount, 0 ) > 0
           then cast( 'X' as abap_boolean preserving type )
           else cast( '' as abap_boolean preserving type ) end        as CreatorPostedGR,

      /* Regra dura */
      case when forn.SupplierIsBlocked = 'X'
           then cast( 'BLOQUEIO_REGRA' as abap.char(15) )
           else cast( 'AVALIAR_JEV' as abap.char(15) ) end           as RuleClassification,

      /* Ultima avaliacao */
      case when ult.LastAvalTimestamp is null then cast( 0 as timestampl )
           else ult.LastAvalTimestamp end                            as LastAvalTimestamp,
      coalesce( lav.classificacao, cast( '' as abap.char(15) ) )     as LastClassification,
      coalesce( lav.risco_max, cast( 0 as abap.dec(5,4) ) )          as LastRiskMax,
      coalesce( ult.EvaluationCount, 0 )                             as EvaluationCount,

      /* Semaforos: 1 vermelho, 2 amarelo, 3 verde, 0 neutro */
      case when forn.SupplierAgeDays < 90  then 1
           when forn.SupplierAgeDays < 365 then 2
           else 3 end                                                as SupplierAgeCriticality,
      case when coalesce( alt.MasterDataChanges30d, 0 ) > 0 then 1 else 3 end
                                                                     as MDChangeCriticality,
      case when forn.SharedBankOtherBPs > 0 then 1 else 3 end        as SharedBankCriticality,
      case when coalesce( flx.MaxPriceToInfoRecordRatio, 0 ) * 100 > 120
             or coalesce( flx.MaxPriceToMaterialAvgRatio, 0 ) * 100 > 120 then 1
           when coalesce( flx.MaxPriceToInfoRecordRatio, 0 ) * 100 > 105
             or coalesce( flx.MaxPriceToMaterialAvgRatio, 0 ) * 100 > 105 then 2
           when coalesce( flx.MaxPriceToInfoRecordRatio, 0 ) = 0
            and coalesce( flx.MaxPriceToMaterialAvgRatio, 0 ) = 0 then 0
           else 3 end                                                as PriceCriticality,
      case when forn.SupplierIsBlocked = 'X' then 1 else 3 end       as RuleCriticality,
      case lav.classificacao
           when 'BLOQUEIA'       then 1
           when 'BLOQUEIO_REGRA' then 1
           when 'APROVACAO'      then 2
           when 'LIBERA'         then 3
           else 0 end                                                as ClassificationCriticality,

      _Avaliacao,
      _Supplier
}
where
      po.PurchaseOrderType              = 'NB'
  and po.SupplyingPlant                 = ''
  and po.PurchasingDocumentDeletionCode = ''

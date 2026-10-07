@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - fluxo docs e pior item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_POC_JEV_FLUXODOC
  as select from    ZI_POC_JEV_ITEMIND as itm
    inner join      ekko                     on  ekko.ebeln = itm.PurchaseOrder
    left outer join ekbe as gr               on  gr.ebeln = itm.PurchaseOrder
                                             and gr.ebelp = itm.PurchaseOrderItem
                                             and gr.vgabe = '1'
                                             and gr.ernam = ekko.ernam
    left outer join rseg as r                on  r.ebeln = itm.PurchaseOrder
                                             and r.ebelp = itm.PurchaseOrderItem
    left outer join rbkp as k                on  k.belnr = r.belnr
                                             and k.gjahr = r.gjahr
                                             and k.stblg = ''
                                             and k.bldat < itm.CreationDate
{
  key itm.PurchaseOrder,
      count( distinct gr.belnr )                                               as GRByPOCreatorCount,
      count( distinct k.belnr )                                                as InvoiceBeforePOCount,
      max( case when itm.HistMaterialAvgUnitPrice > 0
                then division( itm.UnitPrice, itm.HistMaterialAvgUnitPrice, 4 )
                else cast( 0 as abap.dec(15,4) ) end )                         as MaxPriceToMaterialAvgRatio,
      max( case when itm.InfoRecordUnitPrice > 0
                then division( itm.UnitPrice, itm.InfoRecordUnitPrice, 4 )
                else cast( 0 as abap.dec(15,4) ) end )                         as MaxPriceToInfoRecordRatio,
      max( case when itm.HistSuplrMaterialAvgQty > 0
                then division( itm.OrderQuantity, itm.HistSuplrMaterialAvgQty, 4 )
                else cast( 0 as abap.dec(15,4) ) end )                         as MaxQtyToHistRatio,
      max( case when itm.Material <> '' and itm.HistSuplrMaterialItemCount = 0
                then cast( 'X' as abap_boolean preserving type )
                else cast( '' as abap_boolean preserving type ) end )          as MaterialNewForSupplier
}
group by
  itm.PurchaseOrder

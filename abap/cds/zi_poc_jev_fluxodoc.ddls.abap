@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - fluxo docs e pior item'
@Metadata.ignorePropagatedAnnotations: true
/* EM: documento de material 101 nao estornado, usuario do cabecalho = criador do pedido.
   Fatura: documento nao estornado com data do documento anterior a criacao do pedido. */
define view entity ZI_POC_JEV_FLUXODOC
  as select from    ZI_POC_JEV_ITEMIND            as itm
    inner join      I_PurchaseOrderAPI01          as po  on  po.PurchaseOrder = itm.PurchaseOrder
    left outer join I_MaterialDocumentItem_2      as gr  on  gr.PurchaseOrder            = itm.PurchaseOrder
                                                         and gr.PurchaseOrderItem        = itm.PurchaseOrderItem
                                                         and gr.GoodsMovementType        = '101'
                                                         and gr.GoodsMovementIsCancelled = ''
    left outer join I_MaterialDocumentHeader_2    as grh on  grh.MaterialDocumentYear = gr.MaterialDocumentYear
                                                         and grh.MaterialDocument     = gr.MaterialDocument
                                                         and grh.CreatedByUser        = po.CreatedByUser
    left outer join I_SuplrInvcItemPurOrdRefAPI01 as r   on  r.PurchaseOrder     = itm.PurchaseOrder
                                                         and r.PurchaseOrderItem = itm.PurchaseOrderItem
    left outer join I_SupplierInvoiceAPI01        as k   on  k.SupplierInvoice = r.SupplierInvoice
                                                         and k.FiscalYear      = r.FiscalYear
                                                         and k.ReverseDocument = ''
                                                         and k.DocumentDate    < itm.CreationDate
{
  key itm.PurchaseOrder,
      count( distinct grh.MaterialDocument )                                   as GRByPOCreatorCount,
      count( distinct k.SupplierInvoice )                                      as InvoiceBeforePOCount,
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

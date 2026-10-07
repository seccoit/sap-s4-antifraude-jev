@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - itens com indicadores'
@Metadata.allowExtensions: true
define view entity ZC_POC_JEV_ITEM
  as select from ZI_POC_JEV_ITEMIND
  association [0..1] to I_Supplier as _Supplier on $projection.Supplier = _Supplier.Supplier
{
  key PurchaseOrder,
  key PurchaseOrderItem,
      @ObjectModel.text.element: [ 'SupplierName' ]
      Supplier,
      @Semantics.text: true
      _Supplier.SupplierName                                             as SupplierName,
      CreationDate,
      Material,
      Plant,
      PurchasingInfoRecord,
      DocumentCurrency,
      OrderUnit,
      OrderPriceUnit,
      OrderQuantity,
      NetAmount,
      UnitPrice,
      InfoRecordUnitPrice,
      HistMaterialPOCount,
      coalesce( HistMaterialAvgUnitPrice, cast( 0 as abap.dec(15,4) ) )  as HistMaterialAvgUnitPrice,
      HistSuplrMaterialItemCount,
      coalesce( HistSuplrMaterialAvgQty, cast( 0 as abap.dec(13,3) ) )   as HistSuplrMaterialAvgQty,
      case when InfoRecordUnitPrice > 0
           then division( UnitPrice, InfoRecordUnitPrice, 4 )
           else cast( 0 as abap.dec(15,4) ) end                          as PriceToInfoRecordRatio,
      case when HistMaterialAvgUnitPrice > 0
           then division( UnitPrice, HistMaterialAvgUnitPrice, 4 )
           else cast( 0 as abap.dec(15,4) ) end                          as PriceToMaterialAvgRatio,
      case when HistSuplrMaterialAvgQty > 0
           then division( OrderQuantity, HistSuplrMaterialAvgQty, 4 )
           else cast( 0 as abap.dec(15,4) ) end                          as QtyToHistRatio,
      case when Material <> '' and HistSuplrMaterialItemCount = 0
           then cast( 'X' as abap_boolean preserving type )
           else cast( '' as abap_boolean preserving type ) end            as MaterialNewForSupplier,
      case when InfoRecordUnitPrice > 0 and UnitPrice * 100 > InfoRecordUnitPrice * 120 then 1
           when InfoRecordUnitPrice > 0 and UnitPrice * 100 > InfoRecordUnitPrice * 105 then 2
           when InfoRecordUnitPrice > 0 then 3
           else 0 end                                                    as PriceCriticality
}

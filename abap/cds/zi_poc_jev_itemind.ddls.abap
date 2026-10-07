@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - estatisticas por item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_POC_JEV_ITEMIND
  as select from    ZI_POC_JEV_PEDIDOITEM as cur
    left outer join ZI_POC_JEV_PEDIDOITEM as hist on  hist.Material         =  cur.Material
                                                  and hist.DocumentCurrency =  cur.DocumentCurrency
                                                  and hist.OrderPriceUnit   =  cur.OrderPriceUnit
                                                  and hist.CreationDate     <  cur.CreationDate
                                                  and hist.CreationDate     >= cur.Date24MonthsBefore
    left outer to one join I_PurgInfoRecdOrgPlntDataApi01 as ri
                                                  on  ri.PurchasingInfoRecord         = cur.PurchasingInfoRecord
                                                  and ri.PurchasingOrganization       = cur.PurchasingOrganization
                                                  and ri.PurchasingInfoRecordCategory = '0'
                                                  and ri.Plant                        = cur.Plant
    left outer to one join I_PurgInfoRecdOrgPlntDataApi01 as rig
                                                  on  rig.PurchasingInfoRecord         = cur.PurchasingInfoRecord
                                                  and rig.PurchasingOrganization       = cur.PurchasingOrganization
                                                  and rig.PurchasingInfoRecordCategory = '0'
                                                  and rig.Plant                        = ''
{
  key cur.PurchaseOrder,
  key cur.PurchaseOrderItem,
      cur.Supplier,
      cur.CreationDate,
      cur.Material,
      cur.Plant,
      cur.PurchasingInfoRecord,
      cur.DocumentCurrency,
      cur.OrderUnit,
      cur.OrderPriceUnit,
      cur.OrderQuantity,
      cur.NetAmount,
      cur.UnitPrice,

      case
        when ri.PurchasingInfoRecord is not null and ri.IsMarkedForDeletion = ''
         and ri.Currency = cur.DocumentCurrency and ri.PurchaseOrderPriceUnit = cur.OrderPriceUnit
         and cast( ri.MaterialPriceUnitQty as abap.dec(13,3) ) > 0
         and cast( ri.NetPriceAmount as abap.dec(11,2) ) > 0
          then cast( division( cast( ri.NetPriceAmount as abap.dec(11,2) ),
                               cast( ri.MaterialPriceUnitQty as abap.dec(13,3) ), 4 ) as abap.dec(15,4) )
        when rig.PurchasingInfoRecord is not null and rig.IsMarkedForDeletion = ''
         and rig.Currency = cur.DocumentCurrency and rig.PurchaseOrderPriceUnit = cur.OrderPriceUnit
         and cast( rig.MaterialPriceUnitQty as abap.dec(13,3) ) > 0
         and cast( rig.NetPriceAmount as abap.dec(11,2) ) > 0
          then cast( division( cast( rig.NetPriceAmount as abap.dec(11,2) ),
                               cast( rig.MaterialPriceUnitQty as abap.dec(13,3) ), 4 ) as abap.dec(15,4) )
        else cast( 0 as abap.dec(15,4) )
      end                                                                     as InfoRecordUnitPrice,

      count( distinct hist.PurchaseOrder )                                    as HistMaterialPOCount,
      avg( hist.UnitPrice as abap.dec(15,4) )                                 as HistMaterialAvgUnitPrice,
      sum( case when hist.Supplier = cur.Supplier then 1 else 0 end )         as HistSuplrMaterialItemCount,
      avg( case when hist.Supplier = cur.Supplier and hist.OrderUnit = cur.OrderUnit
                then hist.OrderQuantity end as abap.dec(13,3) )               as HistSuplrMaterialAvgQty
}
group by
  cur.PurchaseOrder,
  cur.PurchaseOrderItem,
  cur.Supplier,
  cur.CreationDate,
  cur.Material,
  cur.Plant,
  cur.PurchasingInfoRecord,
  cur.DocumentCurrency,
  cur.OrderUnit,
  cur.OrderPriceUnit,
  cur.OrderQuantity,
  cur.NetAmount,
  cur.UnitPrice,
  ri.PurchasingInfoRecord,
  ri.IsMarkedForDeletion,
  ri.Currency,
  ri.PurchaseOrderPriceUnit,
  ri.MaterialPriceUnitQty,
  ri.NetPriceAmount,
  rig.PurchasingInfoRecord,
  rig.IsMarkedForDeletion,
  rig.Currency,
  rig.PurchaseOrderPriceUnit,
  rig.MaterialPriceUnitQty,
  rig.NetPriceAmount

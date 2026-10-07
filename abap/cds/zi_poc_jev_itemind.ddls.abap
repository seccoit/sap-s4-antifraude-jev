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
    left outer to one join eine as ri             on  ri.infnr = cur.PurchasingInfoRecord
                                                  and ri.ekorg = cur.PurchasingOrganization
                                                  and ri.esokz = '0'
                                                  and ri.werks = cur.Plant
    left outer to one join eine as rig            on  rig.infnr = cur.PurchasingInfoRecord
                                                  and rig.ekorg = cur.PurchasingOrganization
                                                  and rig.esokz = '0'
                                                  and rig.werks = ''
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
        when ri.infnr is not null and ri.loekz = '' and ri.waers = cur.DocumentCurrency
         and ri.bprme = cur.OrderPriceUnit and ri.peinh > 0 and ri.netpr > 0
          then division( cast( ri.netpr as abap.dec(11,2) ), ri.peinh, 4 )
        when rig.infnr is not null and rig.loekz = '' and rig.waers = cur.DocumentCurrency
         and rig.bprme = cur.OrderPriceUnit and rig.peinh > 0 and rig.netpr > 0
          then division( cast( rig.netpr as abap.dec(11,2) ), rig.peinh, 4 )
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
  ri.infnr,
  ri.loekz,
  ri.waers,
  ri.bprme,
  ri.peinh,
  ri.netpr,
  rig.infnr,
  rig.loekz,
  rig.waers,
  rig.bprme,
  rig.peinh,
  rig.netpr

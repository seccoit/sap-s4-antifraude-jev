@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - ultima avaliacao por pedido'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_POC_JEV_ULTAVAL
  as select from zpoc_jev_aval
{
  key purchase_order               as PurchaseOrder,
      max( aval_ts )               as LastAvalTimestamp,
      cast( count(*) as abap.int4 ) as EvaluationCount
}
group by
  purchase_order

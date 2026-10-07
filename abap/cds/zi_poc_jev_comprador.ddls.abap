@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - participacao forn. comprador'
@Metadata.ignorePropagatedAnnotations: true
/* Comprador = criador do pedido (ERNAM). Janela 12 meses ate a data do pedido, mesma moeda. */
define view entity ZI_POC_JEV_COMPRADOR
  as select from ZI_POC_JEV_PEDIDOVALOR as c
    inner join   ZI_POC_JEV_PEDIDOVALOR as h on  h.CreatedByUser    =  c.CreatedByUser
                                             and h.DocumentCurrency =  c.DocumentCurrency
                                             and h.CreationDate     >= c.Date12MonthsBefore
                                             and h.CreationDate     <= c.CreationDate
{
  key c.PurchaseOrder,
      sum( h.POTotalAmount )                                                   as BuyerTotal12m,
      sum( case when h.Supplier = c.Supplier then h.POTotalAmount
                else cast( 0 as abap.dec(15,2) ) end )                         as BuyerSupplierAmount12m
}
group by
  c.PurchaseOrder

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - historico/velocidade forn.'
@Metadata.ignorePropagatedAnnotations: true
/* Historico do fornecedor: pedidos ANTERIORES, 24 meses, mesma moeda (n, soma, soma dos quadrados).
   Velocidade: outros pedidos ao mesmo fornecedor em D-1..D e D-7..D (qualquer moeda).
   Desvio padrao/z-score sao calculados em ABAP (ZCL_POC_JEV_STATS) a partir de n, soma e soma dos quadrados. */
define view entity ZI_POC_JEV_HISTFORN
  as select from    ZI_POC_JEV_PEDIDOVALOR as c
    left outer join ZI_POC_JEV_PEDIDOVALOR as h on  h.Supplier      =  c.Supplier
                                                and h.PurchaseOrder <> c.PurchaseOrder
                                                and h.CreationDate  >= c.Date24MonthsBefore
                                                and h.CreationDate  <= c.CreationDate
{
  key c.PurchaseOrder,

      cast( sum( case when h.DocumentCurrency = c.DocumentCurrency and h.CreationDate < c.CreationDate
                      then 1 else 0 end ) as abap.int4 )                                  as SuplrHistPOCount,

      sum( case when h.DocumentCurrency = c.DocumentCurrency and h.CreationDate < c.CreationDate
                then h.POTotalAmount else cast( 0 as abap.dec(15,2) ) end )               as SuplrHistSumAmount,

      sum( case when h.DocumentCurrency = c.DocumentCurrency and h.CreationDate < c.CreationDate
                then cast( h.POTotalAmount as abap.fltp ) * cast( h.POTotalAmount as abap.fltp )
                else cast( 0 as abap.fltp ) end )                                         as SuplrHistSumSqAmount,

      cast( sum( case when h.CreationDate >= c.Date1DayBefore then 1 else 0 end ) as abap.int4 )
                                                                                          as SuplrPOCount24h,

      cast( sum( case when h.CreationDate >= c.Date7DaysBefore then 1 else 0 end ) as abap.int4 )
                                                                                          as SuplrPOCount7d
}
group by
  c.PurchaseOrder

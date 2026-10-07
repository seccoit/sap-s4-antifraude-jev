@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - valor total por pedido'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_POC_JEV_PEDIDOVALOR
  as select from ZI_POC_JEV_PEDIDOITEM
{
  key PurchaseOrder,
      Supplier,
      CreatedByUser,
      CreationDate,
      DocumentCurrency,
      Date1DayBefore,
      Date7DaysBefore,
      Date12MonthsBefore,
      Date24MonthsBefore,
      cast( sum( NetAmount ) as abap.dec(15,2) ) as POTotalAmount
}
group by
  PurchaseOrder,
  Supplier,
  CreatedByUser,
  CreationDate,
  DocumentCurrency,
  Date1DayBefore,
  Date7DaysBefore,
  Date12MonthsBefore,
  Date24MonthsBefore

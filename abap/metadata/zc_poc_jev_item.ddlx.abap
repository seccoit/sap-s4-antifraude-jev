@Metadata.layer: #CUSTOMER
@UI.headerInfo: { typeName: 'Item', typeNamePlural: 'Itens',
                  title: { value: 'PurchaseOrderItem' },
                  description: { value: 'Material' } }
annotate entity ZC_POC_JEV_ITEM with
{
  @UI.facet: [ { id: 'Item', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Item', position: 10 } ]
  @UI.hidden: true
  PurchaseOrder;

  @UI: { lineItem: [ { position: 10 } ], identification: [ { position: 10 } ] }
  @EndUserText.label: 'Item'
  PurchaseOrderItem;

  @UI: { lineItem: [ { position: 20 } ], identification: [ { position: 20 } ] }
  @EndUserText.label: 'Material'
  Material;

  @UI: { lineItem: [ { position: 30 } ], identification: [ { position: 30 } ] }
  @EndUserText.label: 'Centro'
  Plant;

  @UI: { lineItem: [ { position: 40 } ], identification: [ { position: 40 } ] }
  @EndUserText.label: 'Quantidade'
  OrderQuantity;

  @UI: { lineItem: [ { position: 50 } ], identification: [ { position: 50 } ] }
  @EndUserText.label: 'Unidade'
  OrderUnit;

  @UI: { lineItem: [ { position: 60 } ], identification: [ { position: 60 } ] }
  @EndUserText.label: 'Valor liquido'
  NetAmount;

  @UI: { lineItem: [ { position: 70 } ], identification: [ { position: 70 } ] }
  @EndUserText.label: 'Preco unitario'
  UnitPrice;

  @UI: { lineItem: [ { position: 80 } ], identification: [ { position: 80 } ] }
  @EndUserText.label: 'Preco registro info'
  InfoRecordUnitPrice;

  @UI: { lineItem: [ { position: 90, criticality: 'PriceCriticality' } ],
         identification: [ { position: 90, criticality: 'PriceCriticality' } ] }
  @EndUserText.label: 'Preco / registro info'
  PriceToInfoRecordRatio;

  @UI: { lineItem: [ { position: 100 } ], identification: [ { position: 100 } ] }
  @EndUserText.label: 'Preco / media material'
  PriceToMaterialAvgRatio;

  @UI: { lineItem: [ { position: 110 } ], identification: [ { position: 110 } ] }
  @EndUserText.label: 'Qtd / historico'
  QtyToHistRatio;

  @UI: { lineItem: [ { position: 120 } ], identification: [ { position: 120 } ] }
  @EndUserText.label: 'Material novo p/ forn.'
  MaterialNewForSupplier;

  @UI.identification: [ { position: 130 } ]
  @EndUserText.label: 'Pedidos hist. do material'
  HistMaterialPOCount;

  @UI.identification: [ { position: 140 } ]
  @EndUserText.label: 'Preco medio hist. material'
  HistMaterialAvgUnitPrice;

  @UI.identification: [ { position: 150 } ]
  @EndUserText.label: 'Itens hist. forn.+material'
  HistSuplrMaterialItemCount;

  @UI.identification: [ { position: 160 } ]
  @EndUserText.label: 'Qtd media hist. forn.+mat.'
  HistSuplrMaterialAvgQty;

  @UI.identification: [ { position: 170 } ]
  @EndUserText.label: 'Registro info'
  PurchasingInfoRecord;

  @UI.hidden: true
  PriceCriticality;
}

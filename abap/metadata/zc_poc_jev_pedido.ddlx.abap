@Metadata.layer: #CUSTOMER
@UI.headerInfo: { typeName: 'Pedido', typeNamePlural: 'Pedidos',
                  title: { value: 'PurchaseOrder' },
                  description: { value: 'RuleClassification' } }
@UI.presentationVariant: [{ sortOrder: [{ by: 'CreationDate', direction: #DESC }] }]
annotate entity ZC_POC_JEV_PEDIDO with
{
  @UI.facet: [
    { id: 'Geral',      purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Dados do pedido',        position: 10 },
    { id: 'Fornecedor', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Fornecedor', label: 'Fornecedor', position: 20 },
    { id: 'Pedido',     purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Pedido',     label: 'Pedido x historico', position: 30 },
    { id: 'Comprador',  purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Comprador',  label: 'Velocidade e comprador', position: 40 },
    { id: 'Itens',      purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Item',      label: 'Itens e indicadores', position: 50 },
    { id: 'Avaliacoes', purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Avaliacao', label: 'Avaliacoes (Jev)',    position: 60 } ]
  @UI: { lineItem:       [ { position: 10, importance: #HIGH } ],
         identification: [ { position: 10 } ],
         selectionField: [ { position: 10 } ] }
  @EndUserText.label: 'Pedido'
  PurchaseOrder;

  @UI: { lineItem: [ { position: 20, importance: #HIGH } ], identification: [ { position: 20 } ], selectionField: [ { position: 20 } ] }
  @UI.textArrangement: #TEXT_FIRST
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Supplier_VH', element: 'Supplier' } }]
  @EndUserText.label: 'Fornecedor'
  Supplier;

  @EndUserText.label: 'Nome do fornecedor'
  SupplierName;

  @UI: { lineItem: [ { position: 30 } ], identification: [ { position: 30 } ], selectionField: [ { position: 30 } ] }
  @EndUserText.label: 'Criado por'
  CreatedByUser;

  @UI: { lineItem: [ { position: 40 } ], identification: [ { position: 40 } ], selectionField: [ { position: 40 } ] }
  @EndUserText.label: 'Criado em'
  CreationDate;

  @UI: { identification: [ { position: 50 } ], selectionField: [ { position: 50 } ] }
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CompanyCodeVH', element: 'CompanyCode' } }]
  @EndUserText.label: 'Empresa'
  CompanyCode;

  @UI: { identification: [ { position: 60 } ], selectionField: [ { position: 60 } ] }
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_PurchasingOrganization', element: 'PurchasingOrganization' } }]
  @EndUserText.label: 'Org. compras'
  PurchasingOrganization;

  @UI: { identification: [ { position: 70 } ] }
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_PurchasingGroup', element: 'PurchasingGroup' } }]
  @EndUserText.label: 'Grupo compradores'
  PurchasingGroup;

  @UI: { lineItem: [ { position: 50 } ], identification: [ { position: 80 } ] }
  @EndUserText.label: 'Valor total'
  POTotalAmount;

  @UI: { identification: [ { position: 90 } ] }
  @EndUserText.label: 'Moeda'
  DocumentCurrency;

  @UI: { lineItem: [ { position: 60, criticality: 'RuleCriticality' } ], identification: [ { position: 100, criticality: 'RuleCriticality' } ],
         selectionField: [ { position: 70 } ] }
  @EndUserText.label: 'Regra'
  RuleClassification;

  @UI: { lineItem: [ { position: 70, criticality: 'ClassificationCriticality' } ],
         identification: [ { position: 110, criticality: 'ClassificationCriticality' } ],
         selectionField: [ { position: 80 } ] }
  @EndUserText.label: 'Ultima classificacao'
  LastClassification;

  @UI: { lineItem: [ { position: 80 } ], identification: [ { position: 120 } ] }
  @EndUserText.label: 'Ultimo risco max.'
  LastRiskMax;

  @UI: { identification: [ { position: 130 } ] }
  @EndUserText.label: 'Ultima avaliacao em'
  LastAvalTimestamp;

  @UI: { identification: [ { position: 140 } ] }
  @EndUserText.label: 'Qtd. avaliacoes'
  EvaluationCount;

  @UI: { lineItem: [ { position: 90, criticality: 'SupplierAgeCriticality' } ],
         fieldGroup: [ { qualifier: 'Fornecedor', position: 10, criticality: 'SupplierAgeCriticality' } ] }
  @EndUserText.label: 'Idade fornecedor (dias)'
  SupplierAgeDays;

  @UI.fieldGroup: [ { qualifier: 'Fornecedor', position: 20 } ]
  @EndUserText.label: 'Criador forn. = criador pedido'
  SupplierCreatorIsPOCreator;

  @UI.fieldGroup: [ { qualifier: 'Fornecedor', position: 30, criticality: 'RuleCriticality' } ]
  @EndUserText.label: 'Fornecedor bloqueado'
  SupplierIsBlocked;

  @UI: { lineItem: [ { position: 100, criticality: 'MDChangeCriticality' } ],
         fieldGroup: [ { qualifier: 'Fornecedor', position: 40, criticality: 'MDChangeCriticality' } ] }
  @EndUserText.label: 'Alter. banco/endereco 30d'
  MasterDataChanges30d;

  @UI.fieldGroup: [ { qualifier: 'Fornecedor', position: 50 } ]
  @EndUserText.label: 'Dias desde ult. alteracao'
  DaysSinceLastMDChange;

  @UI: { lineItem: [ { position: 110, criticality: 'SharedBankCriticality' } ],
         fieldGroup: [ { qualifier: 'Fornecedor', position: 60, criticality: 'SharedBankCriticality' } ] }
  @EndUserText.label: 'Conta bancaria compartilhada'
  SharedBankAccount;

  @UI.fieldGroup: [ { qualifier: 'Fornecedor', position: 70 } ]
  @EndUserText.label: 'Outros forn. mesma conta'
  SharedBankOtherCount;

  @UI.fieldGroup: [ { qualifier: 'Fornecedor', position: 80 } ]
  @EndUserText.label: 'Pedidos historicos (24m)'
  SuplrHistPOCount;

  @UI.fieldGroup: [ { qualifier: 'Fornecedor', position: 90 } ]
  @EndUserText.label: 'Valor medio historico'
  SuplrHistAvgAmount;

  @UI.fieldGroup: [ { qualifier: 'Fornecedor', position: 100 } ]
  @EndUserText.label: 'Desvio padrao historico'
  SuplrHistStdDevAmount;

  @UI: { lineItem: [ { position: 120 } ], fieldGroup: [ { qualifier: 'Pedido', position: 10 } ] }
  @EndUserText.label: 'Valor / media fornecedor'
  AmountToSuplrAvgRatio;

  @UI.fieldGroup: [ { qualifier: 'Pedido', position: 20 } ]
  @EndUserText.label: 'Z-score do valor'
  AmountZScore;

  @UI: { lineItem: [ { position: 130, criticality: 'PriceCriticality' } ],
         fieldGroup: [ { qualifier: 'Pedido', position: 30, criticality: 'PriceCriticality' } ] }
  @EndUserText.label: 'Preco / registro info (max)'
  MaxPriceToInfoRecordRatio;

  @UI.fieldGroup: [ { qualifier: 'Pedido', position: 40, criticality: 'PriceCriticality' } ]
  @EndUserText.label: 'Preco / media material (max)'
  MaxPriceToMaterialAvgRatio;

  @UI.fieldGroup: [ { qualifier: 'Pedido', position: 50 } ]
  @EndUserText.label: 'Qtd / historico (max)'
  MaxQtyToHistRatio;

  @UI.fieldGroup: [ { qualifier: 'Pedido', position: 60 } ]
  @EndUserText.label: 'Material novo p/ fornecedor'
  MaterialNewForSupplier;

  @UI.fieldGroup: [ { qualifier: 'Pedido', position: 70 } ]
  @EndUserText.label: 'Cond. pagto difere do padrao'
  PaymentTermsDiverge;

  @UI.fieldGroup: [ { qualifier: 'Pedido', position: 80 } ]
  @EndUserText.label: 'Cond. pagto do pedido'
  PaymentTerms;

  @UI.fieldGroup: [ { qualifier: 'Pedido', position: 90 } ]
  @EndUserText.label: 'Cond. pagto padrao forn.'
  SupplierDefaultPaymentTerms;

  @UI.fieldGroup: [ { qualifier: 'Pedido', position: 100 } ]
  @EndUserText.label: 'Pedido criado apos fatura'
  InvoiceBeforePO;

  @UI: { lineItem: [ { position: 140 } ], fieldGroup: [ { qualifier: 'Comprador', position: 10 } ] }
  @EndUserText.label: 'Pedidos ao forn. 24h'
  SuplrPOCount24h;

  @UI.fieldGroup: [ { qualifier: 'Comprador', position: 20 } ]
  @EndUserText.label: 'Pedidos ao forn. 7 dias'
  SuplrPOCount7d;

  @UI.fieldGroup: [ { qualifier: 'Comprador', position: 30 } ]
  @EndUserText.label: 'Particip. forn. no comprador %'
  BuyerSupplierSharePct;

  @UI.fieldGroup: [ { qualifier: 'Comprador', position: 40 } ]
  @EndUserText.label: 'Criador registrou EM'
  CreatorPostedGR;

  @UI.hidden: true
  SupplierAgeCriticality;
  @UI.hidden: true
  MDChangeCriticality;
  @UI.hidden: true
  SharedBankCriticality;
  @UI.hidden: true
  PriceCriticality;
  @UI.hidden: true
  RuleCriticality;
  @UI.hidden: true
  ClassificationCriticality;

  /* Base tecnica do campo calculado (desvio padrao / z-score) */
  @UI.hidden: true
  SuplrHistSumAmount;
  @UI.hidden: true
  SuplrHistSumSqAmount;
}

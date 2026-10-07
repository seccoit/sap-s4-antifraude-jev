@Metadata.layer: #CUSTOMER
@UI.headerInfo: { typeName: 'Avaliacao', typeNamePlural: 'Avaliacoes',
                  title: { value: 'Classificacao' },
                  description: { value: 'ChaveRiscoMax' } }
@UI.presentationVariant: [{ sortOrder: [{ by: 'EvaluatedAt', direction: #DESC }] }]
annotate entity ZC_POC_JEV_AVAL with
{
  @UI.facet: [
    { id: 'Resultado', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Resultado', position: 10 },
    { id: 'Jev',       purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Jev',      label: 'Probabilidades Jev', position: 20 },
    { id: 'Snapshot',  purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Snapshot', label: 'Indicadores no momento', position: 30 },
    { id: 'Decisao',   purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Decisao',  label: 'Decisao do aprovador', position: 40 } ]
  @UI.hidden: true
  EvaluationUUID;

  @UI.hidden: true
  PurchaseOrder;

  @UI: { lineItem: [ { position: 10 } ], identification: [ { position: 10 } ] }
  @EndUserText.label: 'Avaliado em'
  EvaluatedAt;

  @UI: { lineItem: [ { position: 20 } ], identification: [ { position: 20 } ] }
  @EndUserText.label: 'Avaliado por'
  EvaluatedBy;

  @UI: { lineItem: [ { position: 30, criticality: 'ClassificacaoCriticality' } ],
         identification: [ { position: 30, criticality: 'ClassificacaoCriticality' } ] }
  @EndUserText.label: 'Classificacao ABAP'
  Classificacao;

  @UI.hidden: true
  ClassificacaoCriticality;

  @UI: { lineItem: [ { position: 40 } ], identification: [ { position: 40 } ] }
  @EndUserText.label: 'Risco maximo'
  RiscoMax;

  @UI: { lineItem: [ { position: 50 } ], identification: [ { position: 50 } ] }
  @EndUserText.label: 'Chave do risco'
  ChaveRiscoMax;

  @UI: { lineItem: [ { position: 60 } ], identification: [ { position: 60 } ] }
  @EndUserText.label: 'Acao sugerida Jev'
  JevAcaoSugerida;

  @UI: { lineItem: [ { position: 70 } ], identification: [ { position: 70 } ] }
  @EndUserText.label: 'Atipicidade (1-5)'
  Atipicidade;

  @UI: { lineItem: [ { position: 80 } ], identification: [ { position: 80 } ] }
  @EndUserText.label: 'Modo sombra'
  ModoSombra;

  @UI.identification: [ { position: 90 } ]
  @EndUserText.label: 'Jev disponivel'
  JevDisponivel;

  @UI.identification: [ { position: 100 } ]
  @EndUserText.label: 'Limiar aprovacao usado'
  LimiarAprovacaoUsado;

  @UI.identification: [ { position: 110 } ]
  @EndUserText.label: 'Limiar bloqueio usado'
  LimiarBloqueioUsado;

  @UI.identification: [ { position: 120 } ]
  @EndUserText.label: 'Versao do modelo'
  JevModeloVersao;

  @UI.fieldGroup: [ { qualifier: 'Jev', position: 10 } ]
  @EndUserText.label: 'Fornecedor ficticio'
  ProbFornecedorFicticio;
  @UI.fieldGroup: [ { qualifier: 'Jev', position: 20 } ]
  @EndUserText.label: 'Desvio de pagamento'
  ProbDesvioPagamento;
  @UI.fieldGroup: [ { qualifier: 'Jev', position: 30 } ]
  @EndUserText.label: 'Sobrepreco'
  ProbSobrepreco;
  @UI.fieldGroup: [ { qualifier: 'Jev', position: 40 } ]
  @EndUserText.label: 'Fracionamento'
  ProbFracionamento;
  @UI.fieldGroup: [ { qualifier: 'Jev', position: 50 } ]
  @EndUserText.label: 'Fraude interna'
  ProbFraudeInterna;
  @UI.fieldGroup: [ { qualifier: 'Jev', position: 60 } ]
  @EndUserText.label: 'Prob. acao liberar'
  JevProbLiberar;
  @UI.fieldGroup: [ { qualifier: 'Jev', position: 70 } ]
  @EndUserText.label: 'Prob. acao aprovacao'
  JevProbAprovacao;
  @UI.fieldGroup: [ { qualifier: 'Jev', position: 80 } ]
  @EndUserText.label: 'Prob. acao bloquear'
  JevProbBloquear;

  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 10 } ]
  @EndUserText.label: 'Idade fornecedor (dias)'
  SnapSupplierAgeDays;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 20 } ]
  @EndUserText.label: 'Alter. cadastrais 30d'
  SnapMDChanges30d;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 30 } ]
  @EndUserText.label: 'Outros forn. mesma conta'
  SnapSharedBankOtherCount;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 40 } ]
  @EndUserText.label: 'Valor / media fornecedor'
  SnapAmountToSuplrAvgRatio;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 50 } ]
  @EndUserText.label: 'Z-score do valor'
  SnapAmountZScore;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 60 } ]
  @EndUserText.label: 'Preco / registro info'
  SnapPriceToInfoRecordRatio;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 70 } ]
  @EndUserText.label: 'Preco / media material'
  SnapPriceToMaterialAvgRatio;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 80 } ]
  @EndUserText.label: 'Qtd / historico'
  SnapQtyToHistRatio;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 90 } ]
  @EndUserText.label: 'Material novo p/ forn.'
  SnapMaterialNewForSupplier;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 100 } ]
  @EndUserText.label: 'Cond. pagto difere'
  SnapPaymentTermsDiverge;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 110 } ]
  @EndUserText.label: 'Pedido apos fatura'
  SnapInvoiceBeforePO;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 120 } ]
  @EndUserText.label: 'Criador registrou EM'
  SnapCreatorPostedGR;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 130 } ]
  @EndUserText.label: 'Criador forn. = criador ped.'
  SnapSupplierCreatorIsPOCreator;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 140 } ]
  @EndUserText.label: 'Pedidos ao forn. 24h'
  SnapSuplrPOCount24h;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 150 } ]
  @EndUserText.label: 'Pedidos ao forn. 7d'
  SnapSuplrPOCount7d;
  @UI.fieldGroup: [ { qualifier: 'Snapshot', position: 160 } ]
  @EndUserText.label: 'Particip. forn. comprador %'
  SnapBuyerSupplierSharePct;

  @UI.fieldGroup: [ { qualifier: 'Decisao', position: 10 } ]
  @EndUserText.label: 'Decisao'
  DecisaoAprovador;
  @UI.fieldGroup: [ { qualifier: 'Decisao', position: 20 } ]
  @EndUserText.label: 'Aprovador'
  Aprovador;
  @UI.fieldGroup: [ { qualifier: 'Decisao', position: 30 } ]
  @EndUserText.label: 'Decidido em'
  DecisaoTimestamp;
  @UI.fieldGroup: [ { qualifier: 'Decisao', position: 40 } ]
  @EndUserText.label: 'Observacao'
  DecisaoObservacao;

  @UI.hidden: true
  LocalLastChangedAt;
}

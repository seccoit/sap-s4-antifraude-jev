@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - pedidos com indicadores'
@Metadata.allowExtensions: true
define root view entity ZC_POC_JEV_PEDIDO
  provider contract transactional_query
  as projection on ZR_POC_JEV_PEDIDO
  association [0..*] to ZC_POC_JEV_ITEM as _Item on _Item.PurchaseOrder = $projection.PurchaseOrder
{
  key PurchaseOrder,
      @ObjectModel.text.element: [ 'SupplierName' ]
      Supplier,
      @Semantics.text: true
      SupplierName,
      CreatedByUser,
      CreationDate,
      CompanyCode,
      PurchasingOrganization,
      PurchasingGroup,
      PaymentTerms,
      SupplierDefaultPaymentTerms,
      DocumentCurrency,
      POTotalAmount,
      SupplierAgeDays,
      SupplierCreatorIsPOCreator,
      SupplierIsBlocked,
      MasterDataChanges30d,
      DaysSinceLastMDChange,
      SharedBankOtherCount,
      SharedBankAccount,
      SuplrHistPOCount,
      SuplrHistAvgAmount,
      SuplrHistSumAmount,
      SuplrHistSumSqAmount,
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_POC_JEV_STATS'
      virtual SuplrHistStdDevAmount : abap.dec(15,2),
      AmountToSuplrAvgRatio,
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_POC_JEV_STATS'
      virtual AmountZScore : abap.dec(11,4),
      MaxPriceToMaterialAvgRatio,
      MaxPriceToInfoRecordRatio,
      MaxQtyToHistRatio,
      MaterialNewForSupplier,
      PaymentTermsDiverge,
      InvoiceBeforePO,
      SuplrPOCount24h,
      SuplrPOCount7d,
      BuyerSupplierSharePct,
      CreatorPostedGR,
      RuleClassification,
      LastAvalTimestamp,
      LastClassification,
      LastRiskMax,
      EvaluationCount,
      SupplierAgeCriticality,
      MDChangeCriticality,
      SharedBankCriticality,
      PriceCriticality,
      RuleCriticality,
      ClassificationCriticality,

      _Avaliacao : redirected to composition child ZC_POC_JEV_AVAL,
      _Item
}

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - indicadores fornecedor'
@Metadata.ignorePropagatedAnnotations: true
/* Conta compartilhada: outros BPs com o mesmo pais/banco/conta (I_BusinessPartnerBank).
   Em S/4 a LFBK e sincronizada a partir da BUT0BK (CVI). */
define view entity ZI_POC_JEV_FORNIND
  as select from         I_PurchaseOrderAPI01        as po
    inner join           I_Supplier                  as sup   on  sup.Supplier = po.Supplier
    left outer to one join I_SupplierPurchasingOrg   as spo   on  spo.Supplier               = po.Supplier
                                                              and spo.PurchasingOrganization = po.PurchasingOrganization
    left outer to one join I_SupplierCompany         as sco   on  sco.Supplier    = po.Supplier
                                                              and sco.CompanyCode = po.CompanyCode
    left outer to one join I_SupplierToBusinessPartner as s2bp on s2bp.Supplier = po.Supplier
    left outer to one join I_BusinessPartner         as bp    on  bp.BusinessPartnerUUID = s2bp.BusinessPartnerUUID
    left outer join      I_BusinessPartnerBank       as bpbk  on  bpbk.BusinessPartner = bp.BusinessPartner
    left outer join      I_BusinessPartnerBank       as obpbk on  obpbk.BankCountryKey  =  bpbk.BankCountryKey
                                                              and obpbk.BankNumber      =  bpbk.BankNumber
                                                              and obpbk.BankAccount     =  bpbk.BankAccount
                                                              and obpbk.BusinessPartner <> bpbk.BusinessPartner
{
  key po.PurchaseOrder                                            as PurchaseOrder,
      po.Supplier                                                 as Supplier,
      sup.CreationDate                                            as SupplierCreationDate,
      dats_days_between( sup.CreationDate, po.CreationDate )      as SupplierAgeDays,

      case when sup.CreatedByUser = po.CreatedByUser or bp.CreatedByUser = po.CreatedByUser
           then cast( 'X' as abap_boolean preserving type )
           else cast( '' as abap_boolean preserving type ) end     as SupplierCreatorIsPOCreator,

      case when sup.PostingIsBlocked <> '' or sup.PurchasingIsBlocked <> '' or sup.PaymentIsBlockedForSupplier <> ''
             or ( spo.PurchasingIsBlockedForSupplier is not null and spo.PurchasingIsBlockedForSupplier <> '' )
           then cast( 'X' as abap_boolean preserving type )
           else cast( '' as abap_boolean preserving type ) end     as SupplierIsBlocked,

      case when spo.PaymentTerms is not null and spo.PaymentTerms <> '' then spo.PaymentTerms
           else sco.PaymentTerms end                               as SupplierDefaultPaymentTerms,

      case when spo.PaymentTerms is not null and spo.PaymentTerms <> '' and spo.PaymentTerms <> po.PaymentTerms
             then cast( 'X' as abap_boolean preserving type )
           when ( spo.PaymentTerms is null or spo.PaymentTerms = '' )
             and sco.PaymentTerms is not null and sco.PaymentTerms <> '' and sco.PaymentTerms <> po.PaymentTerms
             then cast( 'X' as abap_boolean preserving type )
           else cast( '' as abap_boolean preserving type ) end     as PaymentTermsDiverge,

      count( distinct obpbk.BusinessPartner )                     as SharedBankOtherBPs
}
where
      po.PurchaseOrderType              = 'NB'
  and po.SupplyingPlant                 = ''
  and po.PurchasingDocumentDeletionCode = ''
group by
  po.PurchaseOrder,
  po.Supplier,
  po.CreatedByUser,
  po.CreationDate,
  po.PaymentTerms,
  sup.CreationDate,
  sup.CreatedByUser,
  sup.PostingIsBlocked,
  sup.PurchasingIsBlocked,
  sup.PaymentIsBlockedForSupplier,
  spo.PurchasingIsBlockedForSupplier,
  spo.PaymentTerms,
  sco.PaymentTerms,
  bp.CreatedByUser

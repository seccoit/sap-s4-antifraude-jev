@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - indicadores fornecedor'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_POC_JEV_FORNIND
  as select from    ekko
    inner join      lfa1                         on  lfa1.lifnr = ekko.lifnr
    left outer to one join lfm1                  on  lfm1.lifnr = ekko.lifnr
                                                 and lfm1.ekorg = ekko.ekorg
    left outer to one join lfb1                  on  lfb1.lifnr = ekko.lifnr
                                                 and lfb1.bukrs = ekko.bukrs
    left outer to one join cvi_vend_link as cvi  on  cvi.vendor = ekko.lifnr
    left outer to one join but000                on  but000.partner_guid = cvi.partner_guid
    left outer join lfbk as bk                   on  bk.lifnr = ekko.lifnr
    left outer join lfbk as obk                  on  obk.banks =  bk.banks
                                                 and obk.bankl =  bk.bankl
                                                 and obk.bankn =  bk.bankn
                                                 and obk.lifnr <> bk.lifnr
    left outer join but0bk as bpbk               on  bpbk.partner = but000.partner
    left outer join but0bk as obpbk              on  obpbk.banks   =  bpbk.banks
                                                 and obpbk.bankl   =  bpbk.bankl
                                                 and obpbk.bankn   =  bpbk.bankn
                                                 and obpbk.partner <> bpbk.partner
{
  key ekko.ebeln                                                  as PurchaseOrder,
      ekko.lifnr                                                  as Supplier,
      lfa1.erdat                                                  as SupplierCreationDate,
      dats_days_between( lfa1.erdat, ekko.aedat )                 as SupplierAgeDays,

      case when lfa1.ernam = ekko.ernam or but000.crusr = ekko.ernam
           then cast( 'X' as abap_boolean preserving type )
           else cast( '' as abap_boolean preserving type ) end     as SupplierCreatorIsPOCreator,

      case when lfa1.sperr <> '' or lfa1.sperm <> '' or lfa1.sperz <> ''
             or ( lfm1.sperm is not null and lfm1.sperm <> '' )
           then cast( 'X' as abap_boolean preserving type )
           else cast( '' as abap_boolean preserving type ) end     as SupplierIsBlocked,

      case when lfm1.zterm is not null and lfm1.zterm <> '' then lfm1.zterm
           when lfb1.zterm is not null then lfb1.zterm
           else cast( '' as dzterm ) end                           as SupplierDefaultPaymentTerms,

      case when lfm1.zterm is not null and lfm1.zterm <> '' and lfm1.zterm <> ekko.zterm
             then cast( 'X' as abap_boolean preserving type )
           when ( lfm1.zterm is null or lfm1.zterm = '' )
             and lfb1.zterm is not null and lfb1.zterm <> '' and lfb1.zterm <> ekko.zterm
             then cast( 'X' as abap_boolean preserving type )
           else cast( '' as abap_boolean preserving type ) end     as PaymentTermsDiverge,

      count( distinct obk.lifnr )                                 as SharedBankOtherSuppliers,
      count( distinct obpbk.partner )                             as SharedBankOtherBPs
}
where
      ekko.bstyp = 'F'
  and ekko.bsart = 'NB'
  and ekko.reswk = ''
  and ekko.loekz = ''
group by
  ekko.ebeln,
  ekko.lifnr,
  ekko.ernam,
  ekko.aedat,
  ekko.zterm,
  lfa1.erdat,
  lfa1.ernam,
  lfa1.sperr,
  lfa1.sperm,
  lfa1.sperz,
  lfm1.sperm,
  lfm1.zterm,
  lfb1.zterm,
  but000.crusr

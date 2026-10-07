@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - base pedido/item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_POC_JEV_PEDIDOITEM
  as select from    ekko
    inner join      ekpo                        on ekpo.ebeln = ekko.ebeln
    inner join      lfa1                        on lfa1.lifnr = ekko.lifnr
    left outer to one join cvi_vend_link as cvi on cvi.vendor = ekko.lifnr
    left outer to one join but000               on but000.partner_guid = cvi.partner_guid
{
  key ekko.ebeln                                                     as PurchaseOrder,
  key ekpo.ebelp                                                     as PurchaseOrderItem,
      ekko.lifnr                                                     as Supplier,
      but000.partner                                                 as BusinessPartner,
      lfa1.erdat                                                     as SupplierCreationDate,
      ekko.ernam                                                     as CreatedByUser,
      ekko.aedat                                                     as CreationDate,
      dats_add_days( ekko.aedat, -1, 'NULL' )                        as Date1DayBefore,
      dats_add_days( ekko.aedat, -7, 'NULL' )                        as Date7DaysBefore,
      dats_add_days( ekko.aedat, -30, 'NULL' )                       as Date30DaysBefore,
      dats_add_months( ekko.aedat, -12, 'NULL' )                     as Date12MonthsBefore,
      dats_add_months( ekko.aedat, -24, 'NULL' )                     as Date24MonthsBefore,
      ekko.bukrs                                                     as CompanyCode,
      ekko.ekorg                                                     as PurchasingOrganization,
      ekko.ekgrp                                                     as PurchasingGroup,
      ekko.zterm                                                     as PaymentTerms,
      ekko.waers                                                     as DocumentCurrency,
      ekpo.matnr                                                     as Material,
      ekpo.werks                                                     as Plant,
      ekpo.infnr                                                     as PurchasingInfoRecord,
      ekpo.meins                                                     as OrderUnit,
      ekpo.bprme                                                     as OrderPriceUnit,
      cast( ekpo.menge as abap.dec(13,3) )                           as OrderQuantity,
      cast( ekpo.netwr as abap.dec(15,2) )                           as NetAmount,
      case when ekpo.peinh > 0
           then division( cast( ekpo.netpr as abap.dec(11,2) ), ekpo.peinh, 4 )
           else cast( 0 as abap.dec(15,4) )
      end                                                            as UnitPrice
}
where
      ekko.bstyp = 'F'
  and ekko.bsart = 'NB'
  and ekko.reswk = ''
  and ekko.loekz = ''
  and ekpo.loekz = ''
  and ekpo.retpo = ''

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - base pedido/item'
@Metadata.ignorePropagatedAnnotations: true
/* Datas-limite das janelas: parametros da ZPOC_JEV_CFG via ZI_POC_JEV_CFGPARAM (com fallback).
   Os nomes dos campos refletem os valores padrao; o tamanho real vem do parametro:
     Date7DaysBefore    -> JANELA_VELOC_DIAS      (padrao 7)
     Date30DaysBefore   -> JANELA_ALTCAD_DIAS     (padrao 30)
     Date12MonthsBefore -> JANELA_COMPRADOR_MESES (padrao 12)
     Date24MonthsBefore -> HISTORICO_MESES        (padrao 24)
   Date1DayBefore (janela "24h") e fixa. */
define view entity ZI_POC_JEV_PEDIDOITEM
  as select from         I_PurchaseOrderAPI01        as po
    inner join           I_PurchaseOrderItemAPI01    as it   on it.PurchaseOrder = po.PurchaseOrder
    inner join           I_Supplier                  as sup  on sup.Supplier = po.Supplier
    cross join           ZI_POC_JEV_CFGPARAM         as cfg
    left outer to one join I_SupplierToBusinessPartner as s2bp on s2bp.Supplier = po.Supplier
    left outer to one join I_BusinessPartner           as bp   on bp.BusinessPartnerUUID = s2bp.BusinessPartnerUUID
{
  key po.PurchaseOrder                                               as PurchaseOrder,
  key it.PurchaseOrderItem                                           as PurchaseOrderItem,
      po.Supplier                                                    as Supplier,
      bp.BusinessPartner                                             as BusinessPartner,
      sup.CreationDate                                               as SupplierCreationDate,
      po.CreatedByUser                                               as CreatedByUser,
      po.CreationDate                                                as CreationDate,
      dats_add_days( po.CreationDate, -1, 'NULL' )                   as Date1DayBefore,
      dats_add_days( po.CreationDate, 0 - cfg.JanelaVelocDias, 'NULL' )        as Date7DaysBefore,
      dats_add_days( po.CreationDate, 0 - cfg.JanelaAltCadDias, 'NULL' )       as Date30DaysBefore,
      dats_add_months( po.CreationDate, 0 - cfg.JanelaCompradorMeses, 'NULL' ) as Date12MonthsBefore,
      dats_add_months( po.CreationDate, 0 - cfg.HistoricoMeses, 'NULL' )       as Date24MonthsBefore,
      po.CompanyCode                                                 as CompanyCode,
      po.PurchasingOrganization                                      as PurchasingOrganization,
      po.PurchasingGroup                                             as PurchasingGroup,
      po.PaymentTerms                                                as PaymentTerms,
      po.DocumentCurrency                                            as DocumentCurrency,
      it.Material                                                    as Material,
      it.Plant                                                       as Plant,
      it.PurchasingInfoRecord                                        as PurchasingInfoRecord,
      it.PurchaseOrderQuantityUnit                                   as OrderUnit,
      it.OrderPriceUnit                                              as OrderPriceUnit,
      cast( it.OrderQuantity as abap.dec(13,3) )                     as OrderQuantity,
      cast( it.NetAmount as abap.dec(15,2) )                         as NetAmount,
      case when cast( it.NetPriceQuantity as abap.dec(13,3) ) > 0
           then cast( division( cast( it.NetPriceAmount as abap.dec(11,2) ),
                                cast( it.NetPriceQuantity as abap.dec(13,3) ), 4 ) as abap.dec(15,4) )
           else cast( 0 as abap.dec(15,4) )
      end                                                            as UnitPrice
}
where
      po.PurchaseOrderType              = 'NB'
  and po.SupplyingPlant                 = ''
  and po.PurchasingDocumentDeletionCode = ''
  and it.PurchasingDocumentDeletionCode = ''
  and it.IsReturnsItem                  = ''

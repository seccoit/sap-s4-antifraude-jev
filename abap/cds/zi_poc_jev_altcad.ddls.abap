@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - alteracoes cadastrais 30d'
@Metadata.ignorePropagatedAnnotations: true
/* Documentos de modificacao vem do wrapper liberado ZI_POC_JEV_W_CHGDOC (subpacote ZPOC_JEV_WRAP),
   ja filtrado para banco/endereco de fornecedor e BP. */
define view entity ZI_POC_JEV_ALTCAD
  as select from ZI_POC_JEV_PEDIDOITEM as po
    inner join   ZI_POC_JEV_W_CHGDOC   as h on(
                   (    h.ChangeDocObjectClass = 'KRED'
                    and h.ChangeDocObject      = po.Supplier )
                   or ( (    h.ChangeDocObjectClass = 'BUPA_BUP'
                          or h.ChangeDocObjectClass = 'BUPA_BANK'
                          or h.ChangeDocObjectClass = 'BUPA_ADR' )
                        and h.ChangeDocObject = po.BusinessPartner ) )
                 and h.ChangeDate >= po.Date30DaysBefore
                 and h.ChangeDate <= po.CreationDate
                 and h.ChangeDate >  po.SupplierCreationDate
{
  key po.PurchaseOrder,
      count( distinct h.ChangeDocument ) as MasterDataChanges30d,
      max( h.ChangeDate )                as LastMasterDataChangeDate
}
group by
  po.PurchaseOrder

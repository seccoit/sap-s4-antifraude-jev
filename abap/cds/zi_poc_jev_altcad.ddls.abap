@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - alteracoes cadastrais 30d'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_POC_JEV_ALTCAD
  as select from ZI_POC_JEV_PEDIDOITEM as po
    inner join   cdhdr as h on(
                   (    h.objectclas = 'KRED'
                    and h.objectid   = po.Supplier )
                   or ( (    h.objectclas = 'BUPA_BUP'
                          or h.objectclas = 'BUPA_BANK'
                          or h.objectclas = 'BUPA_ADR' )
                        and h.objectid = po.BusinessPartner ) )
                 and h.udate >= po.Date30DaysBefore
                 and h.udate <= po.CreationDate
                 and h.udate >  po.SupplierCreationDate
    inner join   cdpos as p on  p.objectclas = h.objectclas
                            and p.objectid   = h.objectid
                            and p.changenr   = h.changenr
{
  key po.PurchaseOrder,
      count( distinct h.changenr ) as MasterDataChanges30d,
      max( h.udate )               as LastMasterDataChangeDate
}
where
     p.tabname = 'LFBK'
  or p.tabname = 'BUT0BK'
  or p.tabname = 'BUT020'
  or p.tabname = 'BUT021_FS'
  or p.tabname = 'ADRC'
  or (     p.tabname = 'LFA1'
       and (    p.fname = 'STRAS' or p.fname = 'ORT01' or p.fname = 'PSTLZ'
             or p.fname = 'LAND1' or p.fname = 'REGIO' or p.fname = 'ADRNR' ) )
group by
  po.PurchaseOrder

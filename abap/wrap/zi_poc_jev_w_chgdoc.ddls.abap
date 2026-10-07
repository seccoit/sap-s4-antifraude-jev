@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - wrapper docs modif. forn/BP'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
/* Wrapper clean core (Tier 2): unica leitura de documentos de modificacao
   (I_ChangeDocument / I_ChangeDocumentItem nao liberadas). Expoe apenas
   documentos de fornecedor/BP que tocam banco ou endereco. Liberado C1. */
define view entity ZI_POC_JEV_W_CHGDOC
  as select distinct from I_ChangeDocument     as h
    inner join            I_ChangeDocumentItem as p on  p.ChangeDocObjectClass = h.ChangeDocObjectClass
                                                    and p.ChangeDocObject      = h.ChangeDocObject
                                                    and p.ChangeDocument       = h.ChangeDocument
{
  key h.ChangeDocObjectClass as ChangeDocObjectClass,
  key h.ChangeDocObject      as ChangeDocObject,
  key h.ChangeDocument       as ChangeDocument,
      h.CreationDate         as ChangeDate
}
where
  (    h.ChangeDocObjectClass = 'KRED'
    or h.ChangeDocObjectClass = 'BUPA_BUP'
    or h.ChangeDocObjectClass = 'BUPA_BANK'
    or h.ChangeDocObjectClass = 'BUPA_ADR' )
  and (    p.DatabaseTable = 'LFBK'
        or p.DatabaseTable = 'BUT0BK'
        or p.DatabaseTable = 'BUT020'
        or p.DatabaseTable = 'BUT021_FS'
        or p.DatabaseTable = 'ADRC'
        or (     p.DatabaseTable = 'LFA1'
             and (    p.ChangeDocDatabaseTableField = 'STRAS' or p.ChangeDocDatabaseTableField = 'ORT01'
                   or p.ChangeDocDatabaseTableField = 'PSTLZ' or p.ChangeDocDatabaseTableField = 'LAND1'
                   or p.ChangeDocDatabaseTableField = 'REGIO' or p.ChangeDocDatabaseTableField = 'ADRNR' ) ) )

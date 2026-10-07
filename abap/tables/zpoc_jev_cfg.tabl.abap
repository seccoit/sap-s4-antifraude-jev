@EndUserText.label : 'POC Jev - parametros e limiares'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zpoc_jev_cfg {

  key client : abap.clnt not null;
  key param  : abap.char(30) not null;
  valor_dec  : abap.dec(9,4);
  valor_txt  : abap.char(30);

}

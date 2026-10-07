@EndUserText.label: 'POC Jev - historico por pedido (TF)'
@ClientHandling.type: #CLIENT_DEPENDENT
@AccessControl.authorizationCheck: #NOT_REQUIRED
define table function ZTF_POC_JEV_HIST
  with parameters
    @Environment.systemField: #CLIENT
    p_clnt : abap.clnt
returns
{
  client                     : abap.clnt;
  PurchaseOrder              : ebeln;
  POTotalAmount              : abap.dec(15,2);
  SuplrHistPOCount           : abap.int4;
  SuplrHistAvgAmount         : abap.dec(15,2);
  SuplrHistStdDevAmount      : abap.dec(15,2);
  AmountToSuplrAvgRatio      : abap.dec(11,4);
  AmountZScore               : abap.dec(11,4);
  SuplrPOCount24h            : abap.int4;
  SuplrPOCount7d             : abap.int4;
  BuyerSupplierSharePct      : abap.dec(7,2);
  LastAvalTimestamp          : timestampl;
  LastClassificacao          : abap.char(15);
  LastRiscoMax               : abap.dec(5,4);
  AvaliacaoCount             : abap.int4;
}
implemented by method zcl_poc_jev_hist_amdp=>get_hist;

@EndUserText.label: 'POC Jev - parametro registrarAvaliacao'
define abstract entity ZA_POC_JEV_AVAL_IN
{
  JevDisponivel          : abap_boolean;
  ProbFornecedorFicticio : abap.dec(5,4);
  ProbDesvioPagamento    : abap.dec(5,4);
  ProbSobrepreco         : abap.dec(5,4);
  ProbFracionamento      : abap.dec(5,4);
  ProbFraudeInterna      : abap.dec(5,4);
  Atipicidade            : abap.int1;
  JevAcaoSugerida        : abap.char(12);
  JevProbLiberar         : abap.dec(5,4);
  JevProbAprovacao       : abap.dec(5,4);
  JevProbBloquear        : abap.dec(5,4);
  JevModeloVersao        : abap.char(30);
}

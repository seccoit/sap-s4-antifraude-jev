@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POC Jev - parametros de janela'
@Metadata.ignorePropagatedAnnotations: true
/* Parametros de janela lidos da ZPOC_JEV_CFG (mandante corrente), ja com fallback.
   Base de 1 linha garantida: I_Language (liberada C1) filtrada pelo idioma da sessao.
   Cada parametro vem por left outer join; se a linha nao existir, vale o valor fixo de reserva. */
define view entity ZI_POC_JEV_CFGPARAM
  as select from         I_Language   as lang
    left outer to one join zpoc_jev_cfg as altcad on  altcad.param = 'JANELA_ALTCAD_DIAS'
    left outer to one join zpoc_jev_cfg as veloc  on  veloc.param  = 'JANELA_VELOC_DIAS'
    left outer to one join zpoc_jev_cfg as hist   on  hist.param   = 'HISTORICO_MESES'
    left outer to one join zpoc_jev_cfg as compr  on  compr.param  = 'JANELA_COMPRADOR_MESES'
{
  key lang.Language                                                          as Language,

      /* JANELA_ALTCAD_DIAS: alteracoes cadastrais (banco/endereco) - fallback 30 dias */
      cast( coalesce( altcad.valor_dec, cast( 30 as abap.dec(9,4) ) ) as abap.int4 ) as JanelaAltCadDias,

      /* JANELA_VELOC_DIAS: pedidos ao mesmo fornecedor em N dias - fallback 7 dias */
      cast( coalesce( veloc.valor_dec, cast( 7 as abap.dec(9,4) ) ) as abap.int4 )   as JanelaVelocDias,

      /* HISTORICO_MESES: historico do fornecedor e do material - fallback 24 meses */
      cast( coalesce( hist.valor_dec, cast( 24 as abap.dec(9,4) ) ) as abap.int4 )   as HistoricoMeses,

      /* JANELA_COMPRADOR_MESES: participacao do fornecedor no comprador - fallback 12 meses */
      cast( coalesce( compr.valor_dec, cast( 12 as abap.dec(9,4) ) ) as abap.int4 )  as JanelaCompradorMeses
}
where
  lang.Language = $session.system_language

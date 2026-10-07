@EndUserText.label : 'POC Jev - avaliacoes de risco de pedidos'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zpoc_jev_aval {

  key client               : abap.clnt not null;
  key aval_uuid            : sysuuid_x16 not null;
  purchase_order           : ebeln;
  aval_ts                  : timestampl;
  aval_user                : syuname;
  snap_idade_forn_dias     : abap.int4;
  snap_alter_cad_30d       : abap.int4;
  snap_conta_compart       : abap.int4;
  snap_razao_valor_media   : abap.dec(11,4);
  snap_zscore_valor        : abap.dec(11,4);
  snap_razao_preco_ri      : abap.dec(11,4);
  snap_razao_preco_hist    : abap.dec(11,4);
  snap_razao_qtd_hist      : abap.dec(11,4);
  snap_mat_novo_forn       : abap_boolean;
  snap_zterm_diverge       : abap_boolean;
  snap_pedido_pos_fatura   : abap_boolean;
  snap_criador_registra_em : abap_boolean;
  snap_criador_forn_igual  : abap_boolean;
  snap_ped_forn_24h        : abap.int4;
  snap_ped_forn_7d         : abap.int4;
  snap_part_forn_comprador : abap.dec(7,2);
  jev_disponivel           : abap_boolean;
  prob_forn_ficticio       : abap.dec(5,4);
  prob_desvio_pagto        : abap.dec(5,4);
  prob_sobrepreco          : abap.dec(5,4);
  prob_fracionamento       : abap.dec(5,4);
  prob_fraude_interna      : abap.dec(5,4);
  atipicidade              : abap.int1;
  jev_acao_sugerida        : abap.char(12);
  jev_prob_liberar         : abap.dec(5,4);
  jev_prob_aprovacao       : abap.dec(5,4);
  jev_prob_bloquear        : abap.dec(5,4);
  jev_modelo_versao        : abap.char(30);
  risco_max                : abap.dec(5,4);
  chave_risco_max          : abap.char(30);
  classificacao            : abap.char(15);
  limiar_aprov_usado       : abap.dec(5,4);
  limiar_bloq_usado        : abap.dec(5,4);
  modo_sombra              : abap_boolean;
  decisao_aprovador        : abap.char(12);
  aprovador                : syuname;
  decisao_ts               : timestampl;
  decisao_obs              : abap.char(255);
  local_last_changed_at    : timestampl;

}

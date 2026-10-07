CLASS zcl_poc_jev_setup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS zcl_poc_jev_setup IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Carga/atualizacao dos parametros da POC Jev (idempotente).
    DATA lt_cfg TYPE STANDARD TABLE OF zpoc_jev_cfg WITH EMPTY KEY.

    lt_cfg = VALUE #(
      ( client = sy-mandt param = 'LIMIAR_APROVACAO'       valor_dec = '0.2000' )
      ( client = sy-mandt param = 'LIMIAR_BLOQUEIO'        valor_dec = '0.6000' )
      ( client = sy-mandt param = 'MODO_SOMBRA'            valor_txt = 'X' )
      ( client = sy-mandt param = 'JANELA_ALTCAD_DIAS'     valor_dec = 30 )
      ( client = sy-mandt param = 'JANELA_VELOC_DIAS'      valor_dec = 7 )
      ( client = sy-mandt param = 'HISTORICO_MESES'        valor_dec = 24 )
      ( client = sy-mandt param = 'JANELA_COMPRADOR_MESES' valor_dec = 12 ) ).

    MODIFY zpoc_jev_cfg FROM TABLE @lt_cfg.
    COMMIT WORK.

    out->write( |ZPOC_JEV_CFG: { lines( lt_cfg ) } parametros gravados.| ).
  ENDMETHOD.

ENDCLASS.

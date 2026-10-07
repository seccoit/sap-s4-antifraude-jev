*----------------------------------------------------------------------*
* Buffer transacional: avaliacoes a gravar no SAVE
*----------------------------------------------------------------------*
CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-DATA mt_aval TYPE STANDARD TABLE OF zpoc_jev_aval WITH EMPTY KEY.
ENDCLASS.

*----------------------------------------------------------------------*
* Pedido (raiz, somente leitura + acao registrarAvaliacao)
*----------------------------------------------------------------------*
CLASS lhc_pedido DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_limiar_aprov_padrao TYPE p LENGTH 5 DECIMALS 4 VALUE '0.2000',
      c_limiar_bloq_padrao  TYPE p LENGTH 5 DECIMALS 4 VALUE '0.6000'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Pedido RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK Pedido.

    METHODS read FOR READ
      IMPORTING keys FOR READ Pedido RESULT result.

    METHODS rba_avaliacao FOR READ
      IMPORTING keys_rba FOR READ Pedido\_Avaliacao FULL result_requested RESULT result LINK association_links.

    METHODS registraravaliacao FOR MODIFY
      IMPORTING keys FOR ACTION Pedido~registrarAvaliacao RESULT result.
ENDCLASS.

CLASS lhc_pedido IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%action-registrarAvaliacao = if_abap_behv=>mk-on.
      result-%action-registrarAvaliacao = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD lock.
    " Log insert-only com chave UUID: nao ha conflito de concorrencia a travar.
    RETURN.
  ENDMETHOD.

  METHOD read.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    SELECT * FROM zr_poc_jev_pedido
      FOR ALL ENTRIES IN @keys
      WHERE PurchaseOrder = @keys-PurchaseOrder
      INTO TABLE @DATA(lt_ped).

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_ped INTO DATA(ls_ped) WITH KEY PurchaseOrder = ls_key-PurchaseOrder.
      IF sy-subrc = 0.
        INSERT CORRESPONDING #( ls_ped ) INTO TABLE result.
      ELSE.
        APPEND VALUE #( %tky = ls_key-%tky %fail-cause = if_abap_behv=>cause-not_found ) TO failed-pedido.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_avaliacao.
    IF keys_rba IS INITIAL.
      RETURN.
    ENDIF.
    SELECT * FROM zr_poc_jev_aval
      FOR ALL ENTRIES IN @keys_rba
      WHERE PurchaseOrder = @keys_rba-PurchaseOrder
      INTO TABLE @DATA(lt_aval).

    LOOP AT lt_aval INTO DATA(ls_aval).
      INSERT VALUE #( source-PurchaseOrder  = ls_aval-PurchaseOrder
                      target-EvaluationUUID = ls_aval-EvaluationUUID ) INTO TABLE association_links.
      IF result_requested = abap_true.
        INSERT CORRESPONDING #( ls_aval ) INTO TABLE result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD registraravaliacao.
    DATA lv_ts TYPE timestampl.
    DATA lv_risco TYPE zpoc_jev_aval-risco_max.
    DATA lv_chave TYPE zpoc_jev_aval-chave_risco_max.

    " Limiares: tabela ZPOC_JEV_CFG com constantes de reserva
    SELECT param, valor_dec FROM zpoc_jev_cfg INTO TABLE @DATA(lt_cfg).
    DATA(lv_lim_aprov) = CONV zpoc_jev_aval-limiar_aprov_usado(
      VALUE #( lt_cfg[ param = 'LIMIAR_APROVACAO' ]-valor_dec DEFAULT c_limiar_aprov_padrao ) ).
    DATA(lv_lim_bloq) = CONV zpoc_jev_aval-limiar_bloq_usado(
      VALUE #( lt_cfg[ param = 'LIMIAR_BLOQUEIO' ]-valor_dec DEFAULT c_limiar_bloq_padrao ) ).

    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT * FROM zr_poc_jev_pedido
      FOR ALL ENTRIES IN @keys
      WHERE PurchaseOrder = @keys-PurchaseOrder
      INTO TABLE @DATA(lt_ped).

    GET TIME STAMP FIELD lv_ts.

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_ped INTO DATA(ls_ped) WITH KEY PurchaseOrder = ls_key-PurchaseOrder.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_key-%tky %fail-cause = if_abap_behv=>cause-not_found ) TO failed-pedido.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = |Pedido { ls_key-PurchaseOrder } fora do escopo da POC| ) )
               TO reported-pedido.
        CONTINUE.
      ENDIF.

      DATA(ls_p) = ls_key-%param.

      " Validacao de faixas (somente quando o Jev respondeu)
      IF ls_p-JevDisponivel = abap_true AND (
           ls_p-ProbFornecedorFicticio < 0 OR ls_p-ProbFornecedorFicticio > 1 OR
           ls_p-ProbDesvioPagamento    < 0 OR ls_p-ProbDesvioPagamento    > 1 OR
           ls_p-ProbSobrepreco         < 0 OR ls_p-ProbSobrepreco         > 1 OR
           ls_p-ProbFracionamento      < 0 OR ls_p-ProbFracionamento      > 1 OR
           ls_p-ProbFraudeInterna      < 0 OR ls_p-ProbFraudeInterna      > 1 OR
           ls_p-JevProbLiberar         < 0 OR ls_p-JevProbLiberar         > 1 OR
           ls_p-JevProbAprovacao       < 0 OR ls_p-JevProbAprovacao       > 1 OR
           ls_p-JevProbBloquear        < 0 OR ls_p-JevProbBloquear        > 1 OR
           ls_p-Atipicidade            < 1 OR ls_p-Atipicidade            > 5 ).
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-pedido.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Probabilidades devem estar entre 0 e 1 e atipicidade entre 1 e 5' ) )
               TO reported-pedido.
        CONTINUE.
      ENDIF.

      DATA(ls_db) = VALUE zpoc_jev_aval(
        client                   = sy-mandt
        purchase_order           = ls_ped-PurchaseOrder
        aval_ts                  = lv_ts
        aval_user                = sy-uname
        snap_idade_forn_dias     = ls_ped-SupplierAgeDays
        snap_alter_cad_30d       = ls_ped-MasterDataChanges30d
        snap_conta_compart       = ls_ped-SharedBankOtherCount
        snap_razao_valor_media   = ls_ped-AmountToSuplrAvgRatio
        snap_zscore_valor        = ls_ped-AmountZScore
        snap_razao_preco_ri      = ls_ped-MaxPriceToInfoRecordRatio
        snap_razao_preco_hist    = ls_ped-MaxPriceToMaterialAvgRatio
        snap_razao_qtd_hist      = ls_ped-MaxQtyToHistRatio
        snap_mat_novo_forn       = ls_ped-MaterialNewForSupplier
        snap_zterm_diverge       = ls_ped-PaymentTermsDiverge
        snap_pedido_pos_fatura   = ls_ped-InvoiceBeforePO
        snap_criador_registra_em = ls_ped-CreatorPostedGR
        snap_criador_forn_igual  = ls_ped-SupplierCreatorIsPOCreator
        snap_ped_forn_24h        = ls_ped-SuplrPOCount24h
        snap_ped_forn_7d         = ls_ped-SuplrPOCount7d
        snap_part_forn_comprador = ls_ped-BuyerSupplierSharePct
        jev_disponivel           = ls_p-JevDisponivel
        prob_forn_ficticio       = ls_p-ProbFornecedorFicticio
        prob_desvio_pagto        = ls_p-ProbDesvioPagamento
        prob_sobrepreco          = ls_p-ProbSobrepreco
        prob_fracionamento       = ls_p-ProbFracionamento
        prob_fraude_interna      = ls_p-ProbFraudeInterna
        atipicidade              = ls_p-Atipicidade
        jev_acao_sugerida        = to_upper( ls_p-JevAcaoSugerida )
        jev_prob_liberar         = ls_p-JevProbLiberar
        jev_prob_aprovacao       = ls_p-JevProbAprovacao
        jev_prob_bloquear        = ls_p-JevProbBloquear
        jev_modelo_versao        = ls_p-JevModeloVersao
        limiar_aprov_usado       = lv_lim_aprov
        limiar_bloq_usado        = lv_lim_bloq
        modo_sombra              = abap_true
        local_last_changed_at    = lv_ts ).

      TRY.
          ls_db-aval_uuid = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error.
          APPEND VALUE #( %tky = ls_key-%tky ) TO failed-pedido.
          APPEND VALUE #( %tky = ls_key-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = 'Falha ao gerar UUID da avaliacao' ) )
                 TO reported-pedido.
          CONTINUE.
      ENDTRY.

      " Risco maximo e chave que disparou
      lv_risco = ls_p-ProbFornecedorFicticio. lv_chave = 'FORNECEDOR_FICTICIO'.
      IF ls_p-ProbDesvioPagamento > lv_risco.
        lv_risco = ls_p-ProbDesvioPagamento. lv_chave = 'DESVIO_PAGAMENTO'.
      ENDIF.
      IF ls_p-ProbSobrepreco > lv_risco.
        lv_risco = ls_p-ProbSobrepreco. lv_chave = 'SOBREPRECO'.
      ENDIF.
      IF ls_p-ProbFracionamento > lv_risco.
        lv_risco = ls_p-ProbFracionamento. lv_chave = 'FRACIONAMENTO'.
      ENDIF.
      IF ls_p-ProbFraudeInterna > lv_risco.
        lv_risco = ls_p-ProbFraudeInterna. lv_chave = 'FRAUDE_INTERNA'.
      ENDIF.

      " Classificacao ABAP (modo sombra: nada e bloqueado de verdade)
      IF ls_ped-RuleClassification = 'BLOQUEIO_REGRA'.
        ls_db-classificacao   = 'BLOQUEIO_REGRA'.
        ls_db-chave_risco_max = 'FORNECEDOR_BLOQUEADO'.
        ls_db-risco_max       = 1.
      ELSEIF ls_p-JevDisponivel = abap_false.
        ls_db-classificacao   = 'INDISPONIVEL'.
        CLEAR: ls_db-risco_max, ls_db-chave_risco_max.
      ELSE.
        ls_db-risco_max       = lv_risco.
        ls_db-chave_risco_max = lv_chave.
        IF lv_risco < lv_lim_aprov.
          ls_db-classificacao = 'LIBERA'.
        ELSEIF lv_risco <= lv_lim_bloq.
          ls_db-classificacao = 'APROVACAO'.
        ELSE.
          ls_db-classificacao = 'BLOQUEIA'.
        ENDIF.
      ENDIF.

      APPEND ls_db TO lcl_buffer=>mt_aval.

      APPEND VALUE #( %tky   = ls_key-%tky
                      %param = CORRESPONDING #( ls_ped ) ) TO result.
      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Avaliacao registrada: { ls_db-classificacao } (modo sombra)| ) )
             TO reported-pedido.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* Avaliacao (filha, somente leitura)
*----------------------------------------------------------------------*
CLASS lhc_avaliacao DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS read FOR READ
      IMPORTING keys FOR READ Avaliacao RESULT result.

    METHODS rba_pedido FOR READ
      IMPORTING keys_rba FOR READ Avaliacao\_Pedido FULL result_requested RESULT result LINK association_links.
ENDCLASS.

CLASS lhc_avaliacao IMPLEMENTATION.

  METHOD read.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    SELECT * FROM zr_poc_jev_aval
      FOR ALL ENTRIES IN @keys
      WHERE EvaluationUUID = @keys-EvaluationUUID
      INTO TABLE @DATA(lt_aval).

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_aval INTO DATA(ls_aval) WITH KEY EvaluationUUID = ls_key-EvaluationUUID.
      IF sy-subrc = 0.
        INSERT CORRESPONDING #( ls_aval ) INTO TABLE result.
      ELSE.
        APPEND VALUE #( %tky = ls_key-%tky %fail-cause = if_abap_behv=>cause-not_found ) TO failed-avaliacao.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_pedido.
    IF keys_rba IS INITIAL.
      RETURN.
    ENDIF.
    SELECT EvaluationUUID, PurchaseOrder FROM zr_poc_jev_aval
      FOR ALL ENTRIES IN @keys_rba
      WHERE EvaluationUUID = @keys_rba-EvaluationUUID
      INTO TABLE @DATA(lt_link).
    IF lt_link IS INITIAL.
      RETURN.
    ENDIF.

    SELECT * FROM zr_poc_jev_pedido
      FOR ALL ENTRIES IN @lt_link
      WHERE PurchaseOrder = @lt_link-PurchaseOrder
      INTO TABLE @DATA(lt_ped).

    LOOP AT lt_link INTO DATA(ls_link).
      INSERT VALUE #( source-EvaluationUUID = ls_link-EvaluationUUID
                      target-PurchaseOrder  = ls_link-PurchaseOrder ) INTO TABLE association_links.
      IF result_requested = abap_true.
        READ TABLE lt_ped INTO DATA(ls_ped) WITH KEY PurchaseOrder = ls_link-PurchaseOrder.
        IF sy-subrc = 0 AND NOT line_exists( result[ PurchaseOrder = ls_ped-PurchaseOrder ] ).
          INSERT CORRESPONDING #( ls_ped ) INTO TABLE result.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* Saver: grava o log de avaliacoes
*----------------------------------------------------------------------*
CLASS lsc_zr_poc_jev_pedido DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize          REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save              REDEFINITION.
    METHODS cleanup           REDEFINITION.
    METHODS cleanup_finalize  REDEFINITION.
ENDCLASS.

CLASS lsc_zr_poc_jev_pedido IMPLEMENTATION.

  METHOD finalize.
    RETURN.
  ENDMETHOD.

  METHOD check_before_save.
    RETURN.
  ENDMETHOD.

  METHOD save.
    IF lcl_buffer=>mt_aval IS NOT INITIAL.
      INSERT zpoc_jev_aval FROM TABLE @lcl_buffer=>mt_aval.
    ENDIF.
  ENDMETHOD.

  METHOD cleanup.
    CLEAR lcl_buffer=>mt_aval.
  ENDMETHOD.

  METHOD cleanup_finalize.
    CLEAR lcl_buffer=>mt_aval.
  ENDMETHOD.

ENDCLASS.

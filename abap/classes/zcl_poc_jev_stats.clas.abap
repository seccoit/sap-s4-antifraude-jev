"! <p class="shorttext synchronized">POC Jev - desvio padrao / z-score</p>
"! Calcula, a partir de n, soma e soma dos quadrados do historico do fornecedor,
"! o desvio padrao amostral e o z-score do valor do pedido.
"! Usado como elemento virtual em ZC_POC_JEV_PEDIDO e no snapshot da acao registrarAvaliacao.
CLASS zcl_poc_jev_stats DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

    TYPES ty_amount TYPE p LENGTH 8 DECIMALS 2.
    TYPES ty_ratio  TYPE p LENGTH 6 DECIMALS 4.

    "! Desvio padrao amostral (equivalente ao STDDEV do HANA); 0 quando n menor que 2
    CLASS-METHODS stddev
      IMPORTING iv_n             TYPE numeric
                iv_sum           TYPE numeric
                iv_sumsq         TYPE numeric
      RETURNING VALUE(rv_stddev) TYPE ty_amount.

    "! Z-score do valor contra o historico; 0 quando o desvio e 0
    CLASS-METHODS zscore
      IMPORTING iv_value         TYPE numeric
                iv_n             TYPE numeric
                iv_sum           TYPE numeric
                iv_sumsq         TYPE numeric
      RETURNING VALUE(rv_zscore) TYPE ty_ratio.

  PRIVATE SECTION.
    CLASS-METHODS stddev_raw
      IMPORTING iv_n         TYPE numeric
                iv_sum       TYPE numeric
                iv_sumsq     TYPE numeric
      RETURNING VALUE(rv_sd) TYPE f.
ENDCLASS.



CLASS zcl_poc_jev_stats IMPLEMENTATION.

  METHOD stddev_raw.
    DATA(lv_n)     = CONV f( iv_n ).
    DATA(lv_sum)   = CONV f( iv_sum ).
    DATA(lv_sumsq) = CONV f( iv_sumsq ).

    IF lv_n < 2.
      RETURN.
    ENDIF.

    DATA(lv_var) = ( lv_sumsq - lv_sum * lv_sum / lv_n ) / ( lv_n - 1 ).

    " Erro de ponto flutuante: valores todos iguais devem dar desvio 0
    IF lv_var <= abs( lv_sumsq ) * CONV f( '1E-12' ).
      RETURN.
    ENDIF.

    rv_sd = sqrt( lv_var ).
  ENDMETHOD.


  METHOD stddev.
    " Truncado em 2 casas (nao arredondado), como o CAST DECIMAL do HANA na antiga AMDP
    TRY.
        rv_stddev = trunc( stddev_raw( iv_n = iv_n iv_sum = iv_sum iv_sumsq = iv_sumsq ) * 100 ) / 100.
      CATCH cx_sy_arithmetic_error.
        CLEAR rv_stddev.
    ENDTRY.
  ENDMETHOD.


  METHOD zscore.
    " Truncado em 4 casas (nao arredondado), como o CAST DECIMAL do HANA na antiga AMDP
    TRY.
        DATA(lv_sd) = stddev_raw( iv_n = iv_n iv_sum = iv_sum iv_sumsq = iv_sumsq ).
        IF lv_sd <= 0.
          RETURN.
        ENDIF.
        DATA(lv_z) = ( CONV f( iv_value ) - CONV f( iv_sum ) / CONV f( iv_n ) ) / lv_sd.
        rv_zscore = trunc( lv_z * 10000 ) / 10000.
      CATCH cx_sy_arithmetic_error.
        CLEAR rv_zscore.
    ENDTRY.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    et_requested_orig_elements = VALUE #( ( `POTOTALAMOUNT` )
                                          ( `SUPLRHISTPOCOUNT` )
                                          ( `SUPLRHISTSUMAMOUNT` )
                                          ( `SUPLRHISTSUMSQAMOUNT` ) ).
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA lt_ped TYPE STANDARD TABLE OF zc_poc_jev_pedido WITH DEFAULT KEY.

    lt_ped = CORRESPONDING #( it_original_data ).

    LOOP AT lt_ped ASSIGNING FIELD-SYMBOL(<ls_ped>).
      <ls_ped>-SuplrHistStdDevAmount = stddev( iv_n     = <ls_ped>-SuplrHistPOCount
                                               iv_sum   = <ls_ped>-SuplrHistSumAmount
                                               iv_sumsq = <ls_ped>-SuplrHistSumSqAmount ).
      <ls_ped>-AmountZScore = zscore( iv_value = <ls_ped>-POTotalAmount
                                      iv_n     = <ls_ped>-SuplrHistPOCount
                                      iv_sum   = <ls_ped>-SuplrHistSumAmount
                                      iv_sumsq = <ls_ped>-SuplrHistSumSqAmount ).
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_ped ).
  ENDMETHOD.

ENDCLASS.

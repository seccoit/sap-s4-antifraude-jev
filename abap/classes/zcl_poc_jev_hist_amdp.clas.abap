CLASS zcl_poc_jev_hist_amdp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_amdp_marker_hdb.
    CLASS-METHODS get_hist FOR TABLE FUNCTION ztf_poc_jev_hist.
ENDCLASS.



CLASS zcl_poc_jev_hist_amdp IMPLEMENTATION.

  METHOD get_hist BY DATABASE FUNCTION FOR HDB LANGUAGE SQLSCRIPT
                  OPTIONS READ-ONLY
                  USING ekko ekpo zpoc_jev_aval.

    -- pedidos no escopo (NB, sem intercompany, sem devolucao, sem eliminados)
    po = SELECT k.mandt AS client, k.ebeln, k.lifnr, k.ernam, k.aedat, k.waers,
                TO_DATS( ADD_DAYS(   TO_DATE( k.aedat, 'YYYYMMDD' ), -1 ) )  AS d1,
                TO_DATS( ADD_DAYS(   TO_DATE( k.aedat, 'YYYYMMDD' ), -7 ) )  AS d7,
                TO_DATS( ADD_MONTHS( TO_DATE( k.aedat, 'YYYYMMDD' ), -12 ) ) AS d12m,
                TO_DATS( ADD_MONTHS( TO_DATE( k.aedat, 'YYYYMMDD' ), -24 ) ) AS d24m,
                SUM( p.netwr ) AS total
           FROM ekko AS k
          INNER JOIN ekpo AS p ON p.mandt = k.mandt AND p.ebeln = k.ebeln
          WHERE k.mandt = :p_clnt
            AND k.bstyp = 'F' AND k.bsart = 'NB' AND k.reswk = '' AND k.loekz = ''
            AND p.loekz = '' AND p.retpo = ''
          GROUP BY k.mandt, k.ebeln, k.lifnr, k.ernam, k.aedat, k.waers;

    -- historico do fornecedor (24 meses, anteriores, mesma moeda)
    hist = SELECT c.ebeln,
                  COUNT( h.ebeln )  AS cnt,
                  AVG( h.total )    AS avg_amt,
                  STDDEV( h.total ) AS sd_amt
             FROM :po AS c
             LEFT OUTER JOIN :po AS h
               ON h.lifnr = c.lifnr AND h.waers = c.waers AND h.ebeln <> c.ebeln
              AND h.aedat < c.aedat AND h.aedat >= c.d24m
            GROUP BY c.ebeln;

    -- velocidade: outros pedidos ao mesmo fornecedor em D-1..D e D-7..D
    vel = SELECT c.ebeln,
                 SUM( CASE WHEN h.ebeln IS NOT NULL AND h.aedat >= c.d1 THEN 1 ELSE 0 END ) AS c24,
                 COUNT( h.ebeln ) AS c7
            FROM :po AS c
            LEFT OUTER JOIN :po AS h
              ON h.lifnr = c.lifnr AND h.ebeln <> c.ebeln
             AND h.aedat >= c.d7 AND h.aedat <= c.aedat
           GROUP BY c.ebeln;

    -- participacao do fornecedor nas compras do comprador (ERNAM, 12 meses, mesma moeda)
    shr = SELECT c.ebeln,
                 SUM( CASE WHEN h.lifnr = c.lifnr THEN h.total ELSE 0 END ) AS sup_amt,
                 SUM( h.total ) AS tot_amt
            FROM :po AS c
           INNER JOIN :po AS h
              ON h.ernam = c.ernam AND h.waers = c.waers
             AND h.aedat >= c.d12m AND h.aedat <= c.aedat
           GROUP BY c.ebeln;

    -- ultima avaliacao gravada
    av = SELECT purchase_order AS ebeln, aval_ts, classificacao, risco_max,
                ROW_NUMBER( ) OVER ( PARTITION BY purchase_order ORDER BY aval_ts DESC ) AS rn,
                COUNT( * ) OVER ( PARTITION BY purchase_order ) AS cnt
           FROM zpoc_jev_aval
          WHERE client = :p_clnt;

    RETURN
      SELECT c.client,
             c.ebeln                                                          AS purchaseorder,
             CAST( c.total AS DECIMAL(15,2) )                                 AS pototalamount,
             CAST( IFNULL( h.cnt, 0 ) AS INTEGER )                            AS suplrhistpocount,
             CAST( IFNULL( h.avg_amt, 0 ) AS DECIMAL(15,2) )                  AS suplrhistavgamount,
             CAST( IFNULL( h.sd_amt, 0 ) AS DECIMAL(15,2) )                   AS suplrhiststddevamount,
             CAST( CASE WHEN h.avg_amt > 0 THEN c.total / h.avg_amt ELSE 0 END AS DECIMAL(11,4) )
                                                                              AS amounttosuplravgratio,
             CAST( CASE WHEN h.sd_amt > 0 THEN ( c.total - h.avg_amt ) / h.sd_amt ELSE 0 END AS DECIMAL(11,4) )
                                                                              AS amountzscore,
             CAST( IFNULL( v.c24, 0 ) AS INTEGER )                            AS suplrpocount24h,
             CAST( IFNULL( v.c7, 0 ) AS INTEGER )                             AS suplrpocount7d,
             CAST( CASE WHEN s.tot_amt > 0 THEN s.sup_amt * 100 / s.tot_amt ELSE 0 END AS DECIMAL(7,2) )
                                                                              AS buyersuppliersharepct,
             CAST( IFNULL( a.aval_ts, 0 ) AS DECIMAL(21,7) )                  AS lastavaltimestamp,
             CAST( IFNULL( a.classificacao, '' ) AS NVARCHAR(15) )            AS lastclassificacao,
             CAST( IFNULL( a.risco_max, 0 ) AS DECIMAL(5,4) )                 AS lastriscomax,
             CAST( IFNULL( a.cnt, 0 ) AS INTEGER )                            AS avaliacaocount
        FROM :po AS c
        LEFT OUTER JOIN :hist AS h ON h.ebeln = c.ebeln
        LEFT OUTER JOIN :vel  AS v ON v.ebeln = c.ebeln
        LEFT OUTER JOIN :shr  AS s ON s.ebeln = c.ebeln
        LEFT OUTER JOIN :av   AS a ON a.ebeln = c.ebeln AND a.rn = 1;

  ENDMETHOD.

ENDCLASS.

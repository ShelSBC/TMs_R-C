CREATE OR REPLACE TABLE  `crp-pro-cx-analitica.mus_pro_negfin_tablas_finales.DIM_NEGFIN_SOBREGIROS` AS
WITH AUTHKEY AS           							
          							
(    SELECT * EXCEPT (RR_AUTH_KEYS_VALUE_N_32),
          --     LAST_VALUE(RR_AUTH_KEYS_VALUE_N_32) OVER (PARTITION BY CTA_TRACK, DATE_TRUNC(RRHEADER_PROC_DATE_CYMD, MONTH) ORDER BY RRHEADER_PROC_DATE_CYMD 
          --     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS LC, 
              FIRST_VALUE(
              CASE WHEN DECISION = '1' THEN RR_AUTH_KEYS_VALUE_N_32 END) OVER (PARTITION BY CTA_TRACK, DATE_TRUNC(RRHEADER_PROC_DATE_CYMD, MONTH) 
              ORDER BY CASE WHEN DECISION = '1' THEN 0 ELSE 1 END ASC, RRHEADER_PROC_DATE_CYMD DESC) AS LC,
              LAST_VALUE(RRHEADER_SPID) OVER (PARTITION BY CTA_TRACK, DATE_TRUNC(RRHEADER_PROC_DATE_CYMD, MONTH) ORDER BY RRHEADER_PROC_DATE_CYMD 
              ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS SPID,  
              FROM 
              (					
              SELECT          							
              RRHEADER_ACCOUNT_ID,      							
              COALESCE(B.CTA_ACT, A.RRHEADER_ACCOUNT_ID) AS CTA_TRACK,
              RRHEADER_PROC_DATE_CYMD,          							
              RRHEADER_SPID,    							
              EXTRACT (YEAR FROM RRHEADER_PROC_DATE_CYMD) AS ANIO,          							
              EXTRACT (MONTH FROM RRHEADER_PROC_DATE_CYMD) AS MES,          							
              RR_AUTH_KEYS_VALUE_N_32 , -- Linea de Cred 							
              RR_AUTH_KEYS_VALUE_N_18 AS SALDO,  -- saldo         							
              RR_AUTH_KEYS_VALUE_N_18 + RR_AUTH_KEYS_VALUE_N_80 AS SDO_ACT,         							
              RR_AUTH_KEYS_VALUE_N_36 AS CD, -- Cycles-Delinquent         							
              RR_AUTH_KEYS_VALUE_N_50 AS MOB, -- MOB          							
              RR_AUTH_KEYS_VALUE_N_58 AS MESES_DSD_ULT_INC, -- Meses dsd ult incr         							
              RR_AUTH_KEYS_VALUE_N_403 AS GRUPO_SECCION, -- Grupo de sección          							
              RR_AUTH_KEYS_VALUE_N_80 AS MTO_TRN, -- Monto de la transaccion          												
              RR_AUTH_KEYS_VALUE_N_97 AS DECISION,  -- Decision Aprobado 1 rechazado 2          							
							
               --ROW_NUMBER() OVER(PARTITION BY RRHEADER_ACCOUNT_ID order by RRHEADER_PROC_DATE_CYMD) as ID_ASC,          							
          							
              from `crp-pro-dwh-semanticagold.MUS_PRO_DWH_VIEWS_ODS.VFAC_NEGFIN_TRD_KEY_AUTH`  A          							
              LEFT JOIN `crp-pro-dwh-semanticagold.EIL_DP_VDWH.VDIM_CTA_TRACK` AS B         							
              ON A.RRHEADER_ACCOUNT_ID=B.CTA_CVE          							
              WHERE  RR_AUTH_KEYS_VALUE_N_97 IN ('1','2')   
                    AND RR_AUTH_KEYS_VALUE_N_80 != 1					
                                              AND RRHEADER_ACCOUNT_ID NOT IN (0000013000014130061         							
                                              ,0000013000014130103,0000013000030903400,0000013000036791957,0000013000039252205          							
                                              ,0000013000039252239,0004178490016978240,0004178490016978257,0004178490016978265          							
                                              ,0004178490016978273,0004178490017095119,0004178490019654053,         							
                                              /*2023*/ 0000013000050440044, 0000013000050441661, 0000013000050440069          							
                                              ,0000013000050440028
                                              /*2026*/
                                              ,0000053000001042692,0000053000001042700,0000063000000122386,0000063000000122394,
                                                0004178499001826553,0004178499011812098,0006400000000165095,0006400000000165103
                                                )      							
                    AND RRHEADER_PROC_DATE_CYMD >= '2019-09-01' 
              )        							
) --1,279,251         							





--SELECT SPID, DECISION, COUNT (*) FROM AUTHKEY GROUP BY ALL  -------AQUI CUADRA          							
          							
/*1.2 Grupo de sección          							
Insumo para distinguir el grupo de sección por el que se genera la transaccioón*/         							
          							
          							
,SECCION AS           							
(         							
SELECT          							
              CTA_TRACK,          							
              ANIO,         							
              MES,          							
              CASE WHEN COUNTIF(GRUPO_SECCION = 0) > 0 AND COUNTIF(GRUPO_SECCION IN (1,2,3)) > 0 THEN 3 --'No Big Ticket y Big Ticket'          							
                   WHEN COUNTIF(GRUPO_SECCION = 0) > 0 AND COUNTIF(GRUPO_SECCION IN (1,2,3)) = 0 THEN 1 --'No Big Ticket'         							
                   WHEN COUNTIF(GRUPO_SECCION = 0) = 0 AND COUNTIF(GRUPO_SECCION IN (1,2,3)) > 0 THEN 2 --'Big Ticket'          							
                   END AS G_SECCION,          							
              FROM AUTHKEY          							
              GROUP BY CTA_TRACK, ANIO, MES         							
)--373268         							

/*1.3 Distinción entre Trn Aprobadas y Rechazadas         							
Insumo para separar a las transacciones aprobadas y rechazadas de cada cuenta*/         							


          							
,APR_RCH AS           							
(         							
SELECT          							
              CTA_TRACK, ANIO,MES,          							
              count (distinct cta_track ) as CUENTAS,         							
              SUM (CASE WHEN DECISION = '1' THEN 1 ELSE 0 END ) AS APROBADO,          							
              SUM (CASE WHEN DECISION = '2' THEN 1 ELSE 0 END ) AS RECHAZADO,         							
              FROM AUTHKEY GROUP BY ALL         							
) --373268          							
          							


/*1.4 Sobregiros Manuales         							
Insumo de Sobregiros que son aprobados por el área de Analisis de Crédito se ingresa AUTO en VPL y viaja a DWH*/          							
          							
,AC_MANUAL AS           							
(         							
SELECT          							
              COALESCE(B.CTA_ACT, A.CTA_CVE) AS CTA_TRACK,          							
              EXTRACT (YEAR FROM FCH_FCH) AS ANIO,          							
              EXTRACT (MONTH FROM FCH_FCH) AS MES,          							
              SUM(CTA_IMP_LIM_DES) AS MONTO_SOB,          							
              COUNT (*) AS VCS_SOB          							
              from crp-pro-dwh-semanticagold.EIL_DP_VDWH.VFAC_SDO_CTA_AUT A         							
              LEFT JOIN `crp-pro-dwh-semanticagold.EIL_DP_VDWH.VDIM_CTA_TRACK` AS B         							
              ON A.CTA_CVE=B.CTA_CVE          							
              WHERE FCH_FCH >= '2019-09-01'         							
              GROUP BY ALL          							
)--1765         							
          							
		
/*1.5         							
Union de bases*/          							
          							
          							
,AUTHKEY_2 AS           							
(         							
SELECT DISTINCT         							
              A.*,          							
              B.G_SECCION AS SECCION,         							
              C.APROBADO AS TRN_APROB,          							
              C.RECHAZADO AS TRN_RECH,          							
              FROM (          							
              SELECT          							
                    CTA_TRACK,          							
                    ANIO,         							
                    MES,          							
                    SPID,         							
                    LC,         							
                    DECISION,         							
                    MAX(SDO_ACT) AS SALDO,          							
                    SUM(MTO_TRN) AS MONTO_TOTAL,          							
                    MAX(SDO_ACT) - LC AS EXCEDENTE,         							
                    COUNT (*) AS TRN          							
                            FROM AUTHKEY          							
                            GROUP BY ALL --420492         							
              ) A         							
          							
              LEFT JOIN SECCION B           							
              ON A.CTA_TRACK=B.CTA_TRACK AND A.ANIO = B.ANIO AND A.MES = B.MES          							
          							
              LEFT JOIN APR_RCH C           							
              ON A.CTA_TRACK=C.CTA_TRACK AND A.ANIO = C.ANIO AND A.MES = C.MES          							
          							
) -- 420492         							
	 							
          													
          							         							
--SELECT SPID, ANIO,MES, DECISION, SUM(TRN) FROM AUTHKEY_2 GROUP BY ALL --- AQUI CUADRA         							
          							
          							
,AUTHKEY_3 AS           							
(SELECT * FROM AUTHKEY_2 WHERE DECISION = '1') --265832         							
          							

 							
     							
--SELECT SPID, ANIO,MES, DECISION, SUM(TRN) FROM AUTHKEY_3 GROUP BY ALL --- AQUI CUADRA         							
          							
          							
,SDO_CTA_MES AS           							
(         							
                        SELECT          							
                        COALESCE(B.CTA_ACT, A.CTA_CVE) AS CTA_TRACK,          							
                        A.ANIO,         							
                        A.MES,          							
                        A.TIP_INF,          							
                        CASE WHEN A.CTA_IMP_LIM_CRD < A.CTA_SDO_ACT THEN 1 ELSE 0 END AS FLG_EXCED,         							
                        CTA_SDO_ACT,          							
                        FROM `crp-pro-dwh-semanticagold.EIL_DP_VDWH.VFAC_SDO_CTA_MES`  A          							
                        left join `crp-pro-dwh-semanticagold.EIL_DP_VDWH.VDIM_CTA_TRACK`  B           							
                        on A.cta_cve=B.cta_cve          							
                        WHERE A.TIP_INF in (100,110,210,200,220,230)          							
                        AND (         							
                        (a.ANIO = 2019 AND a.MES >= 09) OR          							
                        (a.ANIO >= 2020)          							
                             )          							
                        and a.cta_edo_cve not in ('T')          							
)           							
          							
          							
          							
,AUTHKEY_4 AS           							
(         							
              SELECT          							
              CASE WHEN A.CTA_TRACK IS NULL THEN CTA_AC ELSE A.CTA_TRACK END AS CTA_CVE,          							
              CASE WHEN A.ANIO IS NULL THEN ANIO_AC ELSE A.ANIO END AS ANIO_ESTR,         							
              CASE WHEN A.MES IS NULL THEN MES_AC ELSE A.MES END AS MES_ESTR,         							
              SPID,         							
              LC AS LC_TRD,         							
              SALDO AS SDO_TRD,         							
              MONTO_TOTAL AS MONTO_TRD,         							
              EXCEDENTE AS IMP_SOBREGIRO,         							
              SECCION,          							
              TRN AS TRN_APROB,         							    							
              TRN_RECH,         							
              TRN + TRN_RECH AS TRN_TRD,          							
              TRN_APROB_AC,         							
              COALESCE(TRN, 0) + COALESCE(TRN_APROB_AC, 0) AS TOT_APRB,        							
              MONTO_AC,						
              COALESCE(MONTO_TOTAL, 0) + COALESCE(MONTO_AC, 0) AS TOT_MONTO,

              CASE WHEN TRN_APROB > 0 AND TRN_APROB_AC IS NULL and SECCION IS NULL THEN 1 -- TRIAD BIG TICKET/NO BIGTICKET          							
                   WHEN TRN_APROB > 0 AND TRN_APROB_AC IS NULL and SECCION = 1     THEN 2 -- TRIAD NO BIGTICKET         							
                   WHEN TRN_APROB > 0 AND TRN_APROB_AC IS NULL and SECCION = 2     THEN 3 -- TRIAD BIGTICKET          							
                   WHEN TRN_APROB > 0 AND TRN_APROB_AC IS NULL and SECCION = 3     THEN 1 -- TRIAD BIGTICKET/NO BIGTICKET         							
                   WHEN TRN_APROB > 0 AND TRN_APROB_AC > 0 and SECCION = 1         THEN 4 -- TRIAD NO BIGTICKET + MANUAL          							
                   WHEN TRN_APROB > 0 AND TRN_APROB_AC > 0 and SECCION = 2         THEN 5 -- TRIAD BIGTICKET + MANUAL         							
                   WHEN TRN_APROB > 0 AND TRN_APROB_AC > 0 and SECCION = 3         THEN 6 -- TRIAD BIGTICKET/NO BIGTICKET + MANUAL          							
                   WHEN TRN_APROB > 0 AND TRN_APROB_AC > 0 and SECCION IS NULL     THEN 6 -- TRIAD BIGTICKET/NO BIGTICKET + MANUAL          							
                   WHEN TRN_APROB IS NULL AND TRN_APROB_AC > 0                     THEN 7 -- MANUAL         							
                   END AS FLG_SOB         							
              FROM (          							
              SELECT A.*,           							
              B.CTA_TRACK AS CTA_AC, B.MONTO_SOB AS MONTO_AC, B.ANIO AS ANIO_AC, B.MES AS MES_AC, B.VCS_SOB AS TRN_APROB_AC         							
              FROM AUTHKEY_3 A          							
              FULL JOIN AC_MANUAL B           							
              ON A.CTA_TRACK=B.CTA_TRACK AND A.ANIO = B.ANIO AND A.MES = B.MES          							
                   ) a          							
) --267417          							


,AUTHKEY_5 AS           							
(         							
SELECT  DISTINCT
 A.*, B.FLG_EXCED, B.TIP_INF, B.CTA_SDO_ACT AS SDO_CIERRE       							
 FROM AUTHKEY_4 A           							
 LEFT JOIN SDO_CTA_MES B          							
 ON  A.CTA_CVE =B.CTA_TRACK AND A.ANIO_ESTR = B.ANIO AND A.MES_ESTR = B.MES   							
)




SELECT * FROM AUTHKEY_5 WHERE TIP_INF IS NOT NULL

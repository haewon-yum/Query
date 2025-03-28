/* 
    longterm metric (e.g. D30, D60 ROAS) comparision and statistical significance for control and test group
    (case: 111Percent, https://docs.google.com/document/d/1fqEZry2O5sll8hPuzT-5GlxMhvM9ky1iW8e2wjnUV7I/edit?tab=t.0)

(from 두형님)
    안녕하세요 해원님!
    D7 이후의 custom event (2nd purchase) 에서 나온 로아스를 뽑아보시려면 prod_stream_view 테이블에서부터
    mtid level imp와 install, 그리고 install-to-revenue계산을 위한 postback revenue(D+n일)를 추출한 다음 둘을 조인하고
    Jackknife method을 통해서 신뢰구간 등의 통계치들을 계산하는 두가지 파트로 나눌 수 있습니다.
    10:24
    1번 항목의 경우 이 코드와 binning과 D+N day revenue joining 코드를 조금 변경하시면 활용 가능하실 것입니다.
    2번 항목을 통한 통계치 계산은 이 쿼리를 응용하시면 로아스에 대한 신뢰구간 등을 잭나이프로 계산할 수 있습니다.

*/

# Query to create MTID level imp/click/install logs under the affected traffic
# Result stored under explab-298609.doohyung_exp.poor_creative_mtid_base table

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL
DECLARE start_ts TIMESTAMP DEFAULT "2024-12-10T00:00:00Z";
DECLARE end_ts TIMESTAMP DEFAULT "2025-03-18T0:00:00Z";
DECLARE install_ts_window_end TIMESTAMP DEFAULT TIMESTAMP_ADD(end_ts, INTERVAL 1 DAY); # for 24h install window
# Query to create MTID level imp/click/install logs under the affected traffic
# Result stored under moloco-ods.haewon.111percent_second_purchase_mtid_base

CREATE OR REPLACE TABLE `moloco-ods.haewon.111percent_second_purchase_mtid_base` AS (
WITH 
      IMP_TABLE AS (
        SELECT
          bid.mtid,
          ANY_VALUE(api.platform.id) AS platform_id,
          ANY_VALUE(api.campaign.id) AS campaign_id,
          ANY_VALUE(exp_id_v2) AS exp_id_v2,
          ANY_VALUE(imp.win_price_usd.amount_micro) AS win_price,
          ANY_VALUE(api.creative.id) AS creative_id,
          MIN(timestamp) AS imp_time,
          MIN(bid.timestamp) AS bid_time,
        FROM
          `focal-elf-631.prod_stream_view.imp`, unnest(bid.experiment.ids_v2) exp_id_v2
        WHERE
          timestamp >= start_ts AND timestamp <= end_ts
          AND (exp_id_v2 IN (8005, 8006))
          AND req.timestamp >= start_ts
          AND req.timestamp <= end_ts
        GROUP BY
          1
      ),
      INSTALL_TABLE AS (
        SELECT
          bid.mtid,
          MIN(timestamp) AS install_time
        FROM
          `focal-elf-631.prod_stream_view.cv`
        WHERE
          timestamp >= start_ts AND timestamp <= install_ts_window_end
          AND cv.event = 'INSTALL'
        GROUP BY
          1
      ),
      CLICK_TABLE AS (
        SELECT
          bid.mtid as mtid,
          MIN(timestamp) AS click_time,
        FROM
          `focal-elf-631.prod_stream_view.click`
        WHERE
          timestamp >= start_ts AND
          timestamp < TIMESTAMP_ADD(end_ts, INTERVAL 2 HOUR)
        GROUP BY
          1
      )
      SELECT
        mtid,
        exp_id_v2,
        win_price/1e6 AS win_price,
        platform_id,
        campaign_id,
        creative_id,
        imp_time,
        click_time,
        install_time,
        bid_time,
        IF(TIMESTAMP_DIFF(install_time, imp_time, hour) < 24, 1, 0) AS install_24h,
        IF(TIMESTAMP_DIFF(click_time, imp_time, hour) < 2, 1, 0) AS click_2h
      FROM
      IMP_TABLE 
      LEFT JOIN INSTALL_TABLE USING (mtid)
      LEFT JOIN CLICK_TABLE USING (mtid)
)

# Query to compute INSTALL CMH CPD statistics

WITH pivoted_data AS (
    SELECT *
    FROM (
      WITH metric_t AS (
        SELECT
          exp_id_v2,
          creative_id,
          campaign_id,
          SUM(win_price) as spend,
          COUNT(imp_time) as imps,
          SUM(click_2h) as clicks,
          SUM(install_24h) as installs
        FROM `moloco-ods.haewon.111percent_second_purchase_mtid_base`
        GROUP BY 1,2,3
      ),
      campaign_os_t AS (
        SELECT DISTINCT id as campaign_id, JSON_VALUE(original_json, '$.os') as os FROM `focal-elf-631.standard_digest.latest_digest`
        WHERE type = 'CAMPAIGN'
      )
      SELECT
        exp_id_v2,
        creative_id,
        SUM(spend) as spend,
        SUM(imps) as imps,
        SUM(clicks) as clicks,
        SUM(installs) as installs,
      FROM metric_t JOIN campaign_os_t USING(campaign_id)
      -- WHERE os IN 
      GROUP BY 1, 2
    )
    PIVOT(SUM(spend) as spend,SUM(imps) as imp, SUM(clicks) as click, SUM(installs) as install FOR exp_id_v2 IN (5708, 5709, 5710))
  ),
  group_agg AS (
    SELECT
      SUM(spend_5708) as ctrl_spend,
      SUM(spend_5709) as test1_spend,
      SUM(spend_5710) as test2_spend,
      SUM(imp_5708) as ctrl_imp,
      SUM(imp_5709) as test1_imp,
      SUM(imp_5710) as test2_imp,
      SUM(click_5708) as ctrl_click,
      SUM(click_5709) as test1_click,
      SUM(click_5710) as test2_click,
      SUM(install_5708) as ctrl_install,
      SUM(install_5709) as test1_install,
      SUM(install_5710) as test2_install,
      SUM(click_5708) / SUM(imp_5708) as ctrl_ctr,
      SUM(click_5709) / SUM(imp_5709) as test1_ctr,
      SUM(click_5710) / SUM(imp_5710) as test2_ctr,
      SUM(install_5708) / SUM(spend_5708) as ctrl_naive_cpd_install,
      SUM(install_5709) / SUM(spend_5709) as test1_naive_cpd_install,
      SAFE_DIVIDE(
        `explab-298609.udf.cmh_cpd_test`(ARRAY_AGG(STRUCT(spend_5708,spend_5709,CAST(install_5708 as FLOAT64), CAST(install_5709 AS FLOAT64)))),
        `explab-298609.udf.cmh_cpd_control`(ARRAY_AGG(STRUCT(spend_5708,spend_5709,CAST(install_5708 as FLOAT64), CAST(install_5709 AS FLOAT64))))
      ) as install_cmh_cpdr_test1,
      SAFE_DIVIDE(
        `explab-298609.udf.cmh_cpd_test`(ARRAY_AGG(STRUCT(spend_5708,spend_5710,CAST(install_5708 as FLOAT64), CAST(install_5710 AS FLOAT64)))),
        `explab-298609.udf.cmh_cpd_control`(ARRAY_AGG(STRUCT(spend_5708,spend_5710,CAST(install_5708 as FLOAT64), CAST(install_5710 AS FLOAT64))))
      ) as install_cmh_cpdr_test2,
    FROM pivoted_data
  )
  SELECT *,
  FROM group_agg
  LEFT JOIN (
    SELECT
      `explab-298609.udf.get_conf_int`(
        0.95,
        STRUCT(
          'cmh_rate_ratio',
          ANY_VALUE(install_cmh_cpdr_test1),
          null,
        `explab-298609.udf.log_cmh_rate_ratio_se`(
            ARRAY_AGG(STRUCT(spend_5708,spend_5709,install_5708, install_5709, install_cmh_cpdr_test1)))
      )
    ) as install_conf_int_test1,
    `explab-298609.udf.get_conf_int`(
        0.95,
        STRUCT(
          'cmh_rate_ratio',
          ANY_VALUE(install_cmh_cpdr_test2),
          null,
        `explab-298609.udf.log_cmh_rate_ratio_se`(
            ARRAY_AGG(STRUCT(spend_5708,spend_5710,install_5708, install_5710, install_cmh_cpdr_test2)))
      )
    ) as install_conf_int_test2,
    
    FROM pivoted_data LEFT JOIN (SELECT install_cmh_cpdr_test1,install_cmh_cpdr_test2 FROM group_agg) ON TRUE
  )
  ON TRUE
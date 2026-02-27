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
    PIVOT(SUM(spend) as spend,SUM(imps) as imp, SUM(clicks) as click, SUM(installs) as install FOR exp_id_v2 IN (8005, 8006))
  ),
  group_agg AS (
    SELECT
      SUM(spend_8005) as ctrl_spend,
      SUM(spend_8006) as test_spend,
      
      SUM(imp_8005) as ctrl_imp,
      SUM(imp_8006) as test1_imp,
      
      SUM(click_8005) as ctrl_click,
      SUM(click_8006) as test1_click,

      SUM(install_8005) as ctrl_install,
      SUM(install_8006) as test1_install,

      SUM(click_8005) / SUM(imp_8005) as ctrl_ctr,
      SUM(click_8006) / SUM(imp_8006) as test1_ctr,

      SUM(install_8005) / SUM(spend_8005) as ctrl_naive_cpd_install,
      SUM(install_8006) / SUM(spend_8006) as test1_naive_cpd_install,
      SAFE_DIVIDE(
        `explab-298609.udf.cmh_cpd_test`(ARRAY_AGG(STRUCT(spend_8005,spend_8006,CAST(install_8005 as FLOAT64), CAST(install_8006 AS FLOAT64)))),
        `explab-298609.udf.cmh_cpd_control`(ARRAY_AGG(STRUCT(spend_8005,spend_8006,CAST(install_8005 as FLOAT64), CAST(install_8006 AS FLOAT64))))
      ) as install_cmh_cpdr_test,
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
          ANY_VALUE(install_cmh_cpdr_test),
          null,
        `explab-298609.udf.log_cmh_rate_ratio_se`(
            ARRAY_AGG(STRUCT(spend_8005, spend_8006, install_8005, install_8006, install_cmh_cpdr_test)))
      )
    ) as install_conf_int_test,
    
    FROM pivoted_data LEFT JOIN (SELECT install_cmh_cpdr_test FROM group_agg) ON TRUE
  )
  ON TRUE


# D7 Distinct Action Stat Results
DECLARE start_ts TIMESTAMP DEFAULT "2024-12-10T00:00:00Z";
DECLARE end_ts TIMESTAMP DEFAULT "2025-03-18T0:00:00Z";

  WITH imp_and_install AS ( # to leverage the readymade table
    WITH metric_t AS (
      SELECT
        mtid,
        exp_id_v2,
        win_price,
        platform_id,
        campaign_id,
        creative_id,
        imp_time,
        click_time,
        install_time,
        bid_time,
        install_24h,
        click_2h
      FROM `moloco-ods.haewon.111percent_second_purchase_mtid_base`
      WHERE bid_time BETWEEN start_ts AND end_ts
    ),
    campaign_os_t AS (
      SELECT DISTINCT 
        id as campaign_id, 
        JSON_VALUE(original_json, '$.os') as os FROM `focal-elf-631.standard_digest.latest_digest`
      WHERE type = 'CAMPAIGN'
    )
    SELECT
      mtid,
      exp_id_v2,
      win_price,
      platform_id,
      campaign_id,
      creative_id,
      imp_time,
      click_time,
      install_time,
      bid_time,
      install_24h,
      click_2h
    FROM metric_t JOIN campaign_os_t USING(campaign_id)
    -- WHERE os IN {os_list} # OS filter
  ),
  EVENTS_TABLE AS (
    SELECT
      bid.mtid,
      timestamp AS event_timestamp,
      cv.event_pb AS event,
    FROM `focal-elf-631.prod_stream_view.cv`
    WHERE
      timestamp BETWEEN start_ts AND TIMESTAMP_ADD(end_ts, INTERVAL 7 DAY)
      AND (cv.event_pb = 'af_purchase')
  ),
  mtid_level_base AS (
    SELECT
      mtid,
      exp_id_v2,
      platform_id,
      campaign_id,
      SUM(win_price) AS win_price,
      SUM(IF(TIMESTAMP_DIFF(event_timestamp, install_time, day) < 7, 1, null)) event_cnt_7d,
    FROM imp_and_install
        LEFT JOIN EVENTS_TABLE USING (mtid)
    GROUP BY 1,2,3,4
  ),
  campaign_level_pivoted AS (
    SELECT *
    FROM (
    SELECT exp_id_v2, campaign_id, d7_actions, d7_distinct_actions, spend
    FROM (
      SELECT
        exp_id_v2,
        campaign_id,
        SUM(event_cnt_7d) as d7_actions,
        COUNT(DISTINCT IF(event_cnt_7d > 0, mtid, null)) AS d7_distinct_actions
      FROM mtid_level_base
      GROUP BY 1,2
    )
    LEFT JOIN (
        SELECT
          exp_id_v2,
          campaign_id,
          SUM(win_price) as spend
        FROM `moloco-ods.haewon.111percent_second_purchase_mtid_base`
        GROUP BY 1,2
      )
    USING(exp_id_v2, campaign_id)
    )
    PIVOT(SUM(spend) as spend, SUM(d7_actions) as d7_actions, SUM(d7_distinct_actions) as d7_distinct_actions FOR exp_id_v2 IN (8005,8006))
  ),
  group_agg AS (
    SELECT
      SUM(spend_8005) as ctrl_spend,
      SUM(spend_8006) as test1_spend,

      SUM(d7_actions_8005) as ctrl_action,
      SUM(d7_actions_8006) as test1_action,
      
      SUM(d7_distinct_actions_8005) as ctrl_distinct_action,
      SUM(d7_distinct_actions_8006) as test1_distinct_action,
      
      SAFE_DIVIDE(
        `explab-298609.udf.cmh_cpd_test`(ARRAY_AGG(STRUCT(spend_8005,spend_8006,CAST(d7_distinct_actions_8005 as FLOAT64), CAST(d7_distinct_actions_8006 AS FLOAT64)))),
        `explab-298609.udf.cmh_cpd_control`(ARRAY_AGG(STRUCT(spend_8005,spend_8006,CAST(d7_distinct_actions_8005 as FLOAT64), CAST(d7_distinct_actions_8006 AS FLOAT64))))
      ) as distinct_action_cmh_cpdr_test1
      
    FROM campaign_level_pivoted
  )
  SELECT *,
  FROM group_agg
  LEFT JOIN (
    SELECT
      `explab-298609.udf.get_conf_int`(
        0.95,
        STRUCT(
          'cmh_rate_ratio',
          ANY_VALUE(distinct_action_cmh_cpdr_test1),
          null,
        `explab-298609.udf.log_cmh_rate_ratio_se`(
            ARRAY_AGG(STRUCT(spend_8005,spend_8006,d7_distinct_actions_8005, d7_distinct_actions_8006, distinct_action_cmh_cpdr_test1)))
      )
    ) as distinct_action_conf_int_test1
    FROM campaign_level_pivoted LEFT JOIN (SELECT distinct_action_cmh_cpdr_test1 FROM group_agg) ON TRUE
  )
  ON TRUE


### DX ROAS / CROAS calculated via Jackknife 
# First creating binned mtid level table for jackknife
-- Applying randomized binning to the mtid level imp and conversion table

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL

DECLARE start_ts TIMESTAMP DEFAULT "2024-12-10T00:00:00Z";
DECLARE end_ts TIMESTAMP DEFAULT "2025-03-18T0:00:00Z";
CREATE OR REPLACE TABLE `moloco-ods.haewon.111percent_second_purchase_mtid_binned` AS (
WITH imp_and_installs_mtid_binned AS ( # spending matches up
  SELECT
    *
  FROM
    `moloco-ods.haewon.111percent_second_purchase_mtid_base`
  LEFT JOIN (
    SELECT bid.mtid, MOD(bid.experiment.bin_number,20) as bin_number
    FROM `focal-elf-631.prod_stream_view.imp`
    WHERE timestamp BETWEEN start_ts AND end_ts
  )
  USING(mtid)
  WHERE imp_time BETWEEN start_ts AND end_ts
)
SELECT *
FROM imp_and_installs_mtid_binned
)

# Binned table of MTID-joined Cohorted revenue

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL
DECLARE date_start DATE DEFAULT "2024-12-10";
DECLARE date_end DATE DEFAULT "2025-03-18";


CREATE OR REPLACE TABLE `moloco-ods.haewon.111percent_second_purchase_mtid_base_mtid_revenue_250502` AS (
WITH imp_and_installs_mtid_binned AS ( # spending matches up
  SELECT
    *
  FROM
    `moloco-ods.haewon.111percent_second_purchase_mtid_binned` 
  WHERE DATE(imp_time) BETWEEN date_start AND date_end
),
installs_mtid_binned AS (
  SELECT
    mtid,
    exp_id_v2,
    install_time,
    imp_time,
    platform_id,
    -- advertiser_id,
    campaign_id,
    -- creative_id,
    bin_number
  FROM imp_and_installs_mtid_binned
  WHERE
    DATE(install_time) BETWEEN date_start AND date_end
    AND install_time IS NOT NULL
),
revenue_mtid_binned AS (
  SELECT
    bid.mtid,
    timestamp AS event_timestamp,
    -- cv.event AS event,
    cv.event_pb AS event_pb,
    IF(cv.revenue_usd.amount>0, cv.revenue_usd.amount, NULL) AS pb_revenue,
    # bin number not required here because binnumber is unique to install level mtid
  FROM `focal-elf-631.prod_stream_view.cv`
  WHERE
    DATE(timestamp) BETWEEN date_start AND DATE_ADD(date_end, INTERVAL 90 DAY)
    AND cv.revenue_usd.amount > 0
),
i2r_mtid_binned AS (
  SELECT
    mtid,
    ANY_VALUE(exp_id_v2) as exp_id_v2,
    MIN(install_time) install_time,
    ANY_VALUE(platform_id) platform_id,
    -- ANY_VALUE(creative_id) creative_id,
    -- ANY_VALUE(advertiser_id) advertiser_id,
    ANY_VALUE(campaign_id) campaign_id,
    TIMESTAMP_DIFF(event_timestamp, install_time, DAY) AS on_day,
    -- event,
    event_pb,
    SUM(pb_revenue) AS total_revenue,
    ANY_VALUE(MOD(bin_number, 20)) AS bin_number
  FROM installs_mtid_binned
  INNER JOIN revenue_mtid_binned
    USING (mtid)
  WHERE TIMESTAMP_DIFF(event_timestamp, install_time, DAY) < 90
--   GROUP BY mtid, on_day, event, event_pb
  GROUP BY mtid, on_day, event_pb
),
mtid_dx_rev_binned AS (
  SELECT
    mtid,
    ANY_VALUE(exp_id_v2) AS exp_id_v2,
    bin_number,
    install_time AS origin_event_timestamp,
    platform_id,
    -- advertiser_id,
    campaign_id,
    -- creative_id,
    SUM(IF(on_day < 7, IFNULL(total_revenue,0), 0)) AS d7_kpi_revenue,
    LEAST(SUM(IF(on_day < 7, IFNULL(total_revenue,0), 0)), 200) AS d7_kpi_revenue_capped,
    SUM(IF(on_day < 14, IFNULL(total_revenue,0), 0)) AS d14_kpi_revenue,
    LEAST(SUM(IF(on_day < 14, IFNULL(total_revenue,0), 0)), 200) AS d14_kpi_revenue_capped,
    SUM(IF(on_day < 30, IFNULL(total_revenue,0), 0)) AS d30_kpi_revenue,
    LEAST(SUM(IF(on_day < 30, IFNULL(total_revenue,0), 0)), 200) AS d30_kpi_revenue_capped,
    SUM(IF(on_day < 60, IFNULL(total_revenue,0), 0)) AS d60_kpi_revenue,
    LEAST(SUM(IF(on_day < 60, IFNULL(total_revenue,0), 0)), 200) AS d60_kpi_revenue_capped,
    SUM(IF(on_day < 90, IFNULL(total_revenue,0), 0)) AS d90_kpi_revenue,
    LEAST(SUM(IF(on_day < 90, IFNULL(total_revenue,0), 0)), 200) AS d90_kpi_revenue_capped
  FROM i2r_mtid_binned
  JOIN (
      SELECT
          campaign_name AS campaign_id
      FROM `focal-elf-631.prod.campaign_digest_merged_latest`
      WHERE type != 'APP_REENGAGEMENT'
  ) USING (campaign_id)
  WHERE DATE(install_time) BETWEEN date_start AND date_end
    AND event_pb = 'af_purchase'
  GROUP BY 1,3,4,5,6
)
SELECT *
FROM mtid_dx_rev_binned
)


####
WITH d7_rev_and_spend_binned AS (  # cte aggregating revenue&spend at expid x creative_id x binnumber
    WITH revenues AS (
      SELECT
        exp_id_v2,
        -- creative_id,
        campaign_id,
        bin_number,
        SUM(d7_kpi_revenue) AS d7rev_binned,
        SUM(d7_kpi_revenue_capped) AS d7crev_binned,
        SUM(d14_kpi_revenue) AS d14rev_binned,
        SUM(d14_kpi_revenue_capped) AS d14crev_binned,
        SUM(d30_kpi_revenue) AS d30rev_binned,
        SUM(d30_kpi_revenue_capped) AS d30crev_binned,
        SUM(d60_kpi_revenue) AS d60rev_binned,
        SUM(d60_kpi_revenue_capped) AS d60crev_binned,
        SUM(d90_kpi_revenue) AS d90rev_binned,
        SUM(d90_kpi_revenue_capped) AS d90crev_binned
      FROM `moloco-ods.haewon.111percent_second_purchase_mtid_base_mtid_revenue_250502`
      GROUP BY 1,2,3
    ),
    spends AS (
      SELECT
        exp_id_v2,
        -- creative_id,
        campaign_id,
        bin_number,
        SUM(win_price) AS spend_binned
      FROM `moloco-ods.haewon.111percent_second_purchase_mtid_binned` 
      GROUP BY 1,2,3
    ),
    campaign_os AS (
      SELECT DISTINCT id as campaign_id, JSON_VALUE(original_json, '$.os') as os FROM `focal-elf-631.standard_digest.latest_digest`
      WHERE type = 'CAMPAIGN'
    )
    SELECT
      exp_id_v2, 
    --   creative_id, 
      bin_number,
      SUM(IFNULL(d7rev_binned, 0)) as d7rev_binned,
      SUM(IFNULL(d7crev_binned, 0)) as d7crev_binned,
      SUM(IFNULL(d14rev_binned, 0)) as d14rev_binned,
      SUM(IFNULL(d14crev_binned, 0)) as d14crev_binned,
      SUM(IFNULL(d30rev_binned, 0)) as d30rev_binned,
      SUM(IFNULL(d30crev_binned, 0)) as d30crev_binned,
      SUM(IFNULL(d60rev_binned, 0)) as d60rev_binned,
      SUM(IFNULL(d60crev_binned, 0)) as d60crev_binned,
      SUM(IFNULL(d90rev_binned, 0)) as d90rev_binned,
      SUM(IFNULL(d90crev_binned, 0)) as d90crev_binned,
      SUM(spend_binned) as spend_binned
    FROM spends LEFT JOIN revenues USING(exp_id_v2, bin_number, campaign_id)
    LEFT JOIN campaign_os USING(campaign_id)
    GROUP BY 1, 2
  ),
  exp_digest AS (
      SELECT
          gr.group_id AS test_group_id,
          gr.control_group_id,
      FROM `explab-298609.exp_prod.experiment_digest_v2`,
          UNNEST(`groups`) AS gr
      WHERE timestamp >= "2021-01-01"
      AND experiment_type != '_UPLIFT_'
      AND control_group_id != 0
      AND gr.group_id IN (8005, 8006)
      GROUP BY 1,2
  ),
  paired_summary_binned AS (
    SELECT
      test_group_id, 
      control_group_id, 
    --   creative_id, 
      bin_number,
      SUM(test_d7rev_binned) as test_d7rev_binned, 
      SUM(test_d7crev_binned) as test_d7crev_binned, 
      SUM(test_d14rev_binned) as test_d14rev_binned, 
      SUM(test_d14crev_binned) as test_d14crev_binned, 
      SUM(test_d30rev_binned) as test_d30rev_binned, 
      SUM(test_d30crev_binned) as test_d30crev_binned, 
      SUM(test_d60rev_binned) as test_d60rev_binned, 
      SUM(test_d60crev_binned) as test_d60crev_binned, 
      SUM(test_d90rev_binned) as test_d90rev_binned, 
      SUM(test_d90crev_binned) as test_d90crev_binned, 
      SUM(test_spend_binned) as test_spend_binned,

      SUM(ctrl_d7rev_binned) as ctrl_d7rev_binned, 
      SUM(ctrl_d7crev_binned) as ctrl_d7crev_binned, 
      SUM(ctrl_d14rev_binned) as ctrl_d14rev_binned, 
      SUM(ctrl_d14crev_binned) as ctrl_d14crev_binned, 
      SUM(ctrl_d30rev_binned) as ctrl_d30rev_binned, 
      SUM(ctrl_d30crev_binned) as ctrl_d30crev_binned, 
      SUM(ctrl_d60rev_binned) as ctrl_d60rev_binned, 
      SUM(ctrl_d60crev_binned) as ctrl_d60crev_binned, 
      SUM(ctrl_d90rev_binned) as ctrl_d90rev_binned, 
      SUM(ctrl_d90crev_binned) as ctrl_d90crev_binned, 
      SUM(ctrl_spend_binned) as ctrl_spend_binned
    FROM (
      SELECT 
        test_group_id, 
        control_group_id, 
        -- creative_id, 
        bin_number,
        d7rev_binned as test_d7rev_binned, 
        d7crev_binned as test_d7crev_binned, 
        d14rev_binned as test_d14rev_binned, 
        d14crev_binned as test_d14crev_binned, 
        d30rev_binned as test_d30rev_binned, 
        d30crev_binned as test_d30crev_binned, 
        d60rev_binned as test_d60rev_binned, 
        d60crev_binned as test_d60crev_binned, 
        d90rev_binned as test_d90rev_binned, 
        d90crev_binned as test_d90crev_binned, 
        spend_binned as test_spend_binned,

        0 as ctrl_d7rev_binned, 
        0 as ctrl_d7crev_binned,
        0 as ctrl_d14rev_binned, 
        0 as ctrl_d14crev_binned, 
        0 as ctrl_d30rev_binned, 
        0 as ctrl_d30crev_binned, 
        0 as ctrl_d60rev_binned, 
        0 as ctrl_d60crev_binned, 
        0 as ctrl_d90rev_binned, 
        0 as ctrl_d90crev_binned, 
        0 as ctrl_spend_binned
      FROM d7_rev_and_spend_binned
        JOIN exp_digest ON test_group_id = exp_id_v2
      UNION ALL
      SELECT 
        test_group_id, 
        control_group_id, 
        -- creative_id, 
        bin_number,
        0 as test_d7rev_binned, 
        0 as test_d7crev_binned, 
        0 as test_d14rev_binned, 
        0 as test_d14crev_binned, 
        0 as test_d30rev_binned, 
        0 as test_d30crev_binned, 
        0 as test_d60rev_binned, 
        0 as test_d60crev_binned, 
        0 as test_d90rev_binned, 
        0 as test_d90crev_binned, 
        0 as test_spend_binned,

        d7rev_binned as ctrl_d7rev_binned, 
        d7crev_binned as ctrl_d7crev_binned, 
        d14rev_binned as ctrl_d14rev_binned, 
        d14crev_binned as ctrl_d14crev_binned, 
        d30rev_binned as ctrl_d30rev_binned, 
        d30crev_binned as ctrl_d30crev_binned, 
        d60rev_binned as ctrl_d60rev_binned, 
        d60crev_binned as ctrl_d60crev_binned, 
        d90rev_binned as ctrl_d90rev_binned, 
        d90crev_binned as ctrl_d90crev_binned, 
        spend_binned as ctrl_spend_binned
      FROM d7_rev_and_spend_binned
        JOIN exp_digest ON control_group_id = exp_id_v2
    )
    GROUP BY 1,2,3
  ),
  full_cmh_summary AS (
    SELECT
      test_group_id, 
      control_group_id, 
    --   creative_id,
      SUM(test_d7rev_binned) as test_d7rev,
      SUM(test_d7crev_binned) as test_d7crev, 
      SUM(test_d14rev_binned) as test_d14rev,
      SUM(test_d14crev_binned) as test_d14crev, 
      SUM(test_d30rev_binned) as test_d30rev,
      SUM(test_d30crev_binned) as test_d30crev, 
      SUM(test_d60rev_binned) as test_d60rev,
      SUM(test_d60crev_binned) as test_d60crev, 
      SUM(test_d90rev_binned) as test_d90rev,
      SUM(test_d90crev_binned) as test_d90crev, 
      SUM(test_spend_binned) as test_spend,

      SUM(ctrl_d7rev_binned) as ctrl_d7rev, 
      SUM(ctrl_d7crev_binned) as ctrl_d7crev, 
      SUM(ctrl_d14rev_binned) as ctrl_d14rev, 
      SUM(ctrl_d14crev_binned) as ctrl_d14crev, 
      SUM(ctrl_d30rev_binned) as ctrl_d30rev, 
      SUM(ctrl_d30crev_binned) as ctrl_d30crev, 
      SUM(ctrl_d60rev_binned) as ctrl_d60rev, 
      SUM(ctrl_d60crev_binned) as ctrl_d60crev, 
      SUM(ctrl_d90rev_binned) as ctrl_d90rev, 
      SUM(ctrl_d90crev_binned) as ctrl_d90crev, 
      SUM(ctrl_spend_binned) as ctrl_spend
    FROM paired_summary_binned
    GROUP BY 1,2
  ),
  loo_summary AS (
    SELECT
      test_group_id,
      control_group_id,
    --   creative_id,
      deleted_bin,
      test_spend_loo,
      test_d7rev_loo,
      test_d7crev_loo,
      test_d14rev_loo,
      test_d14crev_loo,
      test_d30rev_loo,
      test_d30crev_loo,
      test_d60rev_loo,
      test_d60crev_loo,
      test_d90rev_loo,
      test_d90crev_loo,

      ctrl_spend_loo,
      ctrl_d7rev_loo,
      ctrl_d7crev_loo,
      ctrl_d14rev_loo,
      ctrl_d14crev_loo,
      ctrl_d30rev_loo,
      ctrl_d30crev_loo,
      ctrl_d60rev_loo,
      ctrl_d60crev_loo,
      ctrl_d90rev_loo,
      ctrl_d90crev_loo,
    FROM (
      SELECT
        test_group_id,
        control_group_id,
        -- creative_id,
        bin_number AS deleted_bin,
        all_bin.test_spend - IFNULL(single_bin.test_spend_binned, 0) AS test_spend_loo,
        all_bin.test_d7rev - IFNULL(single_bin.test_d7rev_binned, 0) AS test_d7rev_loo,
        all_bin.test_d7crev - IFNULL(single_bin.test_d7crev_binned, 0) AS test_d7crev_loo,
        all_bin.test_d14rev - IFNULL(single_bin.test_d14rev_binned, 0) AS test_d14rev_loo,
        all_bin.test_d14crev - IFNULL(single_bin.test_d14crev_binned, 0) AS test_d14crev_loo,
        all_bin.test_d30rev - IFNULL(single_bin.test_d30rev_binned, 0) AS test_d30rev_loo,
        all_bin.test_d30crev - IFNULL(single_bin.test_d30crev_binned, 0) AS test_d30crev_loo,
        all_bin.test_d60rev - IFNULL(single_bin.test_d60rev_binned, 0) AS test_d60rev_loo,
        all_bin.test_d60crev - IFNULL(single_bin.test_d60crev_binned, 0) AS test_d60crev_loo,
        all_bin.test_d90rev - IFNULL(single_bin.test_d90rev_binned, 0) AS test_d90rev_loo,
        all_bin.test_d90crev - IFNULL(single_bin.test_d90crev_binned, 0) AS test_d90crev_loo,

        all_bin.ctrl_spend - IFNULL(single_bin.ctrl_spend_binned, 0) AS ctrl_spend_loo,
        all_bin.ctrl_d7rev - IFNULL(single_bin.ctrl_d7rev_binned, 0) AS ctrl_d7rev_loo,
        all_bin.ctrl_d7crev - IFNULL(single_bin.ctrl_d7crev_binned, 0) AS ctrl_d7crev_loo,
        all_bin.ctrl_d14rev - IFNULL(single_bin.ctrl_d14rev_binned, 0) AS ctrl_d14rev_loo,
        all_bin.ctrl_d14crev - IFNULL(single_bin.ctrl_d14crev_binned, 0) AS ctrl_d14crev_loo,
        all_bin.ctrl_d30rev - IFNULL(single_bin.ctrl_d30rev_binned, 0) AS ctrl_d30rev_loo,
        all_bin.ctrl_d30crev - IFNULL(single_bin.ctrl_d30crev_binned, 0) AS ctrl_d30crev_loo,
        all_bin.ctrl_d60rev - IFNULL(single_bin.ctrl_d60rev_binned, 0) AS ctrl_d60rev_loo,
        all_bin.ctrl_d60crev - IFNULL(single_bin.ctrl_d60crev_binned, 0) AS ctrl_d60crev_loo,
        all_bin.ctrl_d90rev - IFNULL(single_bin.ctrl_d90rev_binned, 0) AS ctrl_d90rev_loo,
        all_bin.ctrl_d90crev - IFNULL(single_bin.ctrl_d90crev_binned, 0) AS ctrl_d90crev_loo,
      FROM full_cmh_summary AS all_bin
      CROSS JOIN UNNEST(GENERATE_ARRAY(0, 20)) AS bin_number
      LEFT JOIN paired_summary_binned AS single_bin
      USING(test_group_id, control_group_id, bin_number)
      )
    WHERE (test_spend_loo > 0 OR ctrl_spend_loo > 0)
  ),
  cmh_summary AS (
    SELECT
      test_group_id,
      control_group_id,
      deleted_bin,
      `explab-298609.udf.cmh_ratio`(ARRAY_AGG(STRUCT(ctrl_spend_loo, test_spend_loo, ctrl_d7rev_loo, test_d7rev_loo)), FALSE) AS cmh_ratio_d7rev,
      `explab-298609.udf.cmh_ratio`(ARRAY_AGG(STRUCT(ctrl_spend_loo, test_spend_loo, ctrl_d7crev_loo, test_d7crev_loo)), FALSE) AS cmh_ratio_d7crev,
      `explab-298609.udf.cmh_ratio`(ARRAY_AGG(STRUCT(ctrl_spend_loo, test_spend_loo, ctrl_d14rev_loo, test_d14rev_loo)), FALSE) AS cmh_ratio_d14rev,
      `explab-298609.udf.cmh_ratio`(ARRAY_AGG(STRUCT(ctrl_spend_loo, test_spend_loo, ctrl_d14crev_loo, test_d14crev_loo)), FALSE) AS cmh_ratio_d14crev,
      `explab-298609.udf.cmh_ratio`(ARRAY_AGG(STRUCT(ctrl_spend_loo, test_spend_loo, ctrl_d30rev_loo, test_d30rev_loo)), FALSE) AS cmh_ratio_d30rev,
      `explab-298609.udf.cmh_ratio`(ARRAY_AGG(STRUCT(ctrl_spend_loo, test_spend_loo, ctrl_d30crev_loo, test_d30crev_loo)), FALSE) AS cmh_ratio_d30crev,
      `explab-298609.udf.cmh_ratio`(ARRAY_AGG(STRUCT(ctrl_spend_loo, test_spend_loo, ctrl_d60rev_loo, test_d60rev_loo)), FALSE) AS cmh_ratio_d60rev,
      `explab-298609.udf.cmh_ratio`(ARRAY_AGG(STRUCT(ctrl_spend_loo, test_spend_loo, ctrl_d60crev_loo, test_d60crev_loo)), FALSE) AS cmh_ratio_d60crev,
      `explab-298609.udf.cmh_ratio`(ARRAY_AGG(STRUCT(ctrl_spend_loo, test_spend_loo, ctrl_d90rev_loo, test_d90rev_loo)), FALSE) AS cmh_ratio_d90rev,
      `explab-298609.udf.cmh_ratio`(ARRAY_AGG(STRUCT(ctrl_spend_loo, test_spend_loo, ctrl_d90crev_loo, test_d90crev_loo)), FALSE) AS cmh_ratio_d90crev
    FROM loo_summary
    GROUP BY 1,2,3
  ),
  pseudo_summary AS (
    SELECT
      test_group_id,
      control_group_id,
      delete_cmh_summary.deleted_bin,
      full_cmh_summary.cmh_ratio_d7rev AS full_cmh_ratio_d7rev,
      full_cmh_summary.cmh_ratio_d7crev AS full_cmh_ratio_d7crev,
      full_cmh_summary.cmh_ratio_d14rev AS full_cmh_ratio_d14rev,
      full_cmh_summary.cmh_ratio_d14crev AS full_cmh_ratio_d14crev,
      full_cmh_summary.cmh_ratio_d30rev AS full_cmh_ratio_d30rev,
      full_cmh_summary.cmh_ratio_d30crev AS full_cmh_ratio_d30crev,
      full_cmh_summary.cmh_ratio_d60rev AS full_cmh_ratio_d60rev,
      full_cmh_summary.cmh_ratio_d60crev AS full_cmh_ratio_d60crev,
      full_cmh_summary.cmh_ratio_d90rev AS full_cmh_ratio_d90rev,
      full_cmh_summary.cmh_ratio_d90crev AS full_cmh_ratio_d90crev,

      20*LOG(full_cmh_summary.cmh_ratio_d7rev)-(20-1)*LOG(delete_cmh_summary.cmh_ratio_d7rev) AS psuedo_metric_d7rev,
      20*LOG(full_cmh_summary.cmh_ratio_d7crev)-(20-1)*LOG(delete_cmh_summary.cmh_ratio_d7crev) AS psuedo_metric_d7crev,
      20*LOG(full_cmh_summary.cmh_ratio_d14rev)-(20-1)*LOG(delete_cmh_summary.cmh_ratio_d14rev) AS psuedo_metric_d14rev,
      20*LOG(full_cmh_summary.cmh_ratio_d14crev)-(20-1)*LOG(delete_cmh_summary.cmh_ratio_d14crev) AS psuedo_metric_d14crev,
      20*LOG(full_cmh_summary.cmh_ratio_d30rev)-(20-1)*LOG(delete_cmh_summary.cmh_ratio_d30rev) AS psuedo_metric_d30rev,
      20*LOG(full_cmh_summary.cmh_ratio_d30crev)-(20-1)*LOG(delete_cmh_summary.cmh_ratio_d30crev) AS psuedo_metric_d30crev,
      20*LOG(full_cmh_summary.cmh_ratio_d60rev)-(20-1)*LOG(delete_cmh_summary.cmh_ratio_d60rev) AS psuedo_metric_d60rev,
      20*LOG(full_cmh_summary.cmh_ratio_d60crev)-(20-1)*LOG(delete_cmh_summary.cmh_ratio_d60crev) AS psuedo_metric_d60crev,
      20*LOG(full_cmh_summary.cmh_ratio_d90rev)-(20-1)*LOG(delete_cmh_summary.cmh_ratio_d90rev) AS psuedo_metric_d90rev,
      20*LOG(full_cmh_summary.cmh_ratio_d90crev)-(20-1)*LOG(delete_cmh_summary.cmh_ratio_d90crev) AS psuedo_metric_d90crev
    FROM (
      SELECT
      *
      FROM cmh_summary
      WHERE deleted_bin != 20 -- 1 delete estimate
    ) delete_cmh_summary
    JOIN (
      SELECT
          *
      FROM cmh_summary
      WHERE deleted_bin = 20 -- full estimate
    ) full_cmh_summary
    USING (test_group_id, control_group_id)
  )
  SELECT
    test_group_id,
    control_group_id,
    d7roas_estimate,
    `explab-298609.udf.get_conf_int`(0.95, STRUCT("Jackknife", d7roas_estimate, null,log_transform_std_err_d7roas)) as d7_roas_CI,
    d7_capped_roas_estimate,
    `explab-298609.udf.get_conf_int`(0.95, STRUCT("Jackknife", d7_capped_roas_estimate, null,log_transform_std_err_d7_capped_roas)) as d7_capped_roas_CI,
    d14roas_estimate,
    `explab-298609.udf.get_conf_int`(0.95, STRUCT("Jackknife", d14roas_estimate, null,log_transform_std_err_d14roas)) as d14_roas_CI,
    d14_capped_roas_estimate,
    `explab-298609.udf.get_conf_int`(0.95, STRUCT("Jackknife", d14_capped_roas_estimate, null,log_transform_std_err_d14_capped_roas)) as d14_capped_roas_CI,
    d30roas_estimate,
    `explab-298609.udf.get_conf_int`(0.95, STRUCT("Jackknife", d30roas_estimate, null,log_transform_std_err_d30roas)) as d30_roas_CI,
    d30_capped_roas_estimate,
    `explab-298609.udf.get_conf_int`(0.95, STRUCT("Jackknife", d30_capped_roas_estimate, null,log_transform_std_err_d30_capped_roas)) as d30_capped_roas_CI,
    d60roas_estimate,
    `explab-298609.udf.get_conf_int`(0.95, STRUCT("Jackknife", d60roas_estimate, null,log_transform_std_err_d60roas)) as d60_roas_CI,
    d60_capped_roas_estimate,
    `explab-298609.udf.get_conf_int`(0.95, STRUCT("Jackknife", d60_capped_roas_estimate, null,log_transform_std_err_d60_capped_roas)) as d60_capped_roas_CI,
    d90roas_estimate,
    `explab-298609.udf.get_conf_int`(0.95, STRUCT("Jackknife", d90roas_estimate, null,log_transform_std_err_d90roas)) as d90_roas_CI,
    d90_capped_roas_estimate,
    `explab-298609.udf.get_conf_int`(0.95, STRUCT("Jackknife", d90_capped_roas_estimate, null,log_transform_std_err_d90_capped_roas)) as d90_capped_roas_CI


  FROM (
    SELECT
      test_group_id,
      control_group_id,
      EXP(AVG(psuedo_metric_d7rev)) AS d7roas_estimate,
      STDDEV(psuedo_metric_d7rev)/SQRT(20) AS log_transform_std_err_d7roas,
      EXP(AVG(psuedo_metric_d7crev)) AS d7_capped_roas_estimate,
      STDDEV(psuedo_metric_d7crev)/SQRT(20) AS log_transform_std_err_d7_capped_roas,

      EXP(AVG(psuedo_metric_d14rev)) AS d14roas_estimate,
      STDDEV(psuedo_metric_d14rev)/SQRT(20) AS log_transform_std_err_d14roas,
      EXP(AVG(psuedo_metric_d14crev)) AS d14_capped_roas_estimate,
      STDDEV(psuedo_metric_d14crev)/SQRT(20) AS log_transform_std_err_d14_capped_roas,

      EXP(AVG(psuedo_metric_d30rev)) AS d30roas_estimate,
      STDDEV(psuedo_metric_d30rev)/SQRT(20) AS log_transform_std_err_d30roas,
      EXP(AVG(psuedo_metric_d30crev)) AS d30_capped_roas_estimate,
      STDDEV(psuedo_metric_d30crev)/SQRT(20) AS log_transform_std_err_d30_capped_roas,

      EXP(AVG(psuedo_metric_d60rev)) AS d60roas_estimate,
      STDDEV(psuedo_metric_d60rev)/SQRT(20) AS log_transform_std_err_d60roas,
      EXP(AVG(psuedo_metric_d60crev)) AS d60_capped_roas_estimate,
      STDDEV(psuedo_metric_d60crev)/SQRT(20) AS log_transform_std_err_d60_capped_roas,

      EXP(AVG(psuedo_metric_d90rev)) AS d90roas_estimate,
      STDDEV(psuedo_metric_d90rev)/SQRT(20) AS log_transform_std_err_d90roas,
      EXP(AVG(psuedo_metric_d90crev)) AS d90_capped_roas_estimate,
      STDDEV(psuedo_metric_d90crev)/SQRT(20) AS log_transform_std_err_d90_capped_roas
    FROM pseudo_summary
    GROUP BY 1,2
  )
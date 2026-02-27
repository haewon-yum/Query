/* 

RE audience size calculation 
https://github.com/moloco/looker-molocoads/blob/c595a22d9baf801581506c8ca403d4d4b2aecd15/012.Cloud_Tables/cloud_re_target_audience_size.view.lkml#L4


*/

WITH existing_user AS (
          SELECT
          os,
          app_bundle,
          idfa,
          ---- should exclude field
          {% if exclude._parameter_value == 'true' %}
            LOGICAL_OR(DATE_DIFF(CURRENT_DATE(), DATE(TIMESTAMP_MILLIS(latest_millis)), day) < {% parameter exclude_window %}
                      AND {% condition exclude_event %} event {% endcondition %})
          {% else %}
            FALSE
          {% endif %} AS should_exclude,
          ---- should include field
          {% if include._parameter_value == 'true' %}
            LOGICAL_OR(DATE_DIFF(CURRENT_DATE(), DATE(TIMESTAMP_MILLIS(latest_millis)), day) < {% parameter include_window %}
                      AND {% condition include_event %} event {% endcondition %})
          {% else %}
            TRUE
          {% endif %} AS should_include
          FROM `focal-elf-631.user_data_v2_avro.pb_raw_latest`
          WHERE {% condition filter_app_bundle %} app._bundle {% endcondition %}
          GROUP BY 1, 2, 3
      ),
      rtb_user AS (
          SELECT
          os,
          idfa,
          country
          FROM `focal-elf-631.user_data_v2_avro.lifetime_summary_latest`
          WHERE TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), PARSE_TIMESTAMP("%F %T %Z", latest_date_time), DAY) < 30
          AND {% condition filter_country %} country {% endcondition %}
      )
      -------------
      SELECT
      os,
      app_bundle,
      country,
      COUNT(DISTINCT idfa) target_user_count
      FROM (
        SELECT
        os,
        app_bundle,
        idfa
        FROM existing_user
        WHERE should_include AND NOT should_exclude
      ) JOIN rtb_user USING (os, idfa)
      GROUP BY 1, 2, 3
      ORDER BY 1, 2, 3
       ;;


/* audience size by event 
  Reference: https://docs.google.com/spreadsheets/d/1zhfI_WcXH7niYRkidffpwtg4XPvP1UW6eJs11UL5Qoc/edit?gid=606649491#gid=606649491 (Credit Karma)
*/



  DECLARE app_bundle STRING DEFAULT 'com.percent.aos.luckydefense';
  DECLARE country STRING DEFAULT 'KOR';


  WITH
    rtb AS (
      SELECT
        DISTINCT
        idfa
      FROM
        `focal-elf-631.user_data_v2_avro.lifetime_summary_latest`
      WHERE
        TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), PARSE_TIMESTAMP("%F %T %Z", latest_date_time), DAY) < 30
        AND (country = country) 
    ),
    
  lookback_3 AS (
    SELECT 
      event,
      COUNT(DISTINCT idfa) as rtb_user_count_d3
    FROM
    (SELECT
      DISTINCT
      event,
      idfa
    FROM
      `focal-elf-631.user_data_v2_avro.pb_raw_latest` 
    WHERE
      (app_bundle = app_bundle)
      AND DATE_DIFF(CURRENT_DATE(), DATE(TIMESTAMP_MILLIS(latest_millis)), day) < 3)
      JOIN rtb
      USING (idfa)
    GROUP BY 1
  ),

  lookback_7 AS (
    SELECT 
      event,
      COUNT(DISTINCT idfa) as rtb_user_count_d7
    FROM
      (SELECT
      DISTINCT
      event,
      idfa
      FROM
      `focal-elf-631.user_data_v2_avro.pb_raw_latest` 
      WHERE
      (app_bundle = app_bundle)
      AND DATE_DIFF(CURRENT_DATE(), DATE(TIMESTAMP_MILLIS(latest_millis)), day) < 7)
      JOIN rtb
      USING (idfa)
    GROUP BY 1
  ),

  lookback_30 AS (
    SELECT 
      event,
      COUNT(DISTINCT idfa) as rtb_user_count_d30
    FROM
      (SELECT
        DISTINCT
          event,
          idfa
      FROM
          `focal-elf-631.user_data_v2_avro.pb_raw_latest` 
      WHERE
        (app_bundle = app_bundle)
        AND DATE_DIFF(CURRENT_DATE(), DATE(TIMESTAMP_MILLIS(latest_millis)), day) < 30)
        JOIN rtb
        USING (idfa)
    GROUP BY 1
  ),

  lookback_90 AS (
    SELECT 
      event,
      COUNT(DISTINCT idfa) as rtb_user_count_d90
    FROM
      (SELECT
        DISTINCT
        event,
        idfa
      FROM
        `focal-elf-631.user_data_v2_avro.pb_raw_latest` 
      WHERE
        (app_bundle = app_bundle)
        AND DATE_DIFF(CURRENT_DATE(), DATE(TIMESTAMP_MILLIS(latest_millis)), day) < 90)
      JOIN rtb
      USING (idfa)
    GROUP BY 1)

  SELECT
    event,
    COALESCE(rtb_user_count_d3, 0) as rtb_user_count_d3,
    COALESCE(rtb_user_count_d7, 0) as rtb_user_count_d7,
    COALESCE(rtb_user_count_d30, 0) as rtb_user_count_d30,
    COALESCE(rtb_user_count_d90, 0) as rtb_user_count_d90
  FROM
    lookback_3
    FULL JOIN
    lookback_7
    USING
    (event)
    FULL JOIN
    lookback_30
    USING
    (event)
    FULL JOIN
    lookback_90
    USING
    (event)
    ORDER BY rtb_user_count_d90 DESC




### match rate ### 

### iOS Audience ###

  ## DANGGEUN MARKET ##

  DECLARE app_bundle STRING DEFAULT 'id1018769995';
  DECLARE country STRING DEFAULT 'KOR';

  -- WITH lookback_90 AS (
  -- SELECT 
  --   event,
  --   COUNT(DISTINCT maid) as rtb_user_count_d90
  -- FROM
  --   (SELECT
  --     DISTINCT
  --     event,
  --     maid
  --   FROM
  --     `focal-elf-631.user_data_v2_avro.pb_raw_latest` 
  --   WHERE
  --     (app_bundle = app_bundle)
  --     AND DATE_DIFF(CURRENT_DATE(), DATE(TIMESTAMP_MILLIS(latest_millis)), day) < 90)
  --   -- JOIN rtb
  --   -- USING (idfa)
  -- GROUP BY 1)

  -- SELECT *
  -- FROM lookback_90

  SELECT
    DISTINCT device.idfv
  FROM `focal-elf-631.df_accesslog.pb`
  WHERE device.country = 'KOR'
    AND event.name = 'af_app_opened'


-- BigQuery Scripting

-- 파라미터
DECLARE v_app_bundle STRING DEFAULT 'id1018769995';
DECLARE v_country    STRING DEFAULT 'KOR';

-- 필수: 파티션 필터에 사용할 region 목록 (예: AP, EU, NA 등)
DECLARE v_regions ARRAY<STRING> DEFAULT ['AP'];  -- TODO: 환경에 맞게 수정

-- 외부 테이블 최근 30일 → rtb 구성
DECLARE project_id STRING DEFAULT 'moloco-dsp-profile-prod';
DECLARE dataset_id STRING DEFAULT 'bidlog';
DECLARE prefix     STRING DEFAULT 'codered_bid_';

DECLARE today      DATE   DEFAULT CURRENT_DATE('Asia/Seoul');
DECLARE start_date DATE   DEFAULT DATE_SUB(today, INTERVAL 29 DAY);  -- 오늘 포함 30일

DECLARE union_sql    STRING;
DECLARE create_rtb   STRING;
DECLARE region_list  STRING;
DECLARE start_lit    STRING;
DECLARE end_lit      STRING;

-- region IN (...) 문자열 리터럴 생성
SET region_list = (
  SELECT '(' || STRING_AGG("'" || REPLACE(r, "'", "''") || "'", ',') || ')'
  FROM UNNEST(v_regions) AS r
);

-- DATE 'YYYY-MM-DD' 리터럴
SET start_lit = "DATE '" || CAST(start_date AS STRING) || "'";
SET end_lit   = "DATE '" || CAST(today AS STRING) || "'";

-- 1) 최근 30일 EXTERNAL 테이블만 골라 UNION ALL 생성
--    각 SELECT에 파티션 필터: region IN (...) AND CAST(ts AS DATE) BETWEEN start_lit AND end_lit
SET union_sql = (
  SELECT ARRAY_TO_STRING(ARRAY(
    SELECT FORMAT(
      'SELECT req.device.ifv AS idfv FROM `%s.%s.%s` WHERE region IN %s AND CAST(ts AS DATE) BETWEEN %s AND %s',
      project_id, dataset_id, table_name, region_list, start_lit, end_lit
    )
    FROM `moloco-dsp-profile-prod.bidlog.INFORMATION_SCHEMA.TABLES`
    WHERE table_type = 'EXTERNAL'
      AND STARTS_WITH(table_name, prefix)
      AND REGEXP_CONTAINS(table_name, r'^codered_bid_[0-9]{8}$')
      AND PARSE_DATE('%Y%m%d', SUBSTR(table_name, -8)) BETWEEN start_date AND today
    ORDER BY table_name
  ), ' UNION ALL ')
);

-- 2) rtb 임시 테이블 생성 (국가 필터는 여기서 적용)
IF union_sql IS NULL THEN
  CREATE TEMP TABLE rtb AS
  SELECT CAST(NULL AS STRING) AS idfv
  WHERE 1=0;
ELSE
  SET create_rtb =
    'CREATE TEMP TABLE rtb AS ' ||
    'SELECT DISTINCT idfv ' ||
    'FROM (' || union_sql || ') ';
  EXECUTE IMMEDIATE create_rtb;
END IF;

-- ===== 본 분석 쿼리 =====
WITH
  lookback_3 AS (
    SELECT event, COUNT(DISTINCT idfv) AS rtb_user_count_d3
    FROM (
      SELECT DISTINCT event.name AS event, device.idfv
      FROM `focal-elf-631.df_accesslog.pb`
      WHERE app.bundle = v_app_bundle
        AND DATE_DIFF(CURRENT_DATE(), DATE(timestamp), DAY) < 3
        AND device.country = v_country
        AND event.name = 'af_app_opened'
    )
    JOIN rtb USING (idfv)
    GROUP BY 1
  ),
  lookback_7 AS (
    SELECT event, COUNT(DISTINCT idfv) AS rtb_user_count_d7
    FROM (
      SELECT DISTINCT event.name AS event, device.idfv
      FROM `focal-elf-631.df_accesslog.pb`
      WHERE app.bundle = v_app_bundle
        AND DATE_DIFF(CURRENT_DATE(), DATE(timestamp), DAY) < 7
        AND device.country = v_country
        AND event.name = 'af_app_opened'
    )
    JOIN rtb USING (idfv)
    GROUP BY 1
  ),
  lookback_30 AS (
    SELECT event, COUNT(DISTINCT idfv) AS rtb_user_count_d30
    FROM (
      SELECT DISTINCT event.name AS event, device.idfv
      FROM `focal-elf-631.df_accesslog.pb`
      WHERE app.bundle = v_app_bundle
        AND DATE_DIFF(CURRENT_DATE(), DATE(timestamp), DAY) < 30
        AND device.country = v_country
        AND event.name = 'af_app_opened'
    )
    JOIN rtb USING (idfv)
    GROUP BY 1
  ),
  lookback_90 AS (
    SELECT event, COUNT(DISTINCT idfv) AS rtb_user_count_d90
    FROM (
      SELECT DISTINCT event.name AS event, device.idfv
      FROM `focal-elf-631.df_accesslog.pb`
      WHERE app.bundle = v_app_bundle
        AND DATE_DIFF(CURRENT_DATE(), DATE(timestamp), DAY) < 90
        AND device.country = v_country
        AND event.name = 'af_app_opened'
    )
    JOIN rtb USING (idfv)
    GROUP BY 1
  )
SELECT
  event,
  COALESCE(rtb_user_count_d3,  0) AS rtb_user_count_d3,
  COALESCE(rtb_user_count_d7,  0) AS rtb_user_count_d7,
  COALESCE(rtb_user_count_d30, 0) AS rtb_user_count_d30,
  COALESCE(rtb_user_count_d90, 0) AS rtb_user_count_d90
FROM lookback_90 l90
FULL JOIN lookback_30 l30 USING (event)
FULL JOIN lookback_7  l7  USING (event)
FULL JOIN lookback_3  l3  USING (event)
ORDER BY rtb_user_count_d90 DESC;

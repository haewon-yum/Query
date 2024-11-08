-- reference: https://moloco.slack.com/archives/C07G2UKQPD2/p1727155914413519?thread_ts=1727151806.323689&cid=C07G2UKQPD2
WITH
  raw AS (
  SELECT
    *,
    CASE
      WHEN method LIKE "%device%" OR method LIKE "%id%" OR method LIKE "%determi%" THEN FALSE
      ELSE TRUE
  END
    AS is_fp_attributed
  FROM (
    SELECT
      api.product.app.tracking_bundle,
      bid.aux.ignore_mmp_feedback,
      CASE
        WHEN req.device.osv = "" THEN "unknown"
        WHEN cv.pb.mmp.name="SINGULAR"
      AND req.device.osv BETWEEN "14.0"
      AND "18.0" THEN "new"
        WHEN cv.pb.mmp.name<>"SINGULAR" AND req.device.osv BETWEEN "14.5" AND "18.0" THEN "new"
        ELSE "old"
    END
      AS osv_group,
      cv.view_through,
      CASE
        WHEN cv.mmp = "KOCHAVA" THEN REGEXP_EXTRACT(cv.postback, r'&matched_by=([a-zA-Z_]*)')
        WHEN cv.mmp = "ADBRIX_V2" THEN REGEXP_EXTRACT(cv.postback, r'&measurement_type=([a-zA-Z_]*)')
        WHEN cv.mmp <> "BRANCH" THEN REGEXP_EXTRACT(cv.postback, r'&match_type=([a-zA-Z_]*)')
        ELSE "unknown"
    END
      AS method,
      COUNT(*) AS cnt
    FROM
      `focal-elf-631.prod_stream_view.cv`
    WHERE
      DATE(timestamp) > DATE_SUB(CURRENT_DATE(), INTERVAL 16 DAY) #BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
      AND UPPER(cv.event) = "INSTALL"
      AND req.device.os = "IOS"
    GROUP BY
      1,
      2,
      3,
      4,
      5 )
  WHERE
    osv_group = "new" )
SELECT
  tracking_bundle,
  CASE
    WHEN postback_pa = 'enabled' THEN CASE
    WHEN moloco_pa = 'disabled' THEN "Warning: Attribution status not aligned with postback data"
    WHEN viewthrough = 'disabled' THEN "Warning: Probabilistic Attribution is not turned on for VT installs"
    ELSE 'Probabilistic Attribution Enabled'
END
    ELSE "Warning: Probabilistic Attribution is not turned on for 14.5+ traffic"
END
  AS probabilistic_attribution_status
FROM (
  SELECT
    DISTINCT tracking_bundle,
    MAX(CASE
        WHEN is_fp_attributed IS TRUE THEN 'enabled'
        ELSE 'disabled'
    END
      ) OVER (PARTITION BY tracking_bundle) AS postback_pa,
    MAX(CASE
        WHEN ignore_mmp_feedback IS FALSE THEN 'enabled'
        ELSE 'disabled'
    END
      ) OVER (PARTITION BY tracking_bundle) AS moloco_pa,
    MAX(CASE
        WHEN is_fp_attributed IS TRUE AND view_through IS TRUE THEN 'enabled'
        ELSE 'disabled'
    END
      ) OVER (PARTITION BY tracking_bundle) AS viewthrough
  FROM
    raw )
where tracking_bundle = 'id6469305531'
### UA Society 2025 ###

https://colab.research.google.com/drive/1gui6fQ9VbFWBfF7ABC9Zgh95pCLY6CBY#scrollTo=FOMh0WQBRoMp

#THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL

  DECLARE start_date DEFAULT DATE('2025-02-01');
  DECLARE end_date DEFAULT DATE('2025-02-28');


  CREATE OR REPLACE TABLE `moloco-ods.haewon.uas25_user_analysis_rev` AS (
    WITH
      t_app AS (
      SELECT
        product.app_market_bundle,
        advertiser.mmp_bundle_id,
        SUM(gross_spend_usd) AS revenue
      FROM
        `moloco-ae-view.athena.fact_dsp_core`
      WHERE
        date_utc BETWEEN start_date AND end_date
        AND ((product.app_market_bundle = 'closet.match.pair.matching.games' AND advertiser.mmp_bundle_id = 'closet.match.pair.matching.games') OR (product.app_market_bundle = 'com.joycastle.mergematch' AND advertiser.mmp_bundle_id = 'com.joycastle.mergematch') OR (product.app_market_bundle = 'com.gamedots.seasideescape' AND advertiser.mmp_bundle_id = 'com.gamedots.seasideescape') OR (product.app_market_bundle = '1578204014' AND advertiser.mmp_bundle_id = '1578204014') OR (product.app_market_bundle = '1558803930' AND advertiser.mmp_bundle_id = 'id1558803930') OR (product.app_market_bundle = 'com.vm3.global' AND advertiser.mmp_bundle_id = 'com.vm3.global') OR (product.app_market_bundle = '1623318294' AND advertiser.mmp_bundle_id = 'id1623318294') OR (product.app_market_bundle = '6443755785' AND advertiser.mmp_bundle_id = 'id6443755785') OR (product.app_market_bundle = 'com.dreamgames.royalmatch' AND advertiser.mmp_bundle_id = 'com.dreamgames.royalmatch') OR (product.app_market_bundle = '1621328561' AND advertiser.mmp_bundle_id = '1621328561') OR (product.app_market_bundle = '1176027022' AND advertiser.mmp_bundle_id = 'id1176027022') OR (product.app_market_bundle = '1195621598' AND advertiser.mmp_bundle_id = 'id1195621598') OR (product.app_market_bundle = '6449094229' AND advertiser.mmp_bundle_id = 'id6449094229') OR (product.app_market_bundle = 'com.scopely.monopolygo' AND advertiser.mmp_bundle_id = 'com.scopely.monopolygo') OR (product.app_market_bundle = 'net.peakgames.match' AND advertiser.mmp_bundle_id = 'net.peakgames.match') OR (product.app_market_bundle = '1105855019' AND advertiser.mmp_bundle_id = 'id1105855019') OR (product.app_market_bundle = '1492722342' AND advertiser.mmp_bundle_id = 'com.innplaylabs.animalkingdom') OR (product.app_market_bundle = 'com.king.candycrushsaga' AND advertiser.mmp_bundle_id = 'com.king.candycrushsaga') OR (product.app_market_bundle = 'com.dreamgames.royalkingdom' AND advertiser.mmp_bundle_id = 'com.dreamgames.royalkingdom') OR (product.app_market_bundle = '1482155847' AND advertiser.mmp_bundle_id = 'id1482155847') OR (product.app_market_bundle = 'com.playrix.gardenscapes' AND advertiser.mmp_bundle_id = 'com.playrix.gardenscapes') OR (product.app_market_bundle = 'com.innplaylabs.animalkingdomraid' AND advertiser.mmp_bundle_id = 'com.innplaylabs.animalkingdomraid') OR (product.app_market_bundle = '553834731' AND advertiser.mmp_bundle_id = 'id553834731') OR (product.app_market_bundle = '1606549505' AND advertiser.mmp_bundle_id = 'id1606549505') OR (product.app_market_bundle = 'com.playrix.homescapes' AND advertiser.mmp_bundle_id = 'com.playrix.homescapes') OR (product.app_market_bundle = 'net.peakgames.toonblast' AND advertiser.mmp_bundle_id = 'net.peakgames.toonblast') OR (product.app_market_bundle = 'io.randomco.travel' AND advertiser.mmp_bundle_id = 'io.randomco.travel') OR (product.app_market_bundle = '1521236603' AND advertiser.mmp_bundle_id = 'id1521236603') OR (product.app_market_bundle = '6482291732' AND advertiser.mmp_bundle_id = 'id6482291732') OR (product.app_market_bundle = '852912420' AND advertiser.mmp_bundle_id = 'id852912420') OR (product.app_market_bundle = 'com.percent.aos.luckydefense' AND advertiser.mmp_bundle_id = 'com.percent.aos.luckydefense') OR (product.app_market_bundle = '1098157959' AND advertiser.mmp_bundle_id = '1098157959') OR (product.app_market_bundle = '6448786147' AND advertiser.mmp_bundle_id = 'id6448786147') OR (product.app_market_bundle = 'com.gof.global' AND advertiser.mmp_bundle_id = 'com.gof.global') OR (product.app_market_bundle = '1376515087' AND advertiser.mmp_bundle_id = 'id1376515087') OR (product.app_market_bundle = 'com.netmarble.sololv' AND advertiser.mmp_bundle_id = 'com.netmarble.sololv') OR (product.app_market_bundle = 'com.camelgames.superking' AND advertiser.mmp_bundle_id = 'com.camelgames.superking') OR (product.app_market_bundle = 'com.igg.android.doomsdaylastsurvivors' AND advertiser.mmp_bundle_id = 'com.igg.android.doomsdaylastsurvivors') OR (product.app_market_bundle = '1071744151' AND advertiser.mmp_bundle_id = 'id1071744151') OR (product.app_market_bundle = '6443575749' AND advertiser.mmp_bundle_id = '6443575749') OR (product.app_market_bundle = '1552206075' AND advertiser.mmp_bundle_id = 'id1552206075') OR (product.app_market_bundle = 'com.com2us.smon.normal.freefull.google.kr.android.common' AND advertiser.mmp_bundle_id = 'com.com2us.smon.normal.freefull.google.kr.android.common') OR (product.app_market_bundle = '1274132545' AND advertiser.mmp_bundle_id = 'id1274132545') OR (product.app_market_bundle = '1094591345' AND advertiser.mmp_bundle_id = 'id1094591345') OR (product.app_market_bundle = 'com.totalbattle' AND advertiser.mmp_bundle_id = 'com.totalbattle') OR (product.app_market_bundle = '1427744264' AND advertiser.mmp_bundle_id = '1427744264') OR (product.app_market_bundle = 'com.innogames.foeandroid' AND advertiser.mmp_bundle_id = 'com.innogames.foeandroid') OR (product.app_market_bundle = '1241932094' AND advertiser.mmp_bundle_id = 'id1241932094') OR (product.app_market_bundle = 'com.my.defense' AND advertiser.mmp_bundle_id = 'com.my.defense') OR (product.app_market_bundle = 'com.plarium.raidlegends' AND advertiser.mmp_bundle_id = 'com.plarium.raidlegends') OR (product.app_market_bundle = '1371565796' AND advertiser.mmp_bundle_id = 'id1371565796') OR (product.app_market_bundle = 'com.nexters.herowars' AND advertiser.mmp_bundle_id = 'com.nexters.herowars') OR (product.app_market_bundle = 'com.supercell.clashofclans' AND advertiser.mmp_bundle_id = 'com.supercell.clashofclans') OR (product.app_market_bundle = 'com.nianticlabs.pokemongo' AND advertiser.mmp_bundle_id = 'com.nianticlabs.pokemongo') OR (product.app_market_bundle = 'zombie.survival.craft.z' AND advertiser.mmp_bundle_id = 'zombie.survival.craft.z') OR (product.app_market_bundle = '529479190' AND advertiser.mmp_bundle_id = 'id529479190') OR (product.app_market_bundle = '711455226' AND advertiser.mmp_bundle_id = 'com.innogames.iforge') OR (product.app_market_bundle = '1526121033' AND advertiser.mmp_bundle_id = 'id1526121033'))
      GROUP BY 1, 2
      ),
      t_rev AS (
      SELECT
        CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
        END AS user_id,
        device.os,
        device.country,
        app_market_bundle,
        mmp_bundle_id,
        CASE
          WHEN device.country = 'KOR' THEN 'KR'
          WHEN device.country IN ('USA','CAN') THEN 'NA'
          WHEN device.country IN ('GBR', 'FRA', 'DEU') THEN 'EU'
          WHEN device.country IN ('JPN','HKG','TWN') THEN 'NEA'
          ELSE 'ETC' END AS region,
        TIMESTAMP_DIFF(event.event_at, event.install_at, hour) AS diff_hour,
        event.revenue_usd.amount AS revenue,
        CASE WHEN event.name IN ('client_ad_revenue', '__ADMON_USER_LEVEL_REVENUE__', 'af_ad_view', 'af_ad_revenue') THEN event.revenue_usd.amount ELSE 0 END AS revenue_iaa,
        CASE WHEN event.name NOT IN ('client_ad_revenue', '__ADMON_USER_LEVEL_REVENUE__', 'af_ad_view', 'af_ad_revenue') THEN event.revenue_usd.amount ELSE 0 END AS revenue_iap,
      FROM
        `focal-elf-631.prod_stream_view.pb`
      JOIN
        t_app
      ON
        app.bundle = mmp_bundle_id
      WHERE
        DATE(TIMESTAMP) >= start_date
        AND DATE(event.install_at) BETWEEN start_date AND end_date
        AND DATE(event.event_at) >= start_date
        AND device.country IN ('USA',
          'KOR',
          'JPN',
          'TWN',
          'GBR',
          'FRA',
          'DEU',
          'HKG',
          'CAN')
        AND event.revenue_usd.amount > 0
        AND event.revenue_usd.amount < 10000
        AND (LOWER(event.name) LIKE '%purchase%'
          OR LOWER(event.name) LIKE '%iap'
          OR LOWER(event.name) LIKE '%revenue%'
          OR LOWER(event.name) LIKE '%_ad_%'
          OR LOWER(event.name) IN ('af_top_up', 'pay', '0ofw9', 'h9bsc')
          OR LOWER(event.name) LIKE '%deposit%')
        AND LOWER(event.name) NOT LIKE '%ltv%'
        AND event.name NOT IN ('Purcahse=3', 'BOARD_3')
      )
    ,
      t_first_last AS (
      SELECT
        user_id,
        os,
        app_market_bundle,
        mmp_bundle_id,
        region,
        country,
        MIN(diff_hour) / 24 AS first_purchase_day,
        MAX(diff_hour) / 24 AS last_purchase_day,
        COUNT(1) AS purchase_count,
        ARRAY_AGG(revenue ORDER BY diff_hour)[OFFSET(0)] AS first_purchase_amount,
        SUM(
        IF
          (diff_hour < 7 * 24, revenue, NULL)) AS d7_revenue,
        SUM(
        IF
          (diff_hour < 30 * 24, revenue, NULL)) AS d30_revenue,
        SUM(revenue) AS revenue,
        SUM(
        IF
          (diff_hour < 7 * 24, revenue_iaa, NULL)) AS d7_revenue_iaa,
        SUM(
        IF
          (diff_hour < 30 * 24, revenue_iaa, NULL)) AS d30_revenue_iaa,
        SUM(revenue_iaa) AS revenue_iaa,
        SUM(
        IF
          (diff_hour < 7 * 24, revenue_iap, NULL)) AS d7_revenue_iap,
        SUM(
        IF
          (diff_hour < 30 * 24, revenue_iap, NULL)) AS d30_revenue_iap,
        SUM(revenue_iap) AS revenue_iap,
      FROM
        t_rev
      WHERE user_id IS NOT NULL
      GROUP BY
        ALL)

    SELECT
      *
    FROM
      t_first_last
  )


  ### MODIFIED QUERY TO HAVE D1 ... D30 REVENUE per user ###
  ### UA Society 2025 ###

https://colab.research.google.com/drive/1gui6fQ9VbFWBfF7ABC9Zgh95pCLY6CBY#scrollTo=FOMh0WQBRoMp

#THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL

  DECLARE start_date DEFAULT DATE('2025-02-01');
  DECLARE end_date DEFAULT DATE('2025-02-28');


  CREATE OR REPLACE TABLE `moloco-ods.haewon.uas25_user_analysis_rev_2` AS (
    WITH
      t_app AS (
      SELECT
        product.app_market_bundle,
        advertiser.mmp_bundle_id,
        SUM(gross_spend_usd) AS revenue
      FROM
        `moloco-ae-view.athena.fact_dsp_core`
      WHERE
        date_utc BETWEEN start_date AND end_date
        AND ((product.app_market_bundle = 'closet.match.pair.matching.games' AND advertiser.mmp_bundle_id = 'closet.match.pair.matching.games') OR (product.app_market_bundle = 'com.joycastle.mergematch' AND advertiser.mmp_bundle_id = 'com.joycastle.mergematch') OR (product.app_market_bundle = 'com.gamedots.seasideescape' AND advertiser.mmp_bundle_id = 'com.gamedots.seasideescape') OR (product.app_market_bundle = '1578204014' AND advertiser.mmp_bundle_id = '1578204014') OR (product.app_market_bundle = '1558803930' AND advertiser.mmp_bundle_id = 'id1558803930') OR (product.app_market_bundle = 'com.vm3.global' AND advertiser.mmp_bundle_id = 'com.vm3.global') OR (product.app_market_bundle = '1623318294' AND advertiser.mmp_bundle_id = 'id1623318294') OR (product.app_market_bundle = '6443755785' AND advertiser.mmp_bundle_id = 'id6443755785') OR (product.app_market_bundle = 'com.dreamgames.royalmatch' AND advertiser.mmp_bundle_id = 'com.dreamgames.royalmatch') OR (product.app_market_bundle = '1621328561' AND advertiser.mmp_bundle_id = '1621328561') OR (product.app_market_bundle = '1176027022' AND advertiser.mmp_bundle_id = 'id1176027022') OR (product.app_market_bundle = '1195621598' AND advertiser.mmp_bundle_id = 'id1195621598') OR (product.app_market_bundle = '6449094229' AND advertiser.mmp_bundle_id = 'id6449094229') OR (product.app_market_bundle = 'com.scopely.monopolygo' AND advertiser.mmp_bundle_id = 'com.scopely.monopolygo') OR (product.app_market_bundle = 'net.peakgames.match' AND advertiser.mmp_bundle_id = 'net.peakgames.match') OR (product.app_market_bundle = '1105855019' AND advertiser.mmp_bundle_id = 'id1105855019') OR (product.app_market_bundle = '1492722342' AND advertiser.mmp_bundle_id = 'com.innplaylabs.animalkingdom') OR (product.app_market_bundle = 'com.king.candycrushsaga' AND advertiser.mmp_bundle_id = 'com.king.candycrushsaga') OR (product.app_market_bundle = 'com.dreamgames.royalkingdom' AND advertiser.mmp_bundle_id = 'com.dreamgames.royalkingdom') OR (product.app_market_bundle = '1482155847' AND advertiser.mmp_bundle_id = 'id1482155847') OR (product.app_market_bundle = 'com.playrix.gardenscapes' AND advertiser.mmp_bundle_id = 'com.playrix.gardenscapes') OR (product.app_market_bundle = 'com.innplaylabs.animalkingdomraid' AND advertiser.mmp_bundle_id = 'com.innplaylabs.animalkingdomraid') OR (product.app_market_bundle = '553834731' AND advertiser.mmp_bundle_id = 'id553834731') OR (product.app_market_bundle = '1606549505' AND advertiser.mmp_bundle_id = 'id1606549505') OR (product.app_market_bundle = 'com.playrix.homescapes' AND advertiser.mmp_bundle_id = 'com.playrix.homescapes') OR (product.app_market_bundle = 'net.peakgames.toonblast' AND advertiser.mmp_bundle_id = 'net.peakgames.toonblast') OR (product.app_market_bundle = 'io.randomco.travel' AND advertiser.mmp_bundle_id = 'io.randomco.travel') OR (product.app_market_bundle = '1521236603' AND advertiser.mmp_bundle_id = 'id1521236603') OR (product.app_market_bundle = '6482291732' AND advertiser.mmp_bundle_id = 'id6482291732') OR (product.app_market_bundle = '852912420' AND advertiser.mmp_bundle_id = 'id852912420') OR (product.app_market_bundle = 'com.percent.aos.luckydefense' AND advertiser.mmp_bundle_id = 'com.percent.aos.luckydefense') OR (product.app_market_bundle = '1098157959' AND advertiser.mmp_bundle_id = '1098157959') OR (product.app_market_bundle = '6448786147' AND advertiser.mmp_bundle_id = 'id6448786147') OR (product.app_market_bundle = 'com.gof.global' AND advertiser.mmp_bundle_id = 'com.gof.global') OR (product.app_market_bundle = '1376515087' AND advertiser.mmp_bundle_id = 'id1376515087') OR (product.app_market_bundle = 'com.netmarble.sololv' AND advertiser.mmp_bundle_id = 'com.netmarble.sololv') OR (product.app_market_bundle = 'com.camelgames.superking' AND advertiser.mmp_bundle_id = 'com.camelgames.superking') OR (product.app_market_bundle = 'com.igg.android.doomsdaylastsurvivors' AND advertiser.mmp_bundle_id = 'com.igg.android.doomsdaylastsurvivors') OR (product.app_market_bundle = '1071744151' AND advertiser.mmp_bundle_id = 'id1071744151') OR (product.app_market_bundle = '6443575749' AND advertiser.mmp_bundle_id = '6443575749') OR (product.app_market_bundle = '1552206075' AND advertiser.mmp_bundle_id = 'id1552206075') OR (product.app_market_bundle = 'com.com2us.smon.normal.freefull.google.kr.android.common' AND advertiser.mmp_bundle_id = 'com.com2us.smon.normal.freefull.google.kr.android.common') OR (product.app_market_bundle = '1274132545' AND advertiser.mmp_bundle_id = 'id1274132545') OR (product.app_market_bundle = '1094591345' AND advertiser.mmp_bundle_id = 'id1094591345') OR (product.app_market_bundle = 'com.totalbattle' AND advertiser.mmp_bundle_id = 'com.totalbattle') OR (product.app_market_bundle = '1427744264' AND advertiser.mmp_bundle_id = '1427744264') OR (product.app_market_bundle = 'com.innogames.foeandroid' AND advertiser.mmp_bundle_id = 'com.innogames.foeandroid') OR (product.app_market_bundle = '1241932094' AND advertiser.mmp_bundle_id = 'id1241932094') OR (product.app_market_bundle = 'com.my.defense' AND advertiser.mmp_bundle_id = 'com.my.defense') OR (product.app_market_bundle = 'com.plarium.raidlegends' AND advertiser.mmp_bundle_id = 'com.plarium.raidlegends') OR (product.app_market_bundle = '1371565796' AND advertiser.mmp_bundle_id = 'id1371565796') OR (product.app_market_bundle = 'com.nexters.herowars' AND advertiser.mmp_bundle_id = 'com.nexters.herowars') OR (product.app_market_bundle = 'com.supercell.clashofclans' AND advertiser.mmp_bundle_id = 'com.supercell.clashofclans') OR (product.app_market_bundle = 'com.nianticlabs.pokemongo' AND advertiser.mmp_bundle_id = 'com.nianticlabs.pokemongo') OR (product.app_market_bundle = 'zombie.survival.craft.z' AND advertiser.mmp_bundle_id = 'zombie.survival.craft.z') OR (product.app_market_bundle = '529479190' AND advertiser.mmp_bundle_id = 'id529479190') OR (product.app_market_bundle = '711455226' AND advertiser.mmp_bundle_id = 'com.innogames.iforge') OR (product.app_market_bundle = '1526121033' AND advertiser.mmp_bundle_id = 'id1526121033'))
      GROUP BY 1, 2
      ),
      t_rev AS (
      SELECT
        CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
        END AS user_id,
        device.os,
        device.country,
        app_market_bundle,
        mmp_bundle_id,
        CASE
          WHEN device.country = 'KOR' THEN 'KR'
          WHEN device.country IN ('USA','CAN') THEN 'NA'
          WHEN device.country IN ('GBR', 'FRA', 'DEU') THEN 'EU'
          WHEN device.country IN ('JPN','HKG','TWN') THEN 'NEA'
          ELSE 'ETC' END AS region,
        TIMESTAMP_DIFF(event.event_at, event.install_at, hour) AS diff_hour,
        event.revenue_usd.amount AS revenue,
        CASE WHEN event.name IN ('client_ad_revenue', '__ADMON_USER_LEVEL_REVENUE__', 'af_ad_view', 'af_ad_revenue') THEN event.revenue_usd.amount ELSE 0 END AS revenue_iaa,
        CASE WHEN event.name NOT IN ('client_ad_revenue', '__ADMON_USER_LEVEL_REVENUE__', 'af_ad_view', 'af_ad_revenue') THEN event.revenue_usd.amount ELSE 0 END AS revenue_iap,
      FROM
        `focal-elf-631.prod_stream_view.pb`
      JOIN
        t_app
      ON
        app.bundle = mmp_bundle_id
      WHERE
        DATE(TIMESTAMP) >= start_date
        AND DATE(event.install_at) BETWEEN start_date AND end_date
        AND DATE(event.event_at) >= start_date
        AND device.country IN ('USA',
          'KOR',
          'JPN',
          'TWN',
          'GBR',
          'FRA',
          'DEU',
          'HKG',
          'CAN')
        AND event.revenue_usd.amount > 0
        AND event.revenue_usd.amount < 10000
        AND (LOWER(event.name) LIKE '%purchase%'
          OR LOWER(event.name) LIKE '%iap'
          OR LOWER(event.name) LIKE '%revenue%'
          OR LOWER(event.name) LIKE '%_ad_%'
          OR LOWER(event.name) IN ('af_top_up', 'pay', '0ofw9', 'h9bsc')
          OR LOWER(event.name) LIKE '%deposit%')
        AND LOWER(event.name) NOT LIKE '%ltv%'
        AND event.name NOT IN ('Purcahse=3', 'BOARD_3')
      )
    ,
    t_user_day_revenue AS (
        SELECT
        user_id,
        os,
        app_market_bundle,
        mmp_bundle_id,
        region,
        country,
        FLOOR(diff_hour / 24) + 1 AS diff_day,
        SUM(revenue) AS revenue,
        SUM(revenue_iaa) AS revenue_iaa,
        SUM(revenue_iap) AS revenue_iap
        FROM
            t_rev
        WHERE
            user_id IS NOT NULL
            AND diff_hour < 30 * 24
        GROUP BY
            user_id, os, app_market_bundle, mmp_bundle_id, region, country, diff_day
    ),
    
    t_user_summary AS (
        SELECT
            user_id,
            MIN(diff_hour) / 24 AS first_purchase_day,
            MAX(diff_hour) / 24 AS last_purchase_day,
            COUNT(1) AS purchase_count,
            ARRAY_AGG(revenue ORDER BY diff_hour)[OFFSET(0)] AS first_purchase_amount
        FROM
            t_rev
        WHERE
            user_id IS NOT NULL
        GROUP BY
            user_id
  )

    SELECT
        d.user_id,
        d.diff_day,
        d.revenue,
        d.revenue_iaa,
        d.revenue_iap,
        s.first_purchase_day,
        s.last_purchase_day,
        s.purchase_count,
        s.first_purchase_amount,
        d.os,
        d.region,
        d.country,
        d.app_market_bundle,
        d.mmp_bundle_id
    FROM
        t_user_day_revenue d
    LEFT JOIN
        t_user_summary s
    ON
        d.user_id = s.user_id

  )



### full funnel -- performance along the PLC ###

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL

CREATE OR REPLACE TABLE `moloco-ods.haewon.full_funnel_fully_engaged_plus_overD150_apps_revenue` AS
  WITH 
  app_release AS (
    SELECT '6476976929' AS app_market_bundle, DATE('2024-05-07') AS release_date UNION ALL
SELECT 'com.topgamesinc.ac' AS app_market_bundle, DATE('2024-04-23') AS release_date UNION ALL
SELECT '6451403685' AS app_market_bundle, DATE('2023-08-09') AS release_date UNION ALL
SELECT 'com.netease.nshmhmt' AS app_market_bundle, DATE('2024-04-11') AS release_date UNION ALL
SELECT '6443792064' AS app_market_bundle, DATE('2023-08-18') AS release_date UNION ALL
SELECT 'com.global.pnckru' AS app_market_bundle, DATE('2023-10-26') AS release_date UNION ALL
SELECT 'com.oakever.tiletrip' AS app_market_bundle, DATE('2024-05-17') AS release_date UNION ALL
SELECT 'hidden.objects.find.it.out.seek.puzzle.games.free' AS app_market_bundle, DATE('2024-01-26') AS release_date UNION ALL
SELECT 'com.proximabeta.aoemobile' AS app_market_bundle, DATE('2024-01-31') AS release_date UNION ALL
SELECT 'com.vitastudio.color.paint.free.coloring.number' AS app_market_bundle, DATE('2023-08-29') AS release_date UNION ALL
SELECT '6446246671' AS app_market_bundle, DATE('2023-09-11') AS release_date UNION ALL
SELECT 'sudoku.puzzle.brain.games.number.puzzles.free' AS app_market_bundle, DATE('2024-06-14') AS release_date UNION ALL
SELECT 'com.netease.dfjsjp' AS app_market_bundle, DATE('2024-03-08') AS release_date UNION ALL
SELECT '6463851493' AS app_market_bundle, DATE('2023-09-24') AS release_date UNION ALL
SELECT 'com.fatmerge.global' AS app_market_bundle, DATE('2023-12-26') AS release_date UNION ALL
SELECT '6483211224' AS app_market_bundle, DATE('2024-04-24 00:00:00') AS release_date UNION ALL
SELECT '6447841794' AS app_market_bundle, DATE('2023-10-10 00:00:00') AS release_date UNION ALL
SELECT '6449934686' AS app_market_bundle, DATE('2023-09-09 00:00:00') AS release_date UNION ALL
SELECT '6459830966' AS app_market_bundle, DATE('2023-08-29 00:00:00') AS release_date UNION ALL
SELECT 'com.netmarble.sololv' AS app_market_bundle, DATE('2024-03-19 00:00:00') AS release_date UNION ALL
SELECT '6443950173' AS app_market_bundle, DATE('2024-01-05 00:00:00') AS release_date UNION ALL
SELECT '6443950173' AS app_market_bundle, DATE('2024-01-05 00:00:00') AS release_date UNION ALL
SELECT '6469999573' AS app_market_bundle, DATE('2024-04-09 00:00:00') AS release_date UNION ALL
SELECT '6450006659' AS app_market_bundle, DATE('2023-10-17 00:00:00') AS release_date UNION ALL
SELECT '6502750094' AS app_market_bundle, DATE('2024-05-30 00:00:00') AS release_date
  ),
  bundle AS (
    SELECT DISTINCT
      product.app_market_bundle,
      advertiser.mmp_bundle_id,
      campaign.os
      FROM `moloco-ae-view.athena.fact_dsp_core`
      WHERE date_utc >= '2023-07-01'
        AND product.app_market_bundle IN (
          (SELECT DISTINCT app_market_bundle FROM app_release)
        )
      GROUP BY ALL
  )
  ,t_rev AS (
    SELECT
      CASE
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
        WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
        ELSE NULL
      END AS user_id,
      device.os,
      device.country,
      bundle.app_market_bundle,
      app.bundle AS mmp_bundle_id,
      ar.release_date,
      moloco.attributed,
      DATE(event.install_at) AS install_dt, 
      TIMESTAMP_DIFF(event.event_at, event.install_at, hour) AS diff_hour,
      event.revenue_usd.amount AS revenue
      FROM
      `focal-elf-631.prod_stream_view.pb` JOIN bundle 
        ON app.bundle = bundle.mmp_bundle_id AND device.os = bundle.os
        JOIN app_release ar ON ar.app_market_bundle = bundle.app_market_bundle
      WHERE
          DATE(TIMESTAMP) >= '2023-07-01'
          AND DATE(TIMESTAMP) >= ar.release_date
          AND DATE(event.install_at) BETWEEN ar.release_date AND DATE_ADD(ar.release_date, INTERVAL 300 DAY)
          AND DATE(event.event_at) >= ar.release_date
          AND event.revenue_usd.amount > 0
          AND event.revenue_usd.amount < 10000
          AND (LOWER(event.name) LIKE '%purchase%'
            OR LOWER(event.name) LIKE '%iap'
            OR LOWER(event.name) LIKE '%revenue%'
            OR LOWER(event.name) LIKE '%_ad_%'
            OR LOWER(event.name) IN ('af_top_up', 'pay', '0ofw9', 'h9bsc')
            OR LOWER(event.name) LIKE '%deposit%')
          AND LOWER(event.name) NOT LIKE '%ltv%'
          AND event.name NOT IN ('Purcahse=3', 'BOARD_3')
        ),

  t_user_day_revenue AS (
        SELECT
          app_market_bundle,
          release_date,
          user_id,
          os,
          country,
          install_dt,
          FLOOR(diff_hour / 24) + 1 AS diff_day,
          attributed,
          SUM(revenue) AS revenue
        FROM
          t_rev
        WHERE
          user_id IS NOT NULL
          AND diff_hour < 30 * 24 # Limiting to D30 Revenue
        GROUP BY
          ALL
          ),
  
  t_user_summary AS (
      SELECT
          app_market_bundle,
          release_date,
          user_id,
          MIN(diff_hour) / 24 AS first_purchase_day,
          MAX(diff_hour) / 24 AS last_purchase_day,
          COUNT(1) AS purchase_count,
          ARRAY_AGG(revenue ORDER BY diff_hour)[OFFSET(0)] AS first_purchase_amount
      FROM
          t_rev
      WHERE
          user_id IS NOT NULL
      GROUP BY
          1,2,3
)

  SELECT
    d.app_market_bundle,
    d.release_date,
    d.user_id,
    d.os,
    d.country,
    d.install_dt,
    d.diff_day,
    d.attributed,
    d.revenue,
    s.first_purchase_day,
    s.last_purchase_day,
    s.purchase_count,
    s.first_purchase_amount
  FROM 
    t_user_day_revenue d
  LEFT JOIN
    t_user_summary s USING (user_id)

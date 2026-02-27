# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL

  DECLARE start_date DEFAULT DATE('2025-02-01');
  DECLARE end_date DEFAULT DATE('2025-02-28');

  CREATE OR REPLACE TABLE `moloco-ods.haewon.uas25_user_analysis_ret` AS (

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

    installs AS (
    SELECT 
      user_id,
      os,
      app_market_bundle,
      mmp_bundle_id,
      region,
      min(timestamp) as timestamp
    FROM(
        SELECT
          CASE
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
            WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
            ELSE NULL
          END AS user_id,
          device.os,
          app_market_bundle,
          mmp_bundle_id,
          CASE
            WHEN device.country = 'KOR' THEN 'KR'
            WHEN device.country IN ('USA','CAN') THEN 'NA'
            WHEN device.country IN ('GBR', 'FRA', 'DEU') THEN 'EU'
            WHEN device.country IN ('JPN','HKG','TWN') THEN 'NEA'
            ELSE 'ETC' END AS region,        
          event.event_at AS timestamp,
        FROM
          `focal-elf-631.prod_stream_view.pb`
        JOIN 
          t_app
        ON app.bundle = mmp_bundle_id
        WHERE 1=1
          AND DATE(timestamp) >= start_date AND DATE(timestamp) <= end_date
          AND event_name = 'install'
          AND device.country IN ('KOR', 'USA', 'CAN', 'GBR', 'FRA', 'DEU', 'TWN', 'JPN', 'HKG')
      )
      WHERE user_id IS NOT NULL
      GROUP BY 1,2,3,4,5
      ),

    actions AS (
    SELECT * 
    FROM (
      SELECT
          CASE
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN "ifv:" || device.idfv
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN "ifa:" || device.idfa
            WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
            ELSE NULL
          END AS user_id,
          app_market_bundle,
          mmp_bundle_id,
        timestamp
      FROM
        `focal-elf-631.df_accesslog.pb`
      JOIN 
          t_app
      ON 
          app.bundle = mmp_bundle_id
      WHERE 1=1
        AND DATE(timestamp) >= start_date AND DATE(timestamp) <= DATE_ADD(end_date, INTERVAL 30 DAY)
        AND event.name != 'install'
        AND LOWER(event.name) NOT LIKE "%ltv%"
        AND lower(event.name) NOT IN ('reinstall', 'reattribution')
        AND lower(event.name) NOT LIKE '%conver%'
        AND lower(event.name) NOT LIKE '%pecan%'
        AND device.country IN ('KOR', 'USA', 'CAN', 'GBR', 'FRA', 'DEU', 'TWN', 'JPN', 'HKG')
      )
    WHERE user_id IS NOT NULL
    ),

    T as (
      SELECT
        installs.user_id as inst_user_id,
        actions.user_id as action_user_id,      
        installs.app_market_bundle,
        installs.mmp_bundle_id,
        os,
        installs.region,
        TIMESTAMP_DIFF(actions.timestamp, installs.timestamp, DAY) as day_diff,
        COUNT(DISTINCT installs.user_id) OVER 
          (PARTITION BY installs.app_market_bundle, installs.os, installs.region) AS installs_for_group,
      FROM
        installs
      LEFT JOIN
        actions
      ON
        installs.user_id = actions.user_id
        AND installs.app_market_bundle = actions.app_market_bundle
        AND installs.mmp_bundle_id = actions.mmp_bundle_id
        AND actions.timestamp > installs.timestamp
    )

  SELECT
    app_market_bundle,
    mmp_bundle_id,
    os,
    region,
    day_diff,
    ANY_VALUE(installs_for_group) AS installs,
    COUNT(DISTINCT action_user_id) AS retention_for_day
  FROM T
  WHERE day_diff < 30
  GROUP BY
    1,2,3,4,5
  ORDER BY
    1,2,3,4,5
  )

##### 쿼리 업데이트 ######

  WITH app_filter AS (
  SELECT 'closet.match.pair.matching.games' AS bundle, 'closet.match.pair.matching.games' AS mmp_bundle_id UNION ALL
  SELECT 'com.joycastle.mergematch', 'com.joycastle.mergematch' UNION ALL
  SELECT 'com.gamedots.seasideescape', 'com.gamedots.seasideescape' UNION ALL
  SELECT '1578204014', '1578204014' UNION ALL
  SELECT '1558803930', 'id1558803930' UNION ALL
  SELECT 'com.vm3.global', 'com.vm3.global' UNION ALL
  SELECT '1623318294', 'id1623318294' UNION ALL
  SELECT '6443755785', 'id6443755785' UNION ALL
  SELECT 'com.dreamgames.royalmatch', 'com.dreamgames.royalmatch' UNION ALL
  SELECT '1621328561', '1621328561' UNION ALL
  SELECT '1176027022', 'id1176027022' UNION ALL
  SELECT '1195621598', 'id1195621598' UNION ALL
  SELECT '6449094229', 'id6449094229' UNION ALL
  SELECT 'com.scopely.monopolygo', 'com.scopely.monopolygo' UNION ALL
  SELECT 'net.peakgames.match', 'net.peakgames.match' UNION ALL
  SELECT '1105855019', 'id1105855019' UNION ALL
  SELECT '1492722342', 'com.innplaylabs.animalkingdom' UNION ALL
  SELECT 'com.king.candycrushsaga', 'com.king.candycrushsaga' UNION ALL
  SELECT 'com.dreamgames.royalkingdom', 'com.dreamgames.royalkingdom' UNION ALL
  SELECT '1482155847', 'id1482155847' UNION ALL
  SELECT 'com.playrix.gardenscapes', 'com.playrix.gardenscapes' UNION ALL
  SELECT 'com.innplaylabs.animalkingdomraid', 'com.innplaylabs.animalkingdomraid' UNION ALL
  SELECT '553834731', 'id553834731' UNION ALL
  SELECT '1606549505', 'id1606549505' UNION ALL
  SELECT 'com.playrix.homescapes', 'com.playrix.homescapes' UNION ALL
  SELECT 'net.peakgames.toonblast', 'net.peakgames.toonblast' UNION ALL
  SELECT 'io.randomco.travel', 'io.randomco.travel' UNION ALL
  SELECT '1521236603', 'id1521236603' UNION ALL
  SELECT '6482291732', 'id6482291732' UNION ALL
  SELECT '852912420', 'id852912420' UNION ALL
  SELECT 'com.percent.aos.luckydefense', 'com.percent.aos.luckydefense' UNION ALL
  SELECT '1098157959', '1098157959' UNION ALL
  SELECT '6448786147', 'id6448786147' UNION ALL
  SELECT 'com.gof.global', 'com.gof.global' UNION ALL
  SELECT '1376515087', 'id1376515087' UNION ALL
  SELECT 'com.netmarble.sololv', 'com.netmarble.sololv' UNION ALL
  SELECT 'com.camelgames.superking', 'com.camelgames.superking' UNION ALL
  SELECT 'com.igg.android.doomsdaylastsurvivors', 'com.igg.android.doomsdaylastsurvivors' UNION ALL
  SELECT '1071744151', 'id1071744151' UNION ALL
  SELECT '6443575749', '6443575749' UNION ALL
  SELECT '1552206075', 'id1552206075' UNION ALL
  SELECT 'com.com2us.smon.normal.freefull.google.kr.android.common', 'com.com2us.smon.normal.freefull.google.kr.android.common' UNION ALL
  SELECT '1274132545', 'id1274132545' UNION ALL
  SELECT '1094591345', 'id1094591345' UNION ALL
  SELECT 'com.totalbattle', 'com.totalbattle' UNION ALL
  SELECT '1427744264', '1427744264' UNION ALL
  SELECT 'com.innogames.foeandroid', 'com.innogames.foeandroid' UNION ALL
  SELECT '1241932094', 'id1241932094' UNION ALL
  SELECT 'com.my.defense', 'com.my.defense' UNION ALL
  SELECT 'com.plarium.raidlegends', 'com.plarium.raidlegends' UNION ALL
  SELECT '1371565796', 'id1371565796' UNION ALL
  SELECT 'com.nexters.herowars', 'com.nexters.herowars' UNION ALL
  SELECT 'com.supercell.clashofclans', 'com.supercell.clashofclans' UNION ALL
  SELECT 'com.nianticlabs.pokemongo', 'com.nianticlabs.pokemongo' UNION ALL
  SELECT 'zombie.survival.craft.z', 'zombie.survival.craft.z' UNION ALL
  SELECT '529479190', 'id529479190' UNION ALL
  SELECT '711455226', 'com.innogames.iforge' UNION ALL
  SELECT '1526121033', 'id1526121033'
)

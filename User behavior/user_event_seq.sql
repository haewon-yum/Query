DECLARE
  run_from_date DATE DEFAULT '2024-07-01';
DECLARE
  run_to_date DATE DEFAULT '2024-10-20';
DECLARE
  platform_id ARRAY<STRING> DEFAULT [
      '111PERCENT',
      'MYGAMES',
      'Lessmore',
      'TREEPLLA',
      'PLAYTIKA',
      'FUSEBOX',
      'RANXUN',
      'DREAMGAMES',
      'SCOPELY',
      'KING',
      'PLAYRIX',
      'CENTURY_GAMES',
      'SCOREWARRIOR',
      'APPQUANTUM',
      'INNPLAYLABS',
      'PRODUCT_MADNESS',
      'PEAK',
      'VIACOM18_ENTERTAINMENT'
];
DECLARE
  app_bundle ARRAY<STRING> DEFAULT [
    'com.percent.aos.luckydefense',
    'com.fuseboxgames.loveisland2.gp',
    'fi.reworks.redecor',
    'com.vjsjlqvlmp.wearewarriors',
    'com.einckla.breaktea',
    'com.kidultlovin.royalsolitairesonic.bubbleshoot.classic',
    'com.tree.idle.cat.office',
    'com.lquilwe.fhuela',
    'com.my.defense',
    'com.dreamgames.royalmatch',
    'net.peakgames.match',
    'com.scopely.monopolygo',
    'com.gof.global',
    'com.king.candycrushsaga',
    'com.totalbattle',
    'com.productmadness.cashmancasino',
    'com.playrix.gardenscapes',
    'com.redcell.goldandgoblins',
    'com.innplaylabs.animalkingdomraid'
];

WITH advertiser AS (
    SELECT
    *,
    COALESCE(DATE_SUB(LAG(effective_date_local) OVER(PARTITION BY platform_id, advertiser_id ORDER BY effective_date_local DESC), INTERVAL 1 DAY), run_to_date) AS last_effective_date_local,
    FROM (
        SELECT
            DISTINCT effective_date_local,
            platform.id AS platform_id,
            advertiser.id AS advertiser_id,
            advertiser.timezone AS advertiser_timezone,
            platform.serving_cost_percent AS platform_serving_cost_percent,
            platform.contract_markup_percent AS platform_markup_percent
        FROM
            `moloco-dsp-data-source.costbook.costbook`
        WHERE
            campaign.country = 'USA'
            AND platform.id IN UNNEST(platform_id)
            AND DATE_DIFF(run_to_date, effective_date_local, DAY) >=0 
    ) 
),
advertiser_timezone AS (
    SELECT
        DISTINCT platform_id,
        advertiser_id,
        advertiser_timezone
    FROM
        advertiser 
)

-- SELECT
--   first_event,
--   count(1) as cnt
-- FROM(
--   SELECT
--       DATE(C.timestamp, A.advertiser_timezone) AS local_dt,
--       C.bid.mtid,
--       ARRAY_AGG(C.cv.event_pb ORDER BY timestamp LIMIT 1)[OFFSET(0)] AS first_event,
--   FROM `focal-elf-631.prod_stream_view.cv` AS C
--     INNER JOIN advertiser_timezone AS A USING(platform_id, advertiser_id)
--   WHERE 
--       DATE(timestamp) BETWEEN run_from_date AND run_to_date
--       AND api.product.app.store_id IN UNNEST(app_bundle)
--       -- AND cv.revenue_usd.amount = 0
--   GROUP BY 1,2
-- ) t
-- GROUP BY ALL

SELECT
    api.product.app.store_id,
    DATE(C.timestamp, A.advertiser_timezone) AS local_dt,
    C.bid.mtid,
    ARRAY_AGG(C.cv.event_pb ORDER BY timestamp) AS event_seq,
FROM `focal-elf-631.prod_stream_view.cv` AS C
    INNER JOIN advertiser_timezone AS A USING(platform_id, advertiser_id)
WHERE 
    DATE(timestamp) BETWEEN run_from_date AND run_to_date
AND api.product.app.store_id IN UNNEST(app_bundle)
GROUP BY ALL
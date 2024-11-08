WITH fact_dsp_publisher AS (SELECT * FROM `moloco-ae-view.athena.fact_dsp_publisher`
      WHERE
          ( TIMESTAMP(date_utc)  >= TIMESTAMP('2024-09-25 00:00:00'))
      
      ),
adv_publisher AS (
SELECT
    (DATE(TIMESTAMP(fact_dsp_publisher.date_local) )) AS fact_dsp_publisher_local_date,
    fact_dsp_publisher.publisher.app_market_bundle  AS fact_dsp_publisher_publisher_app_market_bundle,
    fact_dsp_publisher.advertiser_id  AS fact_dsp_publisher_advertiser_id,
    COALESCE(SUM(fact_dsp_publisher.gross_spend_usd ), 0) AS fact_dsp_publisher_gross_spend_usd
FROM fact_dsp_publisher
WHERE (TIMESTAMP(fact_dsp_publisher.date_utc) ) >= (TIMESTAMP('2024-09-25 00:00:00')) 
    AND (fact_dsp_publisher.advertiser_id ) = 'gez3LMPdQulTcYEq' 
    AND (fact_dsp_publisher.publisher.app_market_bundle ) IN ('com.Idle.rpg.freeTDgames', 
                                                                'com.gma.ball.sort.color.water.puzzle', 
                                                                'com.gma.water.sort.puzzle', 
                                                                'com.healthmonitor.asd', 
                                                                'com.rayole.colorz')
GROUP BY ALL
ORDER BY
    1 DESC
), 
all_publisher AS (
    SELECT
    (DATE(TIMESTAMP(fact_dsp_publisher.date_local) )) AS fact_dsp_publisher_local_date,
    fact_dsp_publisher.publisher.app_market_bundle  AS fact_dsp_publisher_publisher_app_market_bundle,
    -- fact_dsp_publisher.advertiser_id  AS fact_dsp_publisher_advertiser_id,
    COALESCE(SUM(fact_dsp_publisher.gross_spend_usd ), 0) AS fact_dsp_publisher_gross_spend_usd
FROM fact_dsp_publisher
WHERE (TIMESTAMP(fact_dsp_publisher.date_utc) ) >= (TIMESTAMP('2024-09-25 00:00:00')) 
    AND (fact_dsp_publisher.publisher.app_market_bundle ) IN ('com.Idle.rpg.freeTDgames', 
                                                                'com.gma.ball.sort.color.water.puzzle', 
                                                                'com.gma.water.sort.puzzle', 
                                                                'com.healthmonitor.asd', 
                                                                'com.rayole.colorz')
GROUP BY ALL
ORDER BY
    1 DESC
)

SELECT  
    t1.fact_dsp_publisher_local_date,
    t1.fact_dsp_publisher_publisher_app_market_bundle,
    t1.fact_dsp_publisher_gross_spend_usd as global_spend,
    t2.fact_dsp_publisher_gross_spend_usd as advertiser_spend
FROM all_publisher t1 LEFT JOIN adv_publisher t2
    USING(fact_dsp_publisher_local_date, fact_dsp_publisher_publisher_app_market_bundle)
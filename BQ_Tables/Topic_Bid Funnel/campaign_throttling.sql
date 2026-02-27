-- This query checks for the campaign / ad group block reason for the internal auction
    SELECT
        date AS utc_date,
        campaign,
        reason_order,
        reason_block,
        CASE
        WHEN reason IN ('(campaign) Req', '(ad_group) Req', '(campaign) Ctx') THEN CONCAT(reason, ' - ', reason_raw)
        ELSE
        reason
        END
        AS reason,
        COUNT(1) AS bidreq_count
    FROM
        `moloco-data-prod.younghan.campaign_trace_raw_prod`
    WHERE
        date BETWEEN '2024-11-21' AND '2024-12-10'
        and campaign = "e6KjGFoynXGDiVlk"
        AND reason_block IN ('Get candidate campaigns',
        'Evaluate candidate campaigns',
        'get candidate ad_groups') -- adgroup level
    GROUP BY ALL


/* 
    looking at reason_raw behind the upper level throttling reason
*/
    SELECT        
        reason_raw, COUNT(*)
    FROM `moloco-data-prod.younghan.campaign_trace_raw_prod`
    WHERE
        date >= '2025-12-24'
        AND campaign IN ('')
        AND reason='SKAN setting'
    GROUP BY 1
    ORDER BY 2 DESC
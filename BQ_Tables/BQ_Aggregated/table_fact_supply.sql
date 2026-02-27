/* ads-bpd-guard-china.athena.fact_supply */

SELECT
    date_utc,
    campaign_id,
    SUM(bid_request)

FROM `ads-bpd-guard-china.athena.fact_supply`
WHERE date_utc = CURRENT_DATE()
    AND platform = 'NETMARBLE'
GROUP BY ALL
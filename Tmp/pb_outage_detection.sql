# Postback outage global pull

DECLARE start_date DATE DEFAULT '2025-04-01';
DECLARE end_date DATE DEFAULT DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY);
DECLARE spend_threshold INT64 DEFAULT 10000;
DECLARE daily_spend_threshold FLOAT64 DEFAULT 300.0;

# Bundles with spend > spend_threshold
with agg as (
    select
        advertiser.office_region,
        platform_id,
        advertiser.gm,
        product.app_name,
        product.app_market_bundle,
        campaign.os,
        campaign.goal as campaign_goal,
        campaign_id,
        campaign.title as campaign_title,
        SPLIT(campaign.kpi_actions) AS kpi_actions,
        count(distinct case when gross_spend_usd > 0 then date_utc else null end) as days_active,
        sum(gross_spend_usd) as spend
    from `moloco-ae-view.athena.fact_dsp_core`
    where date_utc between start_date and end_date
        AND advertiser.office_region in ('APAC')
    GROUP BY ALL
    HAVING SAFE_DIVIDE(spend, days_active) >= daily_spend_threshold

)# Unsampled postback -- unattributed & attributed kpi event volume dod change
,
pb_daily as (
    select *,
        lag(cnt) over(partition by bundle, mmp, campaign_id, kpi_event, attributed order by date) as cnt_prev
    from(
        SELECT
            app.bundle,
            mmp.name as mmp,
            moloco.campaign_id,
            event.name as kpi_event,
            date(timestamp) as date,
            moloco.attributed,
            count(*) as cnt
        FROM `focal-elf-631.prod_stream_view.pb`
        WHERE date(timestamp) between start_date and end_date
            AND app.bundle in (select distinct app_market_bundle from agg)
            AND (event.name in (select distinct kpi from agg, UNNEST(kpi_actions) kpi) AND event.name not in ('install'))
            AND mmp.name not in ('SKADNETWORK')
        group by all
    )
),

# All bundles with unattributed & attributed flags
flag as (
    select 
        bundle,
        kpi_event,
        flag_attributed,
        flag_unattributed,
        min(case when flag_attributed = 1 then date else null end) as min_date_attributed_flag,
        max(case when flag_attributed = 1 then date else null end) as max_date_attributed_flag,
        min(case when flag_unattributed = 1 then date else null end) as min_date_unattributed_flag,
        max(case when flag_unattributed = 1 then date else null end) as max_date_unattributed_flag
    from (
        select *,
            safe_divide(cnt-cnt_prev, cnt_prev) as dod_pct_change,
            case when attributed = true and abs(safe_divide(cnt-cnt_prev, cnt_prev)) > 0.3 then 1 else 0 end as flag_attributed,
            case when attributed = false and abs(safe_divide(cnt-cnt_prev, cnt_prev)) > 0.5 then 1 else 0 end as flag_unattributed
        from pb_daily
    )
    group by all
)

# Agg summarization
select *
from (
    select a.*,
        coalesce(b.flag_attributed,0) as flag_attributed,
        coalesce(c.flag_unattributed,0) as flag_unattributed,
        min_date_attributed_flag,
        max_date_attributed_flag,
        min_date_unattributed_flag,
        max_date_unattributed_flag
    from agg a
        left join (select distinct bundle, kpi_event, flag_attributed, min_date_attributed_flag, max_date_attributed_flag from flag where flag_attributed = 1) b
        on a.app_market_bundle = b.bundle and b.kpi_event IN UNNEST(a.kpi_actions)
        left join (select distinct bundle, kpi_event, flag_unattributed, min_date_unattributed_flag, max_date_unattributed_flag from flag where flag_unattributed = 1) c
        on a.app_market_bundle = c.bundle and c.kpi_event IN UNNEST(a.kpi_actions)
)
where flag_attributed = 1 and flag_unattributed = 1
order by 1,2,3,4,5,6
limit 2000
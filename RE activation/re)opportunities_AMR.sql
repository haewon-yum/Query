# update: 9/12/2025
# With unattributed data (Y/N) for existing bundles		
# filter out apps with less than 1M installed users		
DECLARE min_audience_size INT64 DEFAULT 1000000;		
# assumption of daily revenue opportunity per user (based on Pinterests stable $20k DRR @ 30M inactive users)		

DECLARE rev_per_user FLOAT64 DEFAULT 20000 / 30000000;		
DECLARE start_date DATE DEFAULT '2025-08-01';
DECLARE end_date DATE DEFAULT '2025-08-31';
		
WITH advertiser_activity as (		
    SELECT		
        platform_id,		
        product.app_market_bundle,		
        campaign.os,		
        MAX(advertiser.office_region) as office_region,		
        MAX(advertiser.growth_pod) as growth_pod,		
        COALESCE(MAX(advertiser.gm), MAX(advertiser.nbs)) as gm,		
        SUM(IF(campaign.goal in ('OPTIMIZE_CPA_FOR_APP_RE', 'OPTIMIZE_REATTRIBUTION_FOR_APP', 'OPTIMIZE_ROAS_FOR_APP_RE', 'OPTIMIZE_CPC_FOR_APP_RE'),gross_spend_usd, 0)) as RE_spend,		
        SUM(IF(campaign.goal in ('OPTIMIZE_CPA_FOR_APP_RE', 'OPTIMIZE_REATTRIBUTION_FOR_APP', 'OPTIMIZE_ROAS_FOR_APP_RE', 'OPTIMIZE_CPC_FOR_APP_RE'), 0, gross_spend_usd)) as nonRE_spend,		
        SUM(gross_spend_usd) as total_spend		
    FROM		
    `ads-bpd-guard-china.athena.fact_dsp_core`		
    WHERE		
        date_utc BETWEEN start_date and end_date	
        AND lower(campaign.os) = 'android'
        AND gross_spend_usd > 0		
    GROUP BY ALL
),

--need to pull all historical bundles ever existed because bundles may not show up in fact_dsp_core if they have no spend (e.g. Credit Karma IOS is missing, but it is a large RE opportunity). Selects most recent entry per bundle	
all_bundles AS (	
    SELECT * except(rn) FROM (	
    SELECT	
        platform as platform_id,	
        os,	
        app_store_bundle as app_market_bundle,	
        ROW_NUMBER() OVER(partition by app_store_bundle order by timestamp desc) as rn	
    FROM `focal-elf-631.standard_digest.product_digest`	
    )	
    where rn = 1	
    and lower(os) = 'android'
    GROUP BY ALL	
),

--combine all bundles with the fact_dsp_core pull			
mlc_all AS (			
    SELECT			
    COALESCE(advertiser_activity.platform_id, all_bundles.platform_id) as platform_id,			
    all_bundles.app_market_bundle,			
    all_bundles.os,			
    office_region,			
    growth_pod,			
    gm,			
    RE_spend,			
    nonRE_spend,			
    total_spend	
FROM			
    all_bundles			
LEFT JOIN			
        advertiser_activity			
USING			
(app_market_bundle, os)			
),

app_users AS (			
    SELECT			
        app_market_bundle,			
        os,			
        SUM(monthly.downloads) as installed_users			
    FROM			
       `ads-bpd-guard-china.athena.fact_app_v2`			
    WHERE			
        date_utc between '2020-07-01' and end_date	
        AND app_market_bundle IS NOT NULL		
        AND lower(os) = 'android'
    GROUP BY ALL			
),

final as (					
    SELECT					
        COALESCE(platform_id, 'NON-MOLOCO') as platform_id,					
        app_market_bundle,					
        os,					
        office_region,					
        growth_pod,					
        gm,					
        RE_spend,					
        nonRE_spend,					
        total_spend,					
        installed_users,					
        installed_users * rev_per_user as total_opp_monthly					
    FROM					
       mlc_all					
        FULL OUTER JOIN					
       app_users					
        USING					
        (app_market_bundle, os)					
    WHERE					
        installed_users > min_audience_size					
    ORDER BY					
       total_opp_monthly DESC					
)					
					
SELECT					
    app_market_bundle,					
    os,					
    platform_id,					
    office_region,					
    growth_pod,					
    gm,					
    RE_spend,					
    nonRE_spend,					
    total_spend,					
    installed_users,					
    installed_users * rev_per_user as RE_opp_daily					
FROM					
    final					
order by 11 desc

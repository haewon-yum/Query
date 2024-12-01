MERGE `moloco-dsp-data-source.standard_report_v1.report_final_skan` T -- noqa: disable=CP02
USING (
WITH
  skan_scheme AS (
    SELECT
      app_id,
      items.date AS effective_date,
      conversions
    FROM
      `focal-elf-631.standard_digest.skan_conversion_scheme`, UNNEST(items) AS items, UNNEST(items.conversions) AS conversions
  ),

  gen_date_array AS (
    SELECT
      DATE(date_array) AS date
    FROM
      UNNEST(GENERATE_DATE_ARRAY(DATE(data_interval_start), DATE(data_interval_end))) AS date_array
  ),

  dated_skan_scheme AS (
    SELECT
      * EXCEPT(idx)
    FROM (
      SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY app_id, conversions.id, IFNULL(conversions.postback_sequence_index, '0'), date ORDER BY effective_date DESC) AS idx
      FROM (
        SELECT
          *
        FROM
          skan_scheme
        JOIN
          gen_date_array
        ON
          effective_date <= date
      )
    )
    WHERE
      idx = 1
  ),

  dated_skan_scheme_flattened as (
    SELECT
      app_id,
      date,
      conversions.id as SKAN_ConversionValue,
      SAFE_CAST(conversions.postback_sequence_index AS INT64) AS SKAN_PostbackSequenceIndex,
      0 as SKAN_ConversionCount,
      events.name as SKAN_ConversionEvent,
      CAST(events.revenue_interval.start AS NUMERIC) as SKAN_ConversionEventRevenueMin,
      CAST(events.revenue_interval.end AS NUMERIC) as SKAN_ConversionEventRevenueMax
    FROM
      dated_skan_scheme, UNNEST(conversions.events) events
  ),

  # Because of SKAN, we need to split digest subquery into two, the one with platform, advertiser, product, and campaign
  # and the other with lower level entities.
  master_digest AS (
    SELECT
      Platform,
      Advertiser_ID,
      Product_ID,
      Product_StoreID,
      Product_OS,
      Campaign_ID,
    FROM (
      SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY Platform, Advertiser_ID, Campaign_ID ORDER BY Version DESC) AS idx
      FROM
        `moloco-dsp-data-view.standard_report_v1.report_digest_master`
    )
    WHERE
      idx = 1
    GROUP BY
      Platform, Advertiser_ID,
      Product_ID, Product_OS, Product_StoreID, Campaign_ID
  ),

  summary AS (
    SELECT
      time_bucket AS Time_Bucket,
      platform AS Platform,
      advertiser AS Advertiser_ID,
      campaign AS Campaign_ID,
      ad_group AS AdGroup_ID,
      cr_group AS CreativeGroup_ID,
      attribution_type AS Attribution_Type,
      SUM(impressions) AS Impressions,
      SUM(clicks) AS Clicks,
      SUM(installs) AS Installs,
      SUM(spend) AS Spend,
      SUM(sum_pb_revenue_adv) AS Revenue,
      conversion_event AS Conversion_Event,
      SUM(conversion_count) AS Conversion_Count,
      SUM(conversion_revenue) AS Conversion_Revenue,
      is_lat AS Traffic_LAT,
      is_skan_req AS Traffic_SKANReq,
      is_skan_bid AS Traffic_SKANBid,
      is_mmp_effective AS Traffic_MMPEffective,
      skan_cv_val AS SKAN_ConversionValue,
      SUM(skan_cv_count) AS SKAN_ConversionCount,
      skan_campaign_id AS SKAN_CampaignID,
      skan_campaign_tr_suffix AS SKAN_CampaignTrSuffix,
      skan_cv_version AS SKAN_Version,
      skan_cv_fidelity_type AS SKAN_Fidelity_Type,
      skan_cv_did_win AS SKAN_DidWin,
      skan_cv_source_identifier AS SKAN_SourceIdentifier,
      skan_cv_coarse_conversion_value AS SKAN_CoarseConversionValue,
      skan_cv_postback_sequence_index AS SKAN_PostbackSequenceIndex,
      skan_cv_redownload AS SKAN_Redownload,
    FROM
      `moloco-dsp-data-view.standard_report_v1.summary`
    GROUP BY
      Time_Bucket, Platform, Advertiser_ID, Campaign_ID, AdGroup_ID, CreativeGroup_ID,
      Attribution_Type, Conversion_Event, Traffic_LAT, Traffic_SKANReq, Traffic_SKANBid, Traffic_MMPEffective,
      SKAN_ConversionValue, SKAN_CampaignID, SKAN_CampaignTrSuffix, SKAN_Version, SKAN_Fidelity_Type, SKAN_DidWin,
      SKAN_SourceIdentifier, SKAN_CoarseConversionValue, SKAN_PostbackSequenceIndex, SKAN_Redownload
  ),

  report_enriched AS (
    SELECT
      Time_Bucket,
      Platform,
      Advertiser_ID,
      Product_ID,
      Product_StoreID,
      Campaign_ID,
      AdGroup_ID,
      CreativeGroup_ID,
      Attribution_Type,
      SUM(Impressions) AS Impressions,
      SUM(Clicks) AS Clicks,
      SUM(Installs) AS Installs,
      SUM(Spend) AS Spend,
      SUM(Revenue) AS Revenue,
      Conversion_Event,
      SUM(Conversion_Count) AS Conversion_Count,
      SUM(Conversion_Revenue) AS Conversion_Revenue,
      Traffic_LAT,
      Traffic_SKANReq,
      Traffic_SKANBid,
      Traffic_MMPEffective,
      SKAN_ConversionValue,
      SUM(SKAN_ConversionCount) AS SKAN_ConversionCount,
      SKAN_CampaignID,
      SKAN_CampaignTrSuffix,
      SKAN_Version,
      SKAN_Fidelity_Type,
      SKAN_DidWin,
      SKAN_SourceIdentifier,
      SKAN_CoarseConversionValue,
      SKAN_PostbackSequenceIndex,
      SKAN_Redownload,
    FROM
      summary
    LEFT JOIN
      master_digest
    USING
      (Platform, Advertiser_ID, Campaign_ID)
    WHERE
      data_interval_start <= time_bucket AND time_bucket < data_interval_end
      AND IF(get_platforms, platform IN UNNEST(SPLIT(platform_list, ",")), TRUE)
      AND Product_OS = 'IOS'
    GROUP BY
      Time_Bucket, Platform, Advertiser_ID, Product_ID, Product_StoreID, Campaign_ID, AdGroup_ID, CreativeGroup_ID,
      Attribution_Type, Conversion_Event, Traffic_LAT, Traffic_SKANReq, Traffic_SKANBid, Traffic_MMPEffective,
      SKAN_ConversionValue, SKAN_CampaignID, SKAN_CampaignTrSuffix, SKAN_Version, SKAN_Fidelity_Type, SKAN_DidWin,
      SKAN_SourceIdentifier, SKAN_CoarseConversionValue, SKAN_PostbackSequenceIndex, SKAN_Redownload
  ),

  report_skan_scheme_extended AS (
    SELECT
      r.*,
      s.SKAN_ConversionEvent,
      s.SKAN_ConversionEventRevenueMin,
      s.SKAN_ConversionEventRevenueMax
    FROM
      report_enriched r
    LEFT JOIN
      dated_skan_scheme_flattened s
    ON
      r.Product_StoreID = s.app_id
      AND (
        ( # Fine-grained conversions JOIN condition
          r.SKAN_ConversionValue IS NOT NULL
          AND r.SKAN_ConversionValue = SAFE_CAST(s.SKAN_ConversionValue AS INT64)
        ) OR
        ( # Coarse conversions JOIN condition
          r.SKAN_CoarseConversionValue IS NOT NULL
          AND r.SKAN_CoarseConversionValue = s.SKAN_ConversionValue
        )
      )
      AND IFNULL(r.SKAN_PostbackSequenceIndex,0) = IFNULL(s.SKAN_PostbackSequenceIndex,0)
      AND DATE(r.Time_Bucket) = s.date
    WHERE
      s.SKAN_ConversionEvent IS NOT NULL
  )

  SELECT
    Time_Bucket, Platform, Advertiser_ID, Product_ID, Campaign_ID, AdGroup_ID, CreativeGroup_ID, Attribution_Type,
    Impressions, Clicks, Installs, Spend, Revenue,
    Conversion_Event, Conversion_Count, Conversion_Revenue, Traffic_LAT, Traffic_SKANReq, Traffic_SKANBid,
    Traffic_MMPEffective, SKAN_ConversionValue, SKAN_ConversionCount, SKAN_CampaignID, SKAN_CampaignTrSuffix,
    NULL AS SKAN_ConversionEvent, 0 AS SKAN_ConversionEventCount, SKAN_Version, SKAN_Fidelity_Type,
    NULL AS SKAN_ConversionEventRevenueMinSum,
    NULL AS SKAN_ConversionEventRevenueMaxSum,
    SKAN_DidWin, SKAN_SourceIdentifier, SKAN_CoarseConversionValue, SKAN_PostbackSequenceIndex, SKAN_Redownload,
  FROM
    report_enriched
  UNION ALL
  SELECT
    Time_Bucket, Platform, Advertiser_ID, Product_ID, Campaign_ID, AdGroup_ID, CreativeGroup_ID, Attribution_Type,
    0 AS Impressions, 0 AS Clicks, 0 AS Installs, 0 AS Spend, 0 AS Revenue,
    "" AS Conversion_Event, 0 AS Conversion_Count, 0 AS Conversion_Revenue, Traffic_LAT, Traffic_SKANReq, Traffic_SKANBid,
    Traffic_MMPEffective, SKAN_ConversionValue, 0 AS SKAN_ConversionCount, SKAN_CampaignID, SKAN_CampaignTrSuffix,
    SKAN_ConversionEvent, SKAN_ConversionCount AS SKAN_ConversionEventCount, SKAN_Version, SKAN_Fidelity_Type,
    SKAN_ConversionEventRevenueMin * SKAN_ConversionCount AS SKAN_ConversionEventRevenueMinSum,
    SKAN_ConversionEventRevenueMax * SKAN_ConversionCount AS SKAN_ConversionEventRevenueMaxSum,
    SKAN_DidWin, SKAN_SourceIdentifier, SKAN_CoarseConversionValue, SKAN_PostbackSequenceIndex, SKAN_Redownload,
  FROM
    report_skan_scheme_extended
) S

ON FALSE
WHEN NOT MATCHED BY TARGET
  AND data_interval_start <= Time_Bucket AND Time_Bucket < data_interval_end
  AND IF(get_platforms, Platform IN UNNEST(SPLIT(platform_list, ",")), TRUE)
THEN INSERT (Time_Bucket, Platform, Advertiser_ID, Product_ID, Campaign_ID, AdGroup_ID, Attribution_Type,
             Impressions, Clicks, Installs, Spend, Revenue, Conversion_Event, Conversion_Count,
             Conversion_Revenue, Traffic_LAT, Traffic_SKANReq, Traffic_SKANBid, Traffic_MMPEffective, SKAN_ConversionValue,
             SKAN_ConversionCount, SKAN_CampaignID, SKAN_CampaignTrSuffix, SKAN_ConversionEvent, SKAN_ConversionEventCount,
             SKAN_Version, SKAN_Fidelity_Type, SKAN_ConversionEventRevenueMinSum, SKAN_ConversionEventRevenueMaxSum,
             SKAN_DidWin, SKAN_SourceIdentifier, SKAN_CoarseConversionValue, SKAN_PostbackSequenceIndex, SKAN_Redownload, CreativeGroup_ID)
  VALUES (Time_Bucket, Platform, Advertiser_ID, Product_ID, Campaign_ID, AdGroup_ID, Attribution_Type,
          Impressions, Clicks, Installs, Spend, Revenue, Conversion_Event, Conversion_Count,
          Conversion_Revenue, Traffic_LAT, Traffic_SKANReq, Traffic_SKANBid, Traffic_MMPEffective, SKAN_ConversionValue,
          SKAN_ConversionCount, SKAN_CampaignID, SKAN_CampaignTrSuffix, SKAN_ConversionEvent, SKAN_ConversionEventCount,
          SKAN_Version, SKAN_Fidelity_Type, SKAN_ConversionEventRevenueMinSum, SKAN_ConversionEventRevenueMaxSum,
          SKAN_DidWin, SKAN_SourceIdentifier, SKAN_CoarseConversionValue, SKAN_PostbackSequenceIndex, SKAN_Redownload, CreativeGroup_ID)
WHEN NOT MATCHED BY SOURCE
  AND data_interval_start <= Time_Bucket AND Time_Bucket < data_interval_end
  AND IF(get_platforms, Platform IN UNNEST(SPLIT(platform_list, ",")), TRUE)
THEN DELETE
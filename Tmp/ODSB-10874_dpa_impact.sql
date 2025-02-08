-- 2025-02-06 20:00 - 23:30 UTC. 

DECLARE run_from_date DATE DEFAULT "2025-02-06";
DECLARE run_to_date DATE DEFAULT "2025-02-06";
DECLARE advertisers ARRAY<STRING> DEFAULT ['CLPQ2epYqtnnNprD',
          'T7eVdFNdQmaj6bxV',        
          'Voql38wJkmDNzXbW',
          'HKRCcBXgyO9rR9Pb',
          'LkoNjQc1uaLF5Nwf',
          'ynSMKtlu8XyysHtn',
          'BpqrQRzCKeaGyK9w',
          'n4dhNAdPjtkbmLwg',
          'cd2AC5v9ZYTi9ub7' ,         
          'xZwI3qNlo2bSavEw',
          'ymOEhlk0yVV9wHmB',
          'ipNfkW3cSMatrRN5',
          'JJlknKfqvH942sFD',
          'h4khOQuVmBR7OV2S',
          'MujETNlgRwXL7G4Y',
          'NLjd7UEHkMMjZpK5'   ];
DECLARE products ARRAY<STRING> DEFAULT [
  'NQ7JMzyQuPmJp33f',
  'dVxRyuGyxJ6Cy9hK',
  'TniZmVCGHyLtIzpe',
  'fFuMx1cIa5ACsThy',
  'ZN0DxL6RE3Y2XyW2',
  'FSuhhIBZsetuzoYH',
  'twyr0Kpb13Foa47B',
  'CZ1GC81t8W7vWcmA',
  'm1252V4NxEPl8lcy',
  'ok1cQYXajayEgf1P',
  'gNms0z0LZr4chfac',
  'QnvcRbMpW6XabgtJ',
  'FK0ZzWfKMbuY9CK5',
  'SaIywnULt6wrtIwd',
  'J30NdKKPKw2wZ9C5',
  'RbTykUmynTjHYLYu',
  'Cpnzh8NOZYhVJbGi',
  'iATdDPB1agfzLeqW',
  'GfReHruwsTRszgRL',
  'oidTQzPBwFgpdgUU'
];


WITH
  advertiser AS (
    SELECT
      *,
      COALESCE(DATE_SUB(LAG(effective_date_local) OVER(PARTITION BY platform_id, advertiser_id ORDER BY effective_date_local DESC), INTERVAL 1 DAY), run_to_date) AS last_effective_date_local,
    FROM
    (
      SELECT
        DISTINCT
        effective_date_local,
        platform.id AS platform_id,
        advertiser.id AS advertiser_id,
        advertiser.timezone AS advertiser_timezone,
        platform.serving_cost_percent AS platform_serving_cost_percent,
        platform.contract_markup_percent AS platform_markup_percent
      FROM
        `moloco-dsp-data-source.costbook.costbook`
      WHERE
      --   campaign.country = 'KOR'
      -- AND
        advertiser.id IN UNNEST(advertisers)
      AND
        DATE_DIFF(run_to_date, effective_date_local, DAY) >=0
    )
  )
,
  advertiser_timezone AS (
    SELECT
      DISTINCT
      platform_id,
      advertiser_id,
      advertiser_timezone
    FROM
      advertiser
  ),

  imp_t AS (
    SELECT
      I.platform_id,
      I.advertiser_id,
      I.api.product.id AS product_id,
      DATE(I.timestamp, A.advertiser_timezone) AS local_date,
      A.platform_serving_cost_percent,
      A.platform_markup_percent,
      SUM(I.imp.win_price_usd.amount_micro / 1e6) AS win_price_usd,
      COUNT(*) AS imp,
    FROM
      `focal-elf-631.prod_stream_view.imp` AS I
    INNER JOIN
      advertiser AS A
    ON I.platform_id=A.platform_id
      AND I.advertiser_id=A.advertiser_id
      AND A.effective_date_local<=DATE(I.timestamp, A.advertiser_timezone)
      AND DATE(I.timestamp, A.advertiser_timezone)<=A.last_effective_date_local
    WHERE
      I.timestamp BETWEEN TIMESTAMP '2025-02-06 20:00:00 UTC' AND TIMESTAMP '2025-02-06 23:30:00 UTC'
      AND I.api.advertiser.id IN UNNEST(advertisers)
      AND I.api.product.id IN UNNEST(products)
      AND I.api.creative.cr_format in ("di", "db")
    GROUP BY ALL
  )

SELECT
  I.platform_id,
  I.advertiser_id,
  I.product_id,
  -- I.local_date,
  SAFE_CAST(SUM(I.win_price_usd * (1 + I.platform_serving_cost_percent/100) * (1 + I.platform_markup_percent/100)) AS FLOAT64) AS gross_spending_usd,
  SUM(I.imp) AS imp,
FROM
  imp_t AS I
GROUP BY ALL


SELECT
  req.device.os,
  req.device.geo.country,
  api.product.app.store_id AS store_bundle,
  COUNT(1) AS purchase
FROM
  `focal-elf-631.prod_stream_view.cv`
WHERE
  timestamp BETWEEN '{start_date}'
  AND '{end_date}'
  AND api.product.app.store_id IN ({store_bundle})
  AND cv.revenue_usd.amount > 0
GROUP BY
  ALL

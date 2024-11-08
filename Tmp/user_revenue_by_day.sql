# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL
SELECT
  bid.maid AS user_id,
  req.device.os,
  req.device.geo.country,
  TIMESTAMP_DIFF(cv.happened_at, cv.install_at_pb, DAY) + 1 AS diff_day,
  cv.revenue_usd.amount AS revenue
FROM
  `focal-elf-631.prod_stream_view.cv`
WHERE
  TIMESTAMP >= '{start_date}'
  AND cv.install_at_pb BETWEEN '{start_date}' AND '{end_date}'
  AND api.product.app.store_id IN ({store_bundle})
  AND cv.revenue_usd.amount > 0
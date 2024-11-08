WITH
    trace_hour AS (
    SELECT
      bid_trace_id,
      exchange,
      inventory_format,
      country,
      os,
      raw_json,
      timestamp,
      rate
    FROM
      `focal-elf-631.prod.trace20*`
    WHERE
      _table_suffix BETWEEN FORMAT_TIMESTAMP("%y%m%d", target_datestamp)
      AND FORMAT_TIMESTAMP("%y%m%d", TIMESTAMP_ADD(target_datestamp, INTERVAL 1 DAY))
      AND DATE(timestamp) = target_datestamp
      AND EXTRACT(HOUR FROM timestamp) = target_hour
      AND json_query(raw_json,
        '$.trace_logs') IS NOT NULL ),
    
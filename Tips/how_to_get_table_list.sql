SELECT
  table_id,
  row_count,
  size_bytes,
  TIMESTAMP_MILLIS(creation_time) AS created_at,
  TIMESTAMP_MILLIS(last_modified_time) AS last_modified_time
FROM
  `moloco-ods.haewon.__TABLES__`
ORDER BY
  creation_time DESC;



# Get query for dropping result tables

SELECT
  CONCAT('DROP TABLE `moloco-ods.haewon.', table_id, '`;') AS drop_statement
FROM
  `moloco-ods.haewon.__TABLES__`
WHERE
  row_count = 0
ORDER BY
  creation_time DESC;

SELECT
  table_id,
  row_count,
  size_bytes,
  TIMESTAMP_MILLIS(creation_time) AS created_at,
  TIMESTAMP_MILLIS(last_modified_time) AS last_modified_time
FROM
  `moloco-ods.haewon.__TABLES__`
WHERE
  DATE(TIMESTAMP_MILLIS(last_modified_time)) < DATE '2025-01-01'
ORDER BY
  creation_time DESC;

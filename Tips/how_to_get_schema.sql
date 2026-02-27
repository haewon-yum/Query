SELECT
  column_name,
  data_type,
  is_nullable,
  -- description
FROM
  `focal-elf-631.user_data_v2_avro.INFORMATION_SCHEMA.COLUMNS`
WHERE
  table_name = 'lifetime_summary_latest';


SELECT
  column_name,
  data_type,
  is_nullable,
  -- description
FROM
  `focal-elf-631.user_data_v2_avro.INFORMATION_SCHEMA.COLUMNS`
WHERE
  table_name = 'pb_raw_latest';


focal-elf-631.prod.bidrequest

SELECT
  column_name,
  data_type,
  is_nullable,
  -- description
FROM
  `focal-elf-631.prod.INFORMATION_SCHEMA.COLUMNS`
WHERE
  table_name = 'bidrequest';
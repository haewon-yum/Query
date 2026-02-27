SELECT
  SUBSTR(maid, 0, 1),
  Count(1)
FROM
  `focal-elf-631.user_data_v2_avro.lat_pb_raw_latest`;
WHERE app_bundle IN ('com.supercell.brawlstars','id1229016807','id1504236603')
GROUP BY 1
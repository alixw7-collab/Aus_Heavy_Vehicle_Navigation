SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'hvn'
  AND table_name = 'road_rule_source'
ORDER BY ordinal_position;
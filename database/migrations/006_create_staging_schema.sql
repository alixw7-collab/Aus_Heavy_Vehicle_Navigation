CREATE SCHEMA IF NOT EXISTS staging;

SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN ('hvn', 'staging');
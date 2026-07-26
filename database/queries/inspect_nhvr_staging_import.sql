-- Project RoadTrain
-- Inspect raw NHVR B-double staging import

-- 1. Confirm table exists
SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'staging'
  AND table_name = 'nhvr_qld_26m_bdouble_raw';


-- 2. List all imported columns
SELECT
    ordinal_position,
    column_name,
    data_type,
    udt_name,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'staging'
  AND table_name = 'nhvr_qld_26m_bdouble_raw'
ORDER BY ordinal_position;


-- 3. Count imported features
SELECT COUNT(*) AS feature_count
FROM staging.nhvr_qld_26m_bdouble_raw;


-- 4. Identify geometry metadata
SELECT
    f_table_schema,
    f_table_name,
    f_geometry_column,
    coord_dimension,
    srid,
    type
FROM geometry_columns
WHERE f_table_schema = 'staging'
  AND f_table_name = 'nhvr_qld_26m_bdouble_raw';


-- 5. Check for null geometries
SELECT COUNT(*) AS null_geometry_count
FROM staging.nhvr_qld_26m_bdouble_raw
WHERE geom IS NULL;


-- 6. Check geometry types
SELECT
    ST_GeometryType(geom) AS geometry_type,
    COUNT(*) AS feature_count
FROM staging.nhvr_qld_26m_bdouble_raw
WHERE geom IS NOT NULL
GROUP BY ST_GeometryType(geom)
ORDER BY geometry_type;


-- 7. Check geometry validity
SELECT
    ST_IsValid(geom) AS is_valid,
    COUNT(*) AS feature_count
FROM staging.nhvr_qld_26m_bdouble_raw
WHERE geom IS NOT NULL
GROUP BY ST_IsValid(geom);


-- 8. Display coordinate reference system
SELECT DISTINCT
    ST_SRID(geom) AS srid
FROM staging.nhvr_qld_26m_bdouble_raw
WHERE geom IS NOT NULL;


-- 9. Display dataset extent
SELECT
    ST_Extent(geom) AS dataset_extent
FROM staging.nhvr_qld_26m_bdouble_raw;


-- 10. Display sample records
SELECT *
FROM staging.nhvr_qld_26m_bdouble_raw
LIMIT 10;
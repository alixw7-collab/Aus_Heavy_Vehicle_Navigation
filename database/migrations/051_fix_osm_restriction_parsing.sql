/*
===============================================================================
Migration: 051_fix_osm_restriction_parsing.sql

Purpose:
    Correct decimal parsing in physical OSM restriction values populated by
    migration 050_heavy_vehicle_attributes.sql.

Problem:
    PostgreSQL SUBSTRING returned the first parenthesised capture group.
    For example, 4.3 was parsed as .3 instead of 4.3.

Affected columns:
    - max_height_m
    - max_width_m
    - max_length_m
    - max_weight_t
===============================================================================
*/

BEGIN;


-------------------------------------------------------------------------------
-- 1. Correct length parser
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hvn.parse_osm_length_m(
    raw_value TEXT
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
    cleaned_value TEXT;
    numeric_text TEXT;
    numeric_value NUMERIC;
BEGIN
    IF raw_value IS NULL OR BTRIM(raw_value) = '' THEN
        RETURN NULL;
    END IF;

    cleaned_value := LOWER(BTRIM(SPLIT_PART(raw_value, ';', 1)));
    cleaned_value := REPLACE(cleaned_value, ',', '.');

    IF cleaned_value IN (
        'none',
        'default',
        'unsigned',
        'unknown',
        'unlimited',
        'variable'
    ) THEN
        RETURN NULL;
    END IF;

    /*
     * Capture the complete numeric component as group 1.
     */
    numeric_text :=
        (REGEXP_MATCH(
            cleaned_value,
            '^([0-9]+([.][0-9]+)?)'
        ))[1];

    IF numeric_text IS NULL THEN
        RETURN NULL;
    END IF;

    numeric_value := numeric_text::NUMERIC;

    /*
     * No unit in an OSM physical dimension is interpreted as metres.
     */
    IF cleaned_value ~
        '^[0-9]+([.][0-9]+)?[[:space:]]*(m|metre|metres|meter|meters)?$'
    THEN
        RETURN numeric_value;
    END IF;

    IF cleaned_value ~
        '^[0-9]+([.][0-9]+)?[[:space:]]*(cm|centimetre|centimetres|centimeter|centimeters)$'
    THEN
        RETURN numeric_value / 100.0;
    END IF;

    IF cleaned_value ~
        '^[0-9]+([.][0-9]+)?[[:space:]]*(mm|millimetre|millimetres|millimeter|millimeters)$'
    THEN
        RETURN numeric_value / 1000.0;
    END IF;

    IF cleaned_value ~
        '^[0-9]+([.][0-9]+)?[[:space:]]*(ft|foot|feet)$'
    THEN
        RETURN numeric_value * 0.3048;
    END IF;

    IF cleaned_value ~
        '^[0-9]+([.][0-9]+)?[[:space:]]*(in|inch|inches)$'
    THEN
        RETURN numeric_value * 0.0254;
    END IF;

    RETURN NULL;
END;
$$;


-------------------------------------------------------------------------------
-- 2. Correct weight parser
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hvn.parse_osm_weight_t(
    raw_value TEXT
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
    cleaned_value TEXT;
    numeric_text TEXT;
    numeric_value NUMERIC;
BEGIN
    IF raw_value IS NULL OR BTRIM(raw_value) = '' THEN
        RETURN NULL;
    END IF;

    cleaned_value := LOWER(BTRIM(SPLIT_PART(raw_value, ';', 1)));
    cleaned_value := REPLACE(cleaned_value, ',', '.');

    IF cleaned_value IN (
        'none',
        'default',
        'unsigned',
        'unknown',
        'unlimited',
        'variable'
    ) THEN
        RETURN NULL;
    END IF;

    numeric_text :=
        (REGEXP_MATCH(
            cleaned_value,
            '^([0-9]+([.][0-9]+)?)'
        ))[1];

    IF numeric_text IS NULL THEN
        RETURN NULL;
    END IF;

    numeric_value := numeric_text::NUMERIC;

    /*
     * OSM maxweight values without a unit are metric tonnes.
     */
    IF cleaned_value ~
        '^[0-9]+([.][0-9]+)?[[:space:]]*(t|tonne|tonnes|ton|tons)?$'
    THEN
        RETURN numeric_value;
    END IF;

    IF cleaned_value ~
        '^[0-9]+([.][0-9]+)?[[:space:]]*(kg|kilogram|kilograms)$'
    THEN
        RETURN numeric_value / 1000.0;
    END IF;

    RETURN NULL;
END;
$$;


-------------------------------------------------------------------------------
-- 3. Repopulate only the affected physical restriction columns
-------------------------------------------------------------------------------

UPDATE hvn.routing_edge AS edge
SET
    max_height_m =
        hvn.parse_osm_length_m(segment.maxheight),

    max_width_m =
        hvn.parse_osm_length_m(segment.maxwidth),

    max_length_m =
        hvn.parse_osm_length_m(segment.maxlength),

    max_weight_t =
        hvn.parse_osm_weight_t(segment.maxweight),

    attributes_updated_at = CURRENT_TIMESTAMP

FROM staging.osm_road_segment AS segment
WHERE segment.source_way_id = edge.source_way_id
  AND segment.source_segment_number = edge.source_segment_number
  AND (
        segment.maxheight IS NOT NULL
     OR segment.maxwidth IS NOT NULL
     OR segment.maxlength IS NOT NULL
     OR segment.maxweight IS NOT NULL
  );


-------------------------------------------------------------------------------
-- 4. Remove implausible results
-------------------------------------------------------------------------------

UPDATE hvn.routing_edge
SET max_height_m = NULL
WHERE max_height_m <= 0
   OR max_height_m > 20;

UPDATE hvn.routing_edge
SET max_width_m = NULL
WHERE max_width_m <= 0
   OR max_width_m > 20;

UPDATE hvn.routing_edge
SET max_length_m = NULL
WHERE max_length_m <= 0
   OR max_length_m > 200;

UPDATE hvn.routing_edge
SET max_weight_t = NULL
WHERE max_weight_t <= 0
   OR max_weight_t > 1000;


-------------------------------------------------------------------------------
-- 5. Refresh statistics
-------------------------------------------------------------------------------

ANALYZE hvn.routing_edge (
    max_height_m,
    max_width_m,
    max_length_m,
    max_weight_t
);

COMMIT;
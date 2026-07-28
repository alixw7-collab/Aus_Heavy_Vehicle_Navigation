/*
===============================================================================
Migration: 050_heavy_vehicle_attributes.sql

Purpose:
    Add typed heavy-vehicle restrictions and road characteristics to
    hvn.routing_edge.

Design notes:
    - Missing access data is stored as NULL, meaning unknown.
    - FALSE means an explicit prohibition was found.
    - TRUE means explicit permission was found.
    - Existing speed_kmh and travel_time_seconds columns are retained.
    - Raw source values remain available through source_tags and the staging
      tables.

Dependencies:
    - staging.osm_road_segment
    - hvn.routing_edge

===============================================================================
*/

BEGIN;

-------------------------------------------------------------------------------
-- 1. Reusable parsing functions
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
    numeric_value NUMERIC;
BEGIN
    IF raw_value IS NULL OR BTRIM(raw_value) = '' THEN
        RETURN NULL;
    END IF;

    /*
     * Where multiple values exist, use the first value only.
     * Examples:
     *     4.3;4.5
     *     4.3 m
     *     430 cm
     */
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

    IF cleaned_value ~ '^[0-9]+([.][0-9]+)?[[:space:]]*(m|metre|metres|meter|meters)?$' THEN
        numeric_value :=
            SUBSTRING(cleaned_value FROM '[0-9]+([.][0-9]+)?')::NUMERIC;

        RETURN numeric_value;
    END IF;

    IF cleaned_value ~ '^[0-9]+([.][0-9]+)?[[:space:]]*(cm|centimetre|centimetres|centimeter|centimeters)$' THEN
        numeric_value :=
            SUBSTRING(cleaned_value FROM '[0-9]+([.][0-9]+)?')::NUMERIC;

        RETURN numeric_value / 100.0;
    END IF;

    IF cleaned_value ~ '^[0-9]+([.][0-9]+)?[[:space:]]*(mm|millimetre|millimetres|millimeter|millimeters)$' THEN
        numeric_value :=
            SUBSTRING(cleaned_value FROM '[0-9]+([.][0-9]+)?')::NUMERIC;

        RETURN numeric_value / 1000.0;
    END IF;

    IF cleaned_value ~ '^[0-9]+([.][0-9]+)?[[:space:]]*(ft|foot|feet)$' THEN
        numeric_value :=
            SUBSTRING(cleaned_value FROM '[0-9]+([.][0-9]+)?')::NUMERIC;

        RETURN numeric_value * 0.3048;
    END IF;

    IF cleaned_value ~ '^[0-9]+([.][0-9]+)?[[:space:]]*(in|inch|inches)$' THEN
        numeric_value :=
            SUBSTRING(cleaned_value FROM '[0-9]+([.][0-9]+)?')::NUMERIC;

        RETURN numeric_value * 0.0254;
    END IF;

    /*
     * Do not guess when a value cannot be interpreted safely.
     */
    RETURN NULL;
END;
$$;


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
     * OSM maxweight values without a unit are expressed in metric tonnes.
     */
    IF cleaned_value ~ '^[0-9]+([.][0-9]+)?[[:space:]]*(t|tonne|tonnes|ton|tons)?$' THEN
        numeric_value :=
            SUBSTRING(cleaned_value FROM '[0-9]+([.][0-9]+)?')::NUMERIC;

        RETURN numeric_value;
    END IF;

    IF cleaned_value ~ '^[0-9]+([.][0-9]+)?[[:space:]]*(kg|kilogram|kilograms)$' THEN
        numeric_value :=
            SUBSTRING(cleaned_value FROM '[0-9]+([.][0-9]+)?')::NUMERIC;

        RETURN numeric_value / 1000.0;
    END IF;

    RETURN NULL;
END;
$$;


CREATE OR REPLACE FUNCTION hvn.parse_osm_smallint(
    raw_value TEXT
)
RETURNS SMALLINT
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
    cleaned_value TEXT;
    parsed_value INTEGER;
BEGIN
    IF raw_value IS NULL OR BTRIM(raw_value) = '' THEN
        RETURN NULL;
    END IF;

    cleaned_value := BTRIM(SPLIT_PART(raw_value, ';', 1));

    IF cleaned_value !~ '^[0-9]+$' THEN
        RETURN NULL;
    END IF;

    parsed_value := cleaned_value::INTEGER;

    IF parsed_value < 0 OR parsed_value > 32767 THEN
        RETURN NULL;
    END IF;

    RETURN parsed_value::SMALLINT;
END;
$$;


CREATE OR REPLACE FUNCTION hvn.parse_osm_access_allowed(
    raw_value TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
    cleaned_value TEXT;
BEGIN
    IF raw_value IS NULL OR BTRIM(raw_value) = '' THEN
        RETURN NULL;
    END IF;

    cleaned_value := LOWER(BTRIM(SPLIT_PART(raw_value, ';', 1)));

    IF cleaned_value IN (
        'yes',
        'designated',
        'permissive',
        'official'
    ) THEN
        RETURN TRUE;
    END IF;

    IF cleaned_value IN (
        'no',
        'private'
    ) THEN
        RETURN FALSE;
    END IF;

    /*
     * Values such as destination, delivery, customers, agricultural and
     * forestry require contextual or conditional evaluation. They remain
     * unknown at this stage rather than being treated as unrestricted access.
     */
    RETURN NULL;
END;
$$;


-------------------------------------------------------------------------------
-- 2. Add typed routing attributes
-------------------------------------------------------------------------------

ALTER TABLE hvn.routing_edge
    ADD COLUMN IF NOT EXISTS road_class TEXT,
    ADD COLUMN IF NOT EXISTS surface_type TEXT,
    ADD COLUMN IF NOT EXISTS lane_count SMALLINT,
    ADD COLUMN IF NOT EXISTS max_height_m NUMERIC(6, 3),
    ADD COLUMN IF NOT EXISTS max_width_m NUMERIC(6, 3),
    ADD COLUMN IF NOT EXISTS max_length_m NUMERIC(7, 3),
    ADD COLUMN IF NOT EXISTS max_weight_t NUMERIC(8, 3),
    ADD COLUMN IF NOT EXISTS motor_vehicle_allowed BOOLEAN,
    ADD COLUMN IF NOT EXISTS hgv_allowed BOOLEAN,
    ADD COLUMN IF NOT EXISTS hazmat_allowed BOOLEAN,
    ADD COLUMN IF NOT EXISTS is_bridge BOOLEAN,
    ADD COLUMN IF NOT EXISTS is_tunnel BOOLEAN,
    ADD COLUMN IF NOT EXISTS is_roundabout BOOLEAN,
    ADD COLUMN IF NOT EXISTS is_oneway BOOLEAN,
    ADD COLUMN IF NOT EXISTS attributes_updated_at TIMESTAMPTZ;


-------------------------------------------------------------------------------
-- 3. Populate attributes from the corresponding staging road segment
-------------------------------------------------------------------------------

UPDATE hvn.routing_edge AS edge
SET
    road_class =
        CASE
            WHEN segment.highway IS NULL
                OR BTRIM(segment.highway) = ''
            THEN NULL
            ELSE UPPER(BTRIM(segment.highway))
        END,

    surface_type =
        CASE
            WHEN segment.surface IS NULL
                OR BTRIM(segment.surface) = ''
            THEN NULL
            ELSE LOWER(BTRIM(segment.surface))
        END,

    lane_count =
        hvn.parse_osm_smallint(segment.lanes),

    max_height_m =
        hvn.parse_osm_length_m(segment.maxheight),

    max_width_m =
        hvn.parse_osm_length_m(segment.maxwidth),

    max_length_m =
        hvn.parse_osm_length_m(segment.maxlength),

    max_weight_t =
        hvn.parse_osm_weight_t(segment.maxweight),

    /*
     * A specific motor_vehicle tag takes precedence over the broader
     * access tag.
     */
    motor_vehicle_allowed =
        COALESCE(
            hvn.parse_osm_access_allowed(segment.motor_vehicle),
            hvn.parse_osm_access_allowed(segment.access)
        ),

    /*
     * Explicit HGV access takes precedence. A general motor-vehicle or access
     * prohibition is inherited only when no specific HGV value exists.
     */
    hgv_allowed =
        CASE
            WHEN hvn.parse_osm_access_allowed(segment.hgv) IS NOT NULL
            THEN hvn.parse_osm_access_allowed(segment.hgv)

            WHEN hvn.parse_osm_access_allowed(segment.motor_vehicle) = FALSE
            THEN FALSE

            WHEN hvn.parse_osm_access_allowed(segment.access) = FALSE
            THEN FALSE

            ELSE NULL
        END,

    /*
     * Hazmat remains NULL unless OSM contains an explicit yes/no decision.
     */
    hazmat_allowed =
        hvn.parse_osm_access_allowed(segment.hazmat),

    is_bridge =
        CASE
            WHEN segment.bridge IS NULL
                OR BTRIM(segment.bridge) = ''
                OR LOWER(BTRIM(segment.bridge)) IN ('no', 'false', '0')
            THEN FALSE
            ELSE TRUE
        END,

    is_tunnel =
        CASE
            WHEN segment.tunnel IS NULL
                OR BTRIM(segment.tunnel) = ''
                OR LOWER(BTRIM(segment.tunnel)) IN ('no', 'false', '0')
            THEN FALSE
            ELSE TRUE
        END,

    is_roundabout =
        LOWER(COALESCE(segment.junction, '')) IN (
            'roundabout',
            'circular'
        ),

    is_oneway =
        LOWER(COALESCE(edge.oneway, '')) IN (
            'yes',
            'true',
            '1',
            '-1',
            'forward',
            'reverse'
        ),

    attributes_updated_at = CURRENT_TIMESTAMP

FROM staging.osm_road_segment AS segment
WHERE segment.source_way_id = edge.source_way_id
  AND segment.source_segment_number = edge.source_segment_number;


-------------------------------------------------------------------------------
-- 4. Guard against implausible parsed measurements
--
-- These checks do not assert Australian legal limits. They only reject values
-- that are almost certainly malformed source data or unit-parsing errors.
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

UPDATE hvn.routing_edge
SET lane_count = NULL
WHERE lane_count <= 0
   OR lane_count > 50;


-------------------------------------------------------------------------------
-- 5. Column documentation
-------------------------------------------------------------------------------

COMMENT ON COLUMN hvn.routing_edge.road_class IS
    'Normalised uppercase OSM highway classification.';

COMMENT ON COLUMN hvn.routing_edge.surface_type IS
    'Normalised lowercase OSM surface value.';

COMMENT ON COLUMN hvn.routing_edge.max_height_m IS
    'Explicit maximum permitted height in metres; NULL means unknown.';

COMMENT ON COLUMN hvn.routing_edge.max_width_m IS
    'Explicit maximum permitted width in metres; NULL means unknown.';

COMMENT ON COLUMN hvn.routing_edge.max_length_m IS
    'Explicit maximum permitted vehicle or combination length in metres; NULL means unknown.';

COMMENT ON COLUMN hvn.routing_edge.max_weight_t IS
    'Explicit maximum permitted weight in metric tonnes; NULL means unknown.';

COMMENT ON COLUMN hvn.routing_edge.motor_vehicle_allowed IS
    'Explicit or inherited general motor-vehicle access decision; NULL means unknown or conditional.';

COMMENT ON COLUMN hvn.routing_edge.hgv_allowed IS
    'Heavy-goods-vehicle access decision; NULL means unknown or conditional.';

COMMENT ON COLUMN hvn.routing_edge.hazmat_allowed IS
    'Dangerous-goods access decision; NULL means unknown or conditional.';

COMMENT ON COLUMN hvn.routing_edge.attributes_updated_at IS
    'Time at which the typed routing attributes were most recently populated.';


-------------------------------------------------------------------------------
-- 6. Indexes
--
-- Restriction values are generally sparse, so partial indexes avoid indexing
-- millions of NULL values.
-------------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS routing_edge_road_class_idx
    ON hvn.routing_edge (road_class);

CREATE INDEX IF NOT EXISTS routing_edge_max_height_idx
    ON hvn.routing_edge (max_height_m)
    WHERE max_height_m IS NOT NULL;

CREATE INDEX IF NOT EXISTS routing_edge_max_width_idx
    ON hvn.routing_edge (max_width_m)
    WHERE max_width_m IS NOT NULL;

CREATE INDEX IF NOT EXISTS routing_edge_max_length_idx
    ON hvn.routing_edge (max_length_m)
    WHERE max_length_m IS NOT NULL;

CREATE INDEX IF NOT EXISTS routing_edge_max_weight_idx
    ON hvn.routing_edge (max_weight_t)
    WHERE max_weight_t IS NOT NULL;

CREATE INDEX IF NOT EXISTS routing_edge_hgv_prohibited_idx
    ON hvn.routing_edge (edge_id)
    WHERE hgv_allowed = FALSE;

CREATE INDEX IF NOT EXISTS routing_edge_hazmat_prohibited_idx
    ON hvn.routing_edge (edge_id)
    WHERE hazmat_allowed = FALSE;


-------------------------------------------------------------------------------
-- 7. Refresh PostgreSQL statistics
-------------------------------------------------------------------------------

ANALYZE hvn.routing_edge;

COMMIT;

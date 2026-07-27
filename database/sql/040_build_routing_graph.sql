BEGIN;

CREATE SCHEMA IF NOT EXISTS hvn;

-- ============================================================
-- Remove previously generated routing tables
-- ============================================================

DROP TABLE IF EXISTS hvn.routing_edge;
DROP TABLE IF EXISTS hvn.routing_node;

-- ============================================================
-- Routing nodes
--
-- Every unique segment endpoint becomes one routing node.
-- Coordinates remain in EPSG:4326.
-- ============================================================

CREATE TABLE hvn.routing_node
(
    node_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    longitude     double precision NOT NULL,
    latitude      double precision NOT NULL,
    geom          geometry(Point, 4326) NOT NULL,

    CONSTRAINT routing_node_coordinate_unique
        UNIQUE (longitude, latitude)
);

WITH endpoints AS
(
    SELECT
        ST_X(ST_StartPoint(segment.geom)) AS longitude,
        ST_Y(ST_StartPoint(segment.geom)) AS latitude,
        ST_StartPoint(segment.geom)::geometry(Point, 4326) AS geom
    FROM staging.osm_road_segment AS segment

    UNION

    SELECT
        ST_X(ST_EndPoint(segment.geom)) AS longitude,
        ST_Y(ST_EndPoint(segment.geom)) AS latitude,
        ST_EndPoint(segment.geom)::geometry(Point, 4326) AS geom
    FROM staging.osm_road_segment AS segment
)
INSERT INTO hvn.routing_node
(
    longitude,
    latitude,
    geom
)
SELECT
    endpoint.longitude,
    endpoint.latitude,
    endpoint.geom
FROM endpoints AS endpoint
ORDER BY
    endpoint.longitude,
    endpoint.latitude;

CREATE INDEX routing_node_geom_gix
    ON hvn.routing_node
    USING gist (geom);

-- ============================================================
-- Routing edges
--
-- Each OSM road segment becomes a directed graph edge.
--
-- cost and reverse_cost are expressed in seconds.
--
-- pgRouting convention:
--   positive cost  = direction permitted
--   negative cost  = direction prohibited
-- ============================================================

CREATE TABLE hvn.routing_edge
(
    edge_id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    source_node_id         bigint NOT NULL,
    target_node_id         bigint NOT NULL,

    source_way_id          bigint NOT NULL,
    source_segment_number  integer NOT NULL,

    highway                text,
    road_name              text,
    road_ref               text,
    access                  text,
    oneway                  text,

    speed_kmh              numeric(6,2) NOT NULL,
    length_metres          numeric(14,3) NOT NULL,
    travel_time_seconds    numeric(14,3) NOT NULL,

    cost                    double precision NOT NULL,
    reverse_cost            double precision NOT NULL,

    source_tags             jsonb,
    geom                    geometry(LineString, 4326) NOT NULL,

    CONSTRAINT routing_edge_source_node_fk
        FOREIGN KEY (source_node_id)
        REFERENCES hvn.routing_node (node_id),

    CONSTRAINT routing_edge_target_node_fk
        FOREIGN KEY (target_node_id)
        REFERENCES hvn.routing_node (node_id),

    CONSTRAINT routing_edge_different_nodes_ck
        CHECK (source_node_id <> target_node_id),

    CONSTRAINT routing_edge_positive_length_ck
        CHECK (length_metres > 0),

    CONSTRAINT routing_edge_positive_speed_ck
        CHECK (speed_kmh > 0)
);

WITH prepared_segments AS
(
    SELECT
        segment.source_way_id,
        segment.source_segment_number,
        segment.highway,
        segment.name AS road_name,
        segment.ref AS road_ref,
        segment.access,
        segment.source_tags,
        segment.length_metres,
        segment.geom,

        lower(
            coalesce(
                segment.oneway, ''
            )
        ) AS explicit_oneway,

        lower(
            coalesce(
                segment.junction, ''
            )
        ) AS junction_type,

        CASE segment.highway
            WHEN 'motorway'       THEN 100.0
            WHEN 'motorway_link'  THEN 70.0
            WHEN 'trunk'          THEN 90.0
            WHEN 'trunk_link'     THEN 60.0
            WHEN 'primary'        THEN 80.0
            WHEN 'primary_link'   THEN 60.0
            WHEN 'secondary'      THEN 70.0
            WHEN 'secondary_link' THEN 50.0
            WHEN 'tertiary'       THEN 60.0
            WHEN 'tertiary_link'  THEN 40.0
            WHEN 'unclassified'   THEN 50.0
            WHEN 'residential'    THEN 50.0
            WHEN 'living_street'  THEN 20.0
            WHEN 'service'        THEN 25.0
            WHEN 'track'          THEN 20.0
            ELSE 40.0
        END AS default_speed_kmh

    FROM staging.osm_road_segment AS segment
    WHERE
        segment.geom IS NOT NULL
        AND NOT ST_IsEmpty(segment.geom)
        AND ST_NPoints(segment.geom) >= 2
        AND segment.length_metres > 0
),
resolved_segments AS
(
    SELECT
        prepared.*,

        CASE
            WHEN explicit_oneway IN ('yes', 'true', '1') THEN 'forward'
            WHEN explicit_oneway = '-1' THEN 'reverse'
            WHEN explicit_oneway IN ('no', 'false', '0') THEN 'both'
            WHEN junction_type = 'roundabout' THEN 'forward'
            ELSE 'both'
        END AS direction_mode

    FROM prepared_segments AS prepared
),
matched_segments AS
(
    SELECT
        resolved.*,
        source_node.node_id AS source_node_id,
        target_node.node_id AS target_node_id,

        (
            resolved.length_metres
            /
            (resolved.default_speed_kmh * 1000.0 / 3600.0)
        ) AS calculated_travel_time_seconds

    FROM resolved_segments AS resolved

    INNER JOIN hvn.routing_node AS source_node
        ON source_node.longitude =
            ST_X(ST_StartPoint(resolved.geom))
       AND source_node.latitude =
            ST_Y(ST_StartPoint(resolved.geom))

    INNER JOIN hvn.routing_node AS target_node
        ON target_node.longitude =
            ST_X(ST_EndPoint(resolved.geom))
       AND target_node.latitude =
            ST_Y(ST_EndPoint(resolved.geom))
)
INSERT INTO hvn.routing_edge
(
    source_node_id,
    target_node_id,
    source_way_id,
    source_segment_number,
    highway,
    road_name,
    road_ref,
    access,
    oneway,
    speed_kmh,
    length_metres,
    travel_time_seconds,
    cost,
    reverse_cost,
    source_tags,
    geom
)
SELECT
    matched.source_node_id,
    matched.target_node_id,
    matched.source_way_id,
    matched.source_segment_number,
    matched.highway,
    matched.road_name,
    matched.road_ref,
    matched.access,
    matched.direction_mode,
    matched.default_speed_kmh,
    matched.length_metres,
    matched.calculated_travel_time_seconds,

    CASE matched.direction_mode
        WHEN 'reverse' THEN -1.0
        ELSE matched.calculated_travel_time_seconds
    END AS cost,

    CASE matched.direction_mode
        WHEN 'forward' THEN -1.0
        ELSE matched.calculated_travel_time_seconds
    END AS reverse_cost,

    matched.source_tags,
    matched.geom

FROM matched_segments AS matched
WHERE matched.source_node_id <> matched.target_node_id;

-- ============================================================
-- Routing indexes
-- ============================================================

CREATE INDEX routing_edge_source_node_idx
    ON hvn.routing_edge (source_node_id);

CREATE INDEX routing_edge_target_node_idx
    ON hvn.routing_edge (target_node_id);

CREATE INDEX routing_edge_source_target_idx
    ON hvn.routing_edge
    (
        source_node_id,
        target_node_id
    );

CREATE INDEX routing_edge_source_way_idx
    ON hvn.routing_edge (source_way_id);

CREATE INDEX routing_edge_highway_idx
    ON hvn.routing_edge (highway);

CREATE INDEX routing_edge_road_name_idx
    ON hvn.routing_edge (road_name);

CREATE INDEX routing_edge_road_ref_idx
    ON hvn.routing_edge (road_ref);

CREATE INDEX routing_edge_geom_gix
    ON hvn.routing_edge
    USING gist (geom);

ANALYZE hvn.routing_node;
ANALYZE hvn.routing_edge;

COMMIT;
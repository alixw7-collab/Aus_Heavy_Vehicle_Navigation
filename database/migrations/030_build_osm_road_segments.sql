/*
Project RoadTrain
Build derived OSM road segments

Source:
    osm.road_way

Target:
    staging.osm_road_segment

Purpose:
    Split OSM road ways into individual two-point segments suitable
    for later topology, access-rule and routing-cost processing.

The osm schema remains the immutable imported source layer.
*/

BEGIN;

DROP TABLE IF EXISTS staging.osm_road_segment;

CREATE TABLE staging.osm_road_segment
(
    road_segment_id       bigint GENERATED ALWAYS AS IDENTITY,
    source_way_id         bigint NOT NULL,
    source_segment_number integer NOT NULL,

    name                  text,
    ref                   text,
    highway               text NOT NULL,

    oneway                text,
    junction              text,

    maxspeed              text,
    maxweight             text,
    maxheight             text,
    maxwidth              text,
    maxlength             text,

    access                text,
    motor_vehicle         text,
    hgv                   text,
    hazmat                text,

    bridge                text,
    tunnel                text,
    lanes                 text,
    surface               text,
    smoothness            text,

    source_tags           jsonb,

    length_metres         double precision NOT NULL,

    geom                  geometry(LineString, 4326) NOT NULL,

    created_at            timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_osm_road_segment
        PRIMARY KEY (road_segment_id),

    CONSTRAINT uq_osm_road_segment_source
        UNIQUE (source_way_id, source_segment_number),

    CONSTRAINT ck_osm_road_segment_positive_length
        CHECK (length_metres > 0),

    CONSTRAINT ck_osm_road_segment_two_or_more_points
        CHECK (ST_NPoints(geom) >= 2),

    CONSTRAINT ck_osm_road_segment_valid_geometry
        CHECK (ST_IsValid(geom))
);

INSERT INTO staging.osm_road_segment
(
    source_way_id,
    source_segment_number,

    name,
    ref,
    highway,

    oneway,
    junction,

    maxspeed,
    maxweight,
    maxheight,
    maxwidth,
    maxlength,

    access,
    motor_vehicle,
    hgv,
    hazmat,

    bridge,
    tunnel,
    lanes,
    surface,
    smoothness,

    source_tags,

    length_metres,
    geom
)
SELECT
    road.way_id,
    segment.path[1]::integer,

    road.name,
    road.ref,
    road.highway,

    road.oneway,
    road.junction,

    road.maxspeed,
    road.maxweight,
    road.maxheight,
    road.maxwidth,
    road.maxlength,

    road.access,
    road.motor_vehicle,
    road.hgv,
    road.hazmat,

    road.bridge,
    road.tunnel,
    road.lanes,
    road.surface,
    road.smoothness,

    road.tags,

    ST_Length(segment.geom::geography),
    segment.geom::geometry(LineString, 4326)

FROM osm.road_way AS road

CROSS JOIN LATERAL
    ST_DumpSegments(road.geom) AS segment

WHERE
    road.highway IN
    (
        'motorway',
        'motorway_link',
        'trunk',
        'trunk_link',
        'primary',
        'primary_link',
        'secondary',
        'secondary_link',
        'tertiary',
        'tertiary_link',
        'unclassified',
        'residential',
        'living_street',
        'service',
        'road',
        'track'
    )

    AND NOT ST_IsEmpty(segment.geom)

    AND ST_NPoints(segment.geom) >= 2

    AND ST_Length(segment.geom::geography) > 0;

CREATE INDEX ix_osm_road_segment_geom
    ON staging.osm_road_segment
    USING gist (geom);

CREATE INDEX ix_osm_road_segment_source_way
    ON staging.osm_road_segment (source_way_id);

CREATE INDEX ix_osm_road_segment_highway
    ON staging.osm_road_segment (highway);

CREATE INDEX ix_osm_road_segment_ref
    ON staging.osm_road_segment (ref)
    WHERE ref IS NOT NULL;

CREATE INDEX ix_osm_road_segment_name
    ON staging.osm_road_segment (name)
    WHERE name IS NOT NULL;

CREATE INDEX ix_osm_road_segment_access
    ON staging.osm_road_segment
    (
        access,
        motor_vehicle,
        hgv
    );

ANALYZE staging.osm_road_segment;

COMMIT;
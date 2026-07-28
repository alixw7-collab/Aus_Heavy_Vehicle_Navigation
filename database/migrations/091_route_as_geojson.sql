/*
===============================================================================
Project RoadTrain
Migration 091: Return a vehicle route as GeoJSON
===============================================================================

Purpose:
    Convert the coordinate-based vehicle route into a GeoJSON FeatureCollection
    suitable for web, mobile and GIS clients.

Output:
    One JSONB document containing:

    - GeoJSON FeatureCollection
    - one feature per traversed routing edge
    - directionally aligned edge geometry
    - road and routing properties for each feature

Coordinate system:
    WGS84 / EPSG:4326
===============================================================================
*/

BEGIN;

CREATE OR REPLACE FUNCTION hvn.route_as_geojson(
    p_start_latitude DOUBLE PRECISION,
    p_start_longitude DOUBLE PRECISION,
    p_end_latitude DOUBLE PRECISION,
    p_end_longitude DOUBLE PRECISION,
    p_vehicle_profile_id BIGINT,
    p_corridor_metres DOUBLE PRECISION DEFAULT 50000
)
RETURNS JSONB
LANGUAGE sql
STABLE
PARALLEL RESTRICTED
AS $function$

    WITH route AS MATERIALIZED (
        SELECT *
        FROM hvn.route_between_coordinates(
            p_start_latitude,
            p_start_longitude,
            p_end_latitude,
            p_end_longitude,
            p_vehicle_profile_id,
            p_corridor_metres
        )
    ),

    route_features AS (
        SELECT
            r.route_sequence,

            jsonb_build_object(
                'type', 'Feature',

                'id', r.edge_id,

                'geometry',
                    ST_AsGeoJSON(
                        r.geom,
                        7
                    )::jsonb,

                'properties',
                    jsonb_build_object(
                        'route_sequence',
                            r.route_sequence,

                        'path_sequence',
                            r.path_sequence,

                        'node_id',
                            r.node_id,

                        'edge_id',
                            r.edge_id,

                        'source_node_id',
                            r.source_node_id,

                        'target_node_id',
                            r.target_node_id,

                        'road_name',
                            r.road_name,

                        'road_ref',
                            r.road_ref,

                        'road_class',
                            r.road_class,

                        'edge_cost',
                            r.edge_cost,

                        'aggregate_cost',
                            r.aggregate_cost,

                        'edge_length_metres',
                            r.edge_length_metres,

                        'cumulative_length_metres',
                            r.cumulative_length_metres,

                        'edge_travel_time_seconds',
                            r.edge_travel_time_seconds,

                        'cumulative_travel_time_seconds',
                            r.cumulative_travel_time_seconds,

                        'traversed_forward',
                            r.traversed_forward
                    )
            ) AS feature

        FROM route r

        /*
         * The terminal pgRouting row can have edge_id = -1 and no geometry.
         * It is not included as a GeoJSON line feature.
         */
        WHERE r.edge_id >= 0
          AND r.geom IS NOT NULL
    ),

    route_summary AS (
        SELECT
            COUNT(*) FILTER (
                WHERE r.edge_id >= 0
                  AND r.geom IS NOT NULL
            ) AS edge_count,

            COALESCE(
                MAX(r.cumulative_length_metres),
                0
            ) AS total_distance_metres,

            COALESCE(
                MAX(r.cumulative_travel_time_seconds),
                0
            ) AS total_travel_time_seconds

        FROM route r
    )

    SELECT jsonb_build_object(
        'type',
            'FeatureCollection',

        'metadata',
            jsonb_build_object(
                'vehicle_profile_id',
                    p_vehicle_profile_id,

                'start',
                    jsonb_build_object(
                        'latitude',
                            p_start_latitude,

                        'longitude',
                            p_start_longitude
                    ),

                'destination',
                    jsonb_build_object(
                        'latitude',
                            p_end_latitude,

                        'longitude',
                            p_end_longitude
                    ),

                'corridor_metres',
                    p_corridor_metres,

                'edge_count',
                    rs.edge_count,

                'total_distance_metres',
                    rs.total_distance_metres,

                'total_distance_kilometres',
                    ROUND(
                        rs.total_distance_metres::numeric / 1000,
                        3
                    ),

                'total_travel_time_seconds',
                    rs.total_travel_time_seconds,

                'total_travel_time_minutes',
                    ROUND(
                        rs.total_travel_time_seconds::numeric / 60,
                        2
                    ),

                'coordinate_reference_system',
                    'EPSG:4326'
            ),

        'features',
            COALESCE(
                (
                    SELECT jsonb_agg(
                        rf.feature
                        ORDER BY rf.route_sequence
                    )
                    FROM route_features rf
                ),
                '[]'::jsonb
            )
    )

    FROM route_summary rs;

$function$;

COMMENT ON FUNCTION hvn.route_as_geojson(
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    BIGINT,
    DOUBLE PRECISION
)
IS
'Returns a vehicle-compatible route between two WGS84 coordinates as a GeoJSON FeatureCollection with route metadata.';

COMMIT;
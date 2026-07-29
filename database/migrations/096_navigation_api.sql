/*
===============================================================================
Project RoadTrain
Migration 096: Single-pass navigation API
===============================================================================

Purpose:
    Provide one public navigation function that calculates the vehicle-aware
    route once and derives all response components from that materialised
    route result.

Returns:
    One JSONB navigation document containing:

        request
        summary
        diagnostics
        instructions
        route

Performance:
    hvn.route_between_coordinates() is called once per navigation request.
===============================================================================
*/

BEGIN;

CREATE OR REPLACE FUNCTION hvn.navigate(
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

route_edges AS MATERIALIZED (
    SELECT
        r.route_sequence,
        r.path_sequence,
        r.node_id,
        r.edge_id,
        r.source_node_id,
        r.target_node_id,
        r.road_name,
        r.road_ref,
        r.road_class,
        r.edge_cost,
        r.aggregate_cost,
        r.edge_length_metres,
        r.cumulative_length_metres,
        r.edge_travel_time_seconds,
        r.cumulative_travel_time_seconds,
        r.traversed_forward,
        r.geom,

        e.highway,
        e.surface_type,
        e.lane_count,
        e.max_height_m,
        e.max_width_m,
        e.max_length_m,
        e.max_weight_t,
        e.motor_vehicle_allowed,
        e.hgv_allowed,
        e.hazmat_allowed,
        e.is_bridge,
        e.is_tunnel,
        e.is_roundabout,
        e.is_oneway

    FROM route r

    LEFT JOIN hvn.routing_edge e
        ON e.edge_id = r.edge_id

    WHERE r.edge_id >= 0
      AND r.geom IS NOT NULL
),

summary_values AS (
    SELECT
        COUNT(*)::BIGINT AS edge_count,

        COUNT(
            DISTINCT NULLIF(BTRIM(road_name), '')
        )::BIGINT AS distinct_named_roads,

        COALESCE(
            SUM(edge_length_metres),
            0::DOUBLE PRECISION
        ) AS total_distance_metres,

        COALESCE(
            SUM(edge_travel_time_seconds),
            0::DOUBLE PRECISION
        ) AS total_travel_time_seconds

    FROM route_edges
),

diagnostic_values AS (
    SELECT
        COUNT(*) FILTER (
            WHERE max_height_m IS NOT NULL
        )::BIGINT AS height_limited_edges,

        MIN(max_height_m) FILTER (
            WHERE max_height_m IS NOT NULL
        ) AS lowest_height_limit_m,

        COUNT(*) FILTER (
            WHERE max_width_m IS NOT NULL
        )::BIGINT AS width_limited_edges,

        MIN(max_width_m) FILTER (
            WHERE max_width_m IS NOT NULL
        ) AS narrowest_width_limit_m,

        COUNT(*) FILTER (
            WHERE max_length_m IS NOT NULL
        )::BIGINT AS length_limited_edges,

        MIN(max_length_m) FILTER (
            WHERE max_length_m IS NOT NULL
        ) AS lowest_length_limit_m,

        COUNT(*) FILTER (
            WHERE max_weight_t IS NOT NULL
        )::BIGINT AS weight_limited_edges,

        MIN(max_weight_t) FILTER (
            WHERE max_weight_t IS NOT NULL
        ) AS lowest_weight_limit_t,

        COUNT(*) FILTER (
            WHERE motor_vehicle_allowed IS FALSE
        )::BIGINT AS motor_vehicle_prohibited_edges,

        COUNT(*) FILTER (
            WHERE hgv_allowed IS FALSE
        )::BIGINT AS hgv_prohibited_edges,

        COUNT(*) FILTER (
            WHERE hazmat_allowed IS FALSE
        )::BIGINT AS hazmat_prohibited_edges,

        COUNT(*) FILTER (
            WHERE is_bridge IS TRUE
        )::BIGINT AS bridge_edges,

        COUNT(*) FILTER (
            WHERE is_tunnel IS TRUE
        )::BIGINT AS tunnel_edges,

        COUNT(*) FILTER (
            WHERE is_roundabout IS TRUE
        )::BIGINT AS roundabout_edges,

        COUNT(*) FILTER (
            WHERE is_oneway IS TRUE
        )::BIGINT AS oneway_edges

    FROM route_edges
),

normalised_edges AS (
    SELECT
        re.*,

        COALESCE(
            NULLIF(BTRIM(re.road_name), ''),
            NULLIF(BTRIM(re.road_ref), ''),
            'Unnamed Road'
        ) AS display_road_name,

        COALESCE(
            NULLIF(BTRIM(re.road_name), ''),
            ''
        ) AS normalised_road_name,

        COALESCE(
            NULLIF(BTRIM(re.road_ref), ''),
            ''
        ) AS normalised_road_ref,

        COALESCE(
            NULLIF(BTRIM(re.road_class), ''),
            ''
        ) AS normalised_road_class

    FROM route_edges re
),

instruction_boundaries AS (
    SELECT
        ne.*,

        CASE
            WHEN LAG(ne.normalised_road_name)
                 OVER (ORDER BY ne.route_sequence)
                 IS DISTINCT FROM ne.normalised_road_name

              OR LAG(ne.normalised_road_ref)
                 OVER (ORDER BY ne.route_sequence)
                 IS DISTINCT FROM ne.normalised_road_ref

              OR LAG(ne.normalised_road_class)
                 OVER (ORDER BY ne.route_sequence)
                 IS DISTINCT FROM ne.normalised_road_class

            THEN 1
            ELSE 0
        END AS starts_new_group

    FROM normalised_edges ne
),

instruction_groups AS (
    SELECT
        ib.*,

        SUM(ib.starts_new_group)
        OVER (
            ORDER BY ib.route_sequence
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW
        ) AS instruction_group_id

    FROM instruction_boundaries ib
),

grouped_instructions AS (
    SELECT
        instruction_group_id,

        MIN(route_sequence)::INTEGER
            AS start_route_sequence,

        MAX(route_sequence)::INTEGER
            AS end_route_sequence,

        COUNT(*)::BIGINT
            AS edge_count,

        MAX(display_road_name)
            AS display_road_name,

        NULLIF(MAX(normalised_road_name), '')
            AS road_name,

        NULLIF(MAX(normalised_road_ref), '')
            AS road_ref,

        NULLIF(MAX(normalised_road_class), '')
            AS road_class,

        COALESCE(
            SUM(edge_length_metres),
            0::DOUBLE PRECISION
        ) AS distance_metres,

        COALESCE(
            SUM(edge_travel_time_seconds),
            0::DOUBLE PRECISION
        ) AS travel_time_seconds

    FROM instruction_groups

    GROUP BY instruction_group_id
),

numbered_instructions AS (
    SELECT
        ROW_NUMBER()
        OVER (
            ORDER BY start_route_sequence
        )::INTEGER AS instruction_sequence,

        gi.*

    FROM grouped_instructions gi
),

instruction_documents AS (
    SELECT
        ni.instruction_sequence,

        jsonb_build_object(
            'sequence',
                ni.instruction_sequence,

            'type',
                CASE
                    WHEN ni.instruction_sequence = 1
                        THEN 'DEPART'
                    ELSE 'CONTINUE'
                END,

            'instruction',
                CASE
                    WHEN ni.instruction_sequence = 1 THEN
                        'Depart via '
                        || ni.display_road_name
                        || ' for '
                        || CASE
                            WHEN ni.distance_metres >= 1000 THEN
                                ROUND(
                                    ni.distance_metres::NUMERIC / 1000,
                                    1
                                )::TEXT || ' km'
                            ELSE
                                ROUND(
                                    ni.distance_metres::NUMERIC,
                                    0
                                )::TEXT || ' m'
                        END

                    ELSE
                        'Continue on '
                        || ni.display_road_name
                        || ' for '
                        || CASE
                            WHEN ni.distance_metres >= 1000 THEN
                                ROUND(
                                    ni.distance_metres::NUMERIC / 1000,
                                    1
                                )::TEXT || ' km'
                            ELSE
                                ROUND(
                                    ni.distance_metres::NUMERIC,
                                    0
                                )::TEXT || ' m'
                        END
                END,

            'road_name',
                ni.road_name,

            'road_ref',
                ni.road_ref,

            'road_class',
                ni.road_class,

            'start_route_sequence',
                ni.start_route_sequence,

            'end_route_sequence',
                ni.end_route_sequence,

            'edge_count',
                ni.edge_count,

            'distance_metres',
                ROUND(
                    ni.distance_metres::NUMERIC,
                    2
                ),

            'distance_kilometres',
                ROUND(
                    ni.distance_metres::NUMERIC / 1000,
                    3
                ),

            'travel_time_seconds',
                ROUND(
                    ni.travel_time_seconds::NUMERIC,
                    2
                ),

            'travel_time_minutes',
                ROUND(
                    ni.travel_time_seconds::NUMERIC / 60,
                    2
                )
        ) AS instruction_document

    FROM numbered_instructions ni
),

instruction_array AS (
    SELECT
        COALESCE(
            jsonb_agg(
                instruction_document
                ORDER BY instruction_sequence
            ),
            '[]'::JSONB
        )
        ||
        jsonb_build_array(
            jsonb_build_object(
                'sequence',
                    COALESCE(
                        MAX(instruction_sequence),
                        0
                    ) + 1,

                'type',
                    'ARRIVE',

                'instruction',
                    'Arrive at destination',

                'road_name',
                    NULL,

                'road_ref',
                    NULL,

                'road_class',
                    NULL,

                'edge_count',
                    0,

                'distance_metres',
                    0,

                'distance_kilometres',
                    0,

                'travel_time_seconds',
                    0,

                'travel_time_minutes',
                    0
            )
        ) AS instructions

    FROM instruction_documents
),

geojson_features AS (
    SELECT
        re.route_sequence,

        jsonb_build_object(
            'type',
                'Feature',

            'id',
                re.edge_id,

            'geometry',
                ST_AsGeoJSON(re.geom)::JSONB,

            'properties',
                jsonb_build_object(
                    'route_sequence',
                        re.route_sequence,

                    'edge_id',
                        re.edge_id,

                    'road_name',
                        re.road_name,

                    'road_ref',
                        re.road_ref,

                    'road_class',
                        re.road_class,

                    'highway',
                        re.highway,

                    'surface_type',
                        re.surface_type,

                    'lane_count',
                        re.lane_count,

                    'length_metres',
                        re.edge_length_metres,

                    'travel_time_seconds',
                        re.edge_travel_time_seconds,

                    'traversed_forward',
                        re.traversed_forward,

                    'max_height_m',
                        re.max_height_m,

                    'max_width_m',
                        re.max_width_m,

                    'max_length_m',
                        re.max_length_m,

                    'max_weight_t',
                        re.max_weight_t,

                    'hgv_allowed',
                        re.hgv_allowed,

                    'hazmat_allowed',
                        re.hazmat_allowed,

                    'is_bridge',
                        re.is_bridge,

                    'is_tunnel',
                        re.is_tunnel
                )
        ) AS feature

    FROM route_edges re
),

geojson_document AS (
    SELECT
        jsonb_build_object(
            'type',
                'FeatureCollection',

            'features',
                COALESCE(
                    jsonb_agg(
                        feature
                        ORDER BY route_sequence
                    ),
                    '[]'::JSONB
                )
        ) AS route_geojson

    FROM geojson_features
)

SELECT jsonb_build_object(
    'api_version',
        '1.0',

    'generated_at',
        CURRENT_TIMESTAMP,

    'request',
        jsonb_build_object(
            'start',
                jsonb_build_object(
                    'latitude',
                        p_start_latitude,
                    'longitude',
                        p_start_longitude
                ),

            'end',
                jsonb_build_object(
                    'latitude',
                        p_end_latitude,
                    'longitude',
                        p_end_longitude
                ),

            'vehicle_profile_id',
                p_vehicle_profile_id,

            'corridor_metres',
                p_corridor_metres
        ),

    'summary',
        jsonb_build_object(
            'route_found',
                sv.edge_count > 0,

            'edge_count',
                sv.edge_count,

            'distinct_named_roads',
                sv.distinct_named_roads,

            'total_distance_metres',
                ROUND(
                    sv.total_distance_metres::NUMERIC,
                    2
                ),

            'total_distance_kilometres',
                ROUND(
                    sv.total_distance_metres::NUMERIC / 1000,
                    3
                ),

            'total_travel_time_seconds',
                ROUND(
                    sv.total_travel_time_seconds::NUMERIC,
                    2
                ),

            'total_travel_time_minutes',
                ROUND(
                    sv.total_travel_time_seconds::NUMERIC / 60,
                    2
                ),

            'average_speed_kph',
                CASE
                    WHEN sv.total_travel_time_seconds > 0 THEN
                        ROUND(
                            (
                                sv.total_distance_metres
                                / 1000.0
                                /
                                (
                                    sv.total_travel_time_seconds
                                    / 3600.0
                                )
                            )::NUMERIC,
                            1
                        )
                    ELSE NULL
                END
        ),

    'diagnostics',
        jsonb_build_object(
            'height_limited_edges',
                dv.height_limited_edges,

            'lowest_height_limit_m',
                dv.lowest_height_limit_m,

            'width_limited_edges',
                dv.width_limited_edges,

            'narrowest_width_limit_m',
                dv.narrowest_width_limit_m,

            'length_limited_edges',
                dv.length_limited_edges,

            'lowest_length_limit_m',
                dv.lowest_length_limit_m,

            'weight_limited_edges',
                dv.weight_limited_edges,

            'lowest_weight_limit_t',
                dv.lowest_weight_limit_t,

            'motor_vehicle_prohibited_edges',
                dv.motor_vehicle_prohibited_edges,

            'hgv_prohibited_edges',
                dv.hgv_prohibited_edges,

            'hazmat_prohibited_edges',
                dv.hazmat_prohibited_edges,

            'bridge_edges',
                dv.bridge_edges,

            'tunnel_edges',
                dv.tunnel_edges,

            'roundabout_edges',
                dv.roundabout_edges,

            'oneway_edges',
                dv.oneway_edges,

            'warnings',
                jsonb_strip_nulls(
                    jsonb_build_object(
                        'hazmat_restriction',
                            CASE
                                WHEN dv.hazmat_prohibited_edges > 0 THEN
                                    'Route contains edges tagged hazmat=no. '
                                    || 'This route must not be used for a '
                                    || 'dangerous-goods vehicle profile.'
                                ELSE NULL
                            END,

                        'hgv_restriction',
                            CASE
                                WHEN dv.hgv_prohibited_edges > 0 THEN
                                    'Route contains edges where '
                                    || 'hgv_allowed=false.'
                                ELSE NULL
                            END,

                        'motor_vehicle_restriction',
                            CASE
                                WHEN dv.motor_vehicle_prohibited_edges > 0 THEN
                                    'Route contains edges where '
                                    || 'motor_vehicle_allowed=false.'
                                ELSE NULL
                            END
                    )
                )
        ),

    'instructions',
        ia.instructions,

    'route',
        gd.route_geojson
)

FROM summary_values sv
CROSS JOIN diagnostic_values dv
CROSS JOIN instruction_array ia
CROSS JOIN geojson_document gd;

$function$;

COMMENT ON FUNCTION hvn.navigate(
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    BIGINT,
    DOUBLE PRECISION
)
IS
'Single-pass navigation API returning route summary, diagnostics, consolidated instructions and GeoJSON from one vehicle-aware route calculation.';

COMMIT;
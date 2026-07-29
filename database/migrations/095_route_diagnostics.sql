/*
===============================================================================
Project RoadTrain
Migration 095: Route diagnostics
===============================================================================

Purpose:
    Return diagnostic information for a vehicle-compatible route.

Important:
    Restriction counts describe attributes on the edges actually traversed by
    the calculated route. They do not represent roads rejected or avoided
    during route calculation.

Boolean access columns:
    TRUE  = explicitly allowed
    FALSE = explicitly prohibited
    NULL  = not explicitly specified in the source data
===============================================================================
*/

BEGIN;

CREATE OR REPLACE FUNCTION hvn.route_diagnostics(
    p_start_latitude DOUBLE PRECISION,
    p_start_longitude DOUBLE PRECISION,
    p_end_latitude DOUBLE PRECISION,
    p_end_longitude DOUBLE PRECISION,
    p_vehicle_profile_id BIGINT,
    p_corridor_metres DOUBLE PRECISION DEFAULT 50000
)
RETURNS TABLE (
    diagnostic_name TEXT,
    diagnostic_value TEXT
)
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

    traversed_edges AS MATERIALIZED (
        SELECT
            r.route_sequence,
            r.edge_id,
            r.edge_length_metres,
            r.edge_travel_time_seconds,
            r.cumulative_length_metres,
            r.cumulative_travel_time_seconds,

            e.highway,
            e.road_name,
            e.road_ref,
            e.road_class,
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
    ),

    route_summary AS (
        SELECT
            COUNT(*)::BIGINT AS edge_count,

            COALESCE(
                SUM(edge_length_metres),
                0::DOUBLE PRECISION
            ) AS total_distance_metres,

            COALESCE(
                SUM(edge_travel_time_seconds),
                0::DOUBLE PRECISION
            ) AS total_travel_time_seconds,

            COUNT(
                DISTINCT NULLIF(BTRIM(road_name), '')
            ) AS distinct_named_roads,

            COUNT(*) FILTER (
                WHERE max_height_m IS NOT NULL
            ) AS height_restricted_edges,

            COUNT(*) FILTER (
                WHERE max_width_m IS NOT NULL
            ) AS width_restricted_edges,

            COUNT(*) FILTER (
                WHERE max_length_m IS NOT NULL
            ) AS length_restricted_edges,

            COUNT(*) FILTER (
                WHERE max_weight_t IS NOT NULL
            ) AS weight_restricted_edges,

            COUNT(*) FILTER (
                WHERE motor_vehicle_allowed IS FALSE
            ) AS motor_vehicle_prohibited_edges,

            COUNT(*) FILTER (
                WHERE hgv_allowed IS FALSE
            ) AS hgv_prohibited_edges,

            COUNT(*) FILTER (
                WHERE hazmat_allowed IS FALSE
            ) AS hazmat_prohibited_edges,

            COUNT(*) FILTER (
                WHERE is_bridge IS TRUE
            ) AS bridge_edges,

            COUNT(*) FILTER (
                WHERE is_tunnel IS TRUE
            ) AS tunnel_edges,

            COUNT(*) FILTER (
                WHERE is_roundabout IS TRUE
            ) AS roundabout_edges,

            COUNT(*) FILTER (
                WHERE is_oneway IS TRUE
            ) AS oneway_edges,

            MIN(max_height_m)
                FILTER (WHERE max_height_m IS NOT NULL)
                AS lowest_height_limit_m,

            MIN(max_width_m)
                FILTER (WHERE max_width_m IS NOT NULL)
                AS narrowest_width_limit_m,

            MIN(max_length_m)
                FILTER (WHERE max_length_m IS NOT NULL)
                AS shortest_length_limit_m,

            MIN(max_weight_t)
                FILTER (WHERE max_weight_t IS NOT NULL)
                AS lowest_weight_limit_t

        FROM traversed_edges
    ),

    diagnostics AS (
        SELECT
            1 AS display_order,
            'Vehicle Profile ID'::TEXT AS diagnostic_name,
            p_vehicle_profile_id::TEXT AS diagnostic_value

        UNION ALL

        SELECT
            2,
            'Route Found',
            CASE
                WHEN edge_count > 0 THEN 'true'
                ELSE 'false'
            END
        FROM route_summary

        UNION ALL

        SELECT
            3,
            'Edges Traversed',
            edge_count::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            4,
            'Distinct Named Roads',
            distinct_named_roads::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            5,
            'Distance (km)',
            ROUND(
                total_distance_metres::NUMERIC / 1000,
                2
            )::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            6,
            'Travel Time (minutes)',
            ROUND(
                total_travel_time_seconds::NUMERIC / 60,
                1
            )::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            7,
            'Average Speed (km/h)',
            CASE
                WHEN total_travel_time_seconds > 0 THEN
                    ROUND(
                        (
                            total_distance_metres / 1000.0
                            /
                            (total_travel_time_seconds / 3600.0)
                        )::NUMERIC,
                        1
                    )::TEXT
                ELSE NULL
            END
        FROM route_summary

        UNION ALL

        SELECT
            8,
            'Height-Limited Edges',
            height_restricted_edges::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            9,
            'Lowest Height Limit (m)',
            COALESCE(
                ROUND(lowest_height_limit_m, 2)::TEXT,
                'none'
            )
        FROM route_summary

        UNION ALL

        SELECT
            10,
            'Width-Limited Edges',
            width_restricted_edges::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            11,
            'Narrowest Width Limit (m)',
            COALESCE(
                ROUND(narrowest_width_limit_m, 2)::TEXT,
                'none'
            )
        FROM route_summary

        UNION ALL

        SELECT
            12,
            'Length-Limited Edges',
            length_restricted_edges::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            13,
            'Lowest Length Limit (m)',
            COALESCE(
                ROUND(shortest_length_limit_m, 2)::TEXT,
                'none'
            )
        FROM route_summary

        UNION ALL

        SELECT
            14,
            'Weight-Limited Edges',
            weight_restricted_edges::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            15,
            'Lowest Weight Limit (t)',
            COALESCE(
                ROUND(lowest_weight_limit_t, 2)::TEXT,
                'none'
            )
        FROM route_summary

        UNION ALL

        SELECT
            16,
            'Motor Vehicle Prohibited Edges',
            motor_vehicle_prohibited_edges::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            17,
            'HGV Prohibited Edges',
            hgv_prohibited_edges::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            18,
            'Hazmat Prohibited Edges',
            hazmat_prohibited_edges::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            19,
            'Bridge Edges',
            bridge_edges::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            20,
            'Tunnel Edges',
            tunnel_edges::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            21,
            'Roundabout Edges',
            roundabout_edges::TEXT
        FROM route_summary

        UNION ALL

        SELECT
            22,
            'One-Way Edges',
            oneway_edges::TEXT
        FROM route_summary
    )

    SELECT
        diagnostic_name,
        diagnostic_value

    FROM diagnostics

    ORDER BY display_order;

$function$;

COMMENT ON FUNCTION hvn.route_diagnostics(
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    BIGINT,
    DOUBLE PRECISION
)
IS
'Returns distance, travel-time, restriction and infrastructure diagnostics for the edges traversed by a vehicle-compatible route.';

COMMIT;
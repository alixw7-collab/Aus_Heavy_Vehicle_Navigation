/*
===============================================================================
Project RoadTrain
Migration 092: Route summary
===============================================================================

Purpose:
    Return a compact summary for a vehicle-compatible route between two WGS84
    coordinates.

Output:
    - whether a route was found
    - number of traversed edges
    - total distance
    - estimated travel time
    - calculated average route speed
    - count of distinct named roads

Notes:
    The route is calculated once using a MATERIALIZED CTE and then aggregated
    into one result row.
===============================================================================
*/

BEGIN;

CREATE OR REPLACE FUNCTION hvn.route_summary(
    p_start_latitude DOUBLE PRECISION,
    p_start_longitude DOUBLE PRECISION,
    p_end_latitude DOUBLE PRECISION,
    p_end_longitude DOUBLE PRECISION,
    p_vehicle_profile_id BIGINT,
    p_corridor_metres DOUBLE PRECISION DEFAULT 50000
)
RETURNS TABLE (
    route_found BOOLEAN,
    edge_count BIGINT,
    distinct_named_roads BIGINT,
    total_distance_metres DOUBLE PRECISION,
    total_distance_kilometres DOUBLE PRECISION,
    total_travel_time_seconds DOUBLE PRECISION,
    total_travel_time_minutes DOUBLE PRECISION,
    average_speed_kph DOUBLE PRECISION
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

    summary AS (
        SELECT
            COUNT(*) FILTER (
                WHERE edge_id >= 0
                  AND geom IS NOT NULL
            ) AS edge_count,

            COUNT(
                DISTINCT NULLIF(
                    BTRIM(road_name),
                    ''
                )
            ) FILTER (
                WHERE edge_id >= 0
            ) AS distinct_named_roads,

            COALESCE(
                MAX(cumulative_length_metres),
                0::DOUBLE PRECISION
            ) AS total_distance_metres,

            COALESCE(
                MAX(cumulative_travel_time_seconds),
                0::DOUBLE PRECISION
            ) AS total_travel_time_seconds

        FROM route
    )

    SELECT
        s.edge_count > 0
            AS route_found,

        s.edge_count,

        s.distinct_named_roads,

        s.total_distance_metres,

        s.total_distance_metres / 1000.0
            AS total_distance_kilometres,

        s.total_travel_time_seconds,

        s.total_travel_time_seconds / 60.0
            AS total_travel_time_minutes,

        CASE
            WHEN s.total_travel_time_seconds > 0 THEN
                (
                    s.total_distance_metres / 1000.0
                )
                /
                (
                    s.total_travel_time_seconds / 3600.0
                )
            ELSE NULL
        END AS average_speed_kph

    FROM summary s;

$function$;

COMMENT ON FUNCTION hvn.route_summary(
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    BIGINT,
    DOUBLE PRECISION
)
IS
'Returns aggregate distance, travel-time and road-count statistics for a vehicle-compatible route between two WGS84 coordinates.';

COMMIT;
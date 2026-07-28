/*
===============================================================================
Project RoadTrain
Migration 094: Consolidated route instructions
===============================================================================

Purpose:
    Merge consecutive routing edges that belong to the same road into a single
    navigation instruction.

Example:
    Instead of:

        Continue on Gateway Motorway
        Continue on Gateway Motorway
        Continue on Gateway Motorway

    Return:

        Continue on Gateway Motorway for 8.4 km

Behaviour:
    - Calculates the route once.
    - Removes the terminal pgRouting row with edge_id = -1.
    - Normalises blank road names and references.
    - Uses a gaps-and-islands calculation to identify consecutive road groups.
    - Aggregates distance and estimated travel time for each group.
    - Appends a separate ARRIVE instruction.
===============================================================================
*/

BEGIN;

CREATE OR REPLACE FUNCTION hvn.consolidated_route_instructions(
    p_start_latitude DOUBLE PRECISION,
    p_start_longitude DOUBLE PRECISION,
    p_end_latitude DOUBLE PRECISION,
    p_end_longitude DOUBLE PRECISION,
    p_vehicle_profile_id BIGINT,
    p_corridor_metres DOUBLE PRECISION DEFAULT 50000
)
RETURNS TABLE (
    instruction_sequence INTEGER,
    instruction_type TEXT,
    instruction TEXT,
    road_name TEXT,
    road_ref TEXT,
    road_class TEXT,
    start_route_sequence INTEGER,
    end_route_sequence INTEGER,
    edge_count BIGINT,
    distance_metres DOUBLE PRECISION,
    distance_kilometres DOUBLE PRECISION,
    travel_time_seconds DOUBLE PRECISION,
    travel_time_minutes DOUBLE PRECISION
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

    usable_edges AS (
        SELECT
            r.route_sequence,
            r.road_name,
            r.road_ref,
            r.road_class,
            r.edge_length_metres,
            r.edge_travel_time_seconds,

            COALESCE(
                NULLIF(BTRIM(r.road_name), ''),
                NULLIF(BTRIM(r.road_ref), ''),
                'Unnamed Road'
            ) AS display_road_name,

            COALESCE(
                NULLIF(BTRIM(r.road_name), ''),
                ''
            ) AS normalised_road_name,

            COALESCE(
                NULLIF(BTRIM(r.road_ref), ''),
                ''
            ) AS normalised_road_ref,

            COALESCE(
                NULLIF(BTRIM(r.road_class), ''),
                ''
            ) AS normalised_road_class

        FROM route r
        WHERE r.edge_id >= 0
          AND r.geom IS NOT NULL
    ),

    road_boundaries AS (
        SELECT
            ue.*,

            CASE
                WHEN LAG(ue.normalised_road_name)
                     OVER (ORDER BY ue.route_sequence)
                     IS DISTINCT FROM ue.normalised_road_name
                  OR LAG(ue.normalised_road_ref)
                     OVER (ORDER BY ue.route_sequence)
                     IS DISTINCT FROM ue.normalised_road_ref
                  OR LAG(ue.normalised_road_class)
                     OVER (ORDER BY ue.route_sequence)
                     IS DISTINCT FROM ue.normalised_road_class
                THEN 1
                ELSE 0
            END AS starts_new_group

        FROM usable_edges ue
    ),

    numbered_groups AS (
        SELECT
            rb.*,

            SUM(rb.starts_new_group)
            OVER (
                ORDER BY rb.route_sequence
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS road_group_id

        FROM road_boundaries rb
    ),

    grouped_roads AS (
        SELECT
            ng.road_group_id,

            MIN(ng.route_sequence)::INTEGER
                AS start_route_sequence,

            MAX(ng.route_sequence)::INTEGER
                AS end_route_sequence,

            COUNT(*)::BIGINT
                AS edge_count,

            MAX(ng.display_road_name)
                AS display_road_name,

            NULLIF(MAX(ng.normalised_road_name), '')
                AS road_name,

            NULLIF(MAX(ng.normalised_road_ref), '')
                AS road_ref,

            NULLIF(MAX(ng.normalised_road_class), '')
                AS road_class,

            COALESCE(
                SUM(ng.edge_length_metres),
                0::DOUBLE PRECISION
            ) AS distance_metres,

            COALESCE(
                SUM(ng.edge_travel_time_seconds),
                0::DOUBLE PRECISION
            ) AS travel_time_seconds

        FROM numbered_groups ng
        GROUP BY ng.road_group_id
    ),

    numbered_instructions AS (
        SELECT
            ROW_NUMBER()
            OVER (ORDER BY gr.start_route_sequence)::INTEGER
                AS instruction_sequence,

            gr.*,

            COUNT(*)
            OVER ()::INTEGER
                AS road_group_count

        FROM grouped_roads gr
    ),

    road_instructions AS (
        SELECT
            ni.instruction_sequence,

            CASE
                WHEN ni.instruction_sequence = 1
                    THEN 'DEPART'
                ELSE 'CONTINUE'
            END::TEXT AS instruction_type,

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
            END::TEXT AS instruction,

            ni.road_name,
            ni.road_ref,
            ni.road_class,
            ni.start_route_sequence,
            ni.end_route_sequence,
            ni.edge_count,
            ni.distance_metres,

            ni.distance_metres / 1000.0
                AS distance_kilometres,

            ni.travel_time_seconds,

            ni.travel_time_seconds / 60.0
                AS travel_time_minutes

        FROM numbered_instructions ni
    ),

    arrival_instruction AS (
        SELECT
            (
                COALESCE(MAX(ri.instruction_sequence), 0) + 1
            )::INTEGER AS instruction_sequence,

            'ARRIVE'::TEXT AS instruction_type,

            'Arrive at destination'::TEXT AS instruction,

            NULL::TEXT AS road_name,
            NULL::TEXT AS road_ref,
            NULL::TEXT AS road_class,

            NULL::INTEGER AS start_route_sequence,
            NULL::INTEGER AS end_route_sequence,

            0::BIGINT AS edge_count,
            0::DOUBLE PRECISION AS distance_metres,
            0::DOUBLE PRECISION AS distance_kilometres,
            0::DOUBLE PRECISION AS travel_time_seconds,
            0::DOUBLE PRECISION AS travel_time_minutes

        FROM road_instructions ri
    )

    SELECT *
    FROM road_instructions

    UNION ALL

    SELECT *
    FROM arrival_instruction

    ORDER BY instruction_sequence;

$function$;

COMMENT ON FUNCTION hvn.consolidated_route_instructions(
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    BIGINT,
    DOUBLE PRECISION
)
IS
'Merges consecutive route edges on the same road into consolidated navigation instructions and appends an arrival instruction.';

COMMIT;
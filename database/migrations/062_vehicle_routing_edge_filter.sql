/*
===============================================================================
Migration: 062_vehicle_routing_edge_filter.sql

Purpose:
    Provide a set-based routing-edge filter for a selected vehicle profile.

Design:
    - Evaluate millions of edges without calling the detailed PL/pgSQL
      function once per row.
    - Return pgRouting-compatible edge fields.
    - Exclude known prohibitions and physical restriction failures.
    - Preserve edges with unknown access data.
    - Provide a separate diagnostic function with compatibility reasons.

Dependencies:
    - hvn.routing_edge
    - hvn.vehicle_profile
    - hvn.evaluate_edge_vehicle_compatibility

===============================================================================
*/

BEGIN;


-------------------------------------------------------------------------------
-- 1. Routing-ready edge filter
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hvn.get_routable_edges_for_vehicle
(
    p_vehicle_profile_id BIGINT
)
RETURNS TABLE
(
    edge_id BIGINT,
    source_node_id BIGINT,
    target_node_id BIGINT,
    cost DOUBLE PRECISION,
    reverse_cost DOUBLE PRECISION,
    length_metres NUMERIC,
    travel_time_seconds NUMERIC,
    road_name TEXT,
    road_ref TEXT,
    road_class TEXT,
    geom geometry
)
LANGUAGE plpgsql
STABLE
PARALLEL SAFE
AS $$
DECLARE
    vehicle_record hvn.vehicle_profile%ROWTYPE;
BEGIN
    SELECT *
    INTO vehicle_record
    FROM hvn.vehicle_profile AS vehicle
    WHERE vehicle.vehicle_profile_id = p_vehicle_profile_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Vehicle profile % does not exist.',
            p_vehicle_profile_id
            USING ERRCODE = 'P0002';
    END IF;

    IF vehicle_record.is_active = FALSE THEN
        RAISE EXCEPTION
            'Vehicle profile % is inactive.',
            p_vehicle_profile_id
            USING ERRCODE = 'P0001';
    END IF;

    RETURN QUERY
    SELECT
        edge.edge_id,
        edge.source_node_id,
        edge.target_node_id,
        edge.cost,
        edge.reverse_cost,
        edge.length_metres,
        edge.travel_time_seconds,
        edge.road_name,
        edge.road_ref,
        edge.road_class,
        edge.geom
    FROM hvn.routing_edge AS edge
    WHERE
        /*
         * General motor-vehicle prohibition.
         */
        edge.motor_vehicle_allowed IS DISTINCT FROM FALSE

        /*
         * HGV prohibition applies only where the profile requires HGV access.
         */
        AND (
            vehicle_record.requires_hgv_access = FALSE
            OR edge.hgv_allowed IS DISTINCT FROM FALSE
        )

        /*
         * Dangerous-goods prohibition applies only when the vehicle carries
         * dangerous goods.
         */
        AND (
            vehicle_record.carries_dangerous_goods = FALSE
            OR edge.hazmat_allowed IS DISTINCT FROM FALSE
        )

        /*
         * A missing physical restriction remains usable but unverified.
         * A populated restriction must accommodate the vehicle.
         */
        AND (
            edge.max_height_m IS NULL
            OR vehicle_record.height_m <= edge.max_height_m
        )

        AND (
            edge.max_width_m IS NULL
            OR vehicle_record.width_m <= edge.max_width_m
        )

        AND (
            edge.max_length_m IS NULL
            OR vehicle_record.length_m <= edge.max_length_m
        )

        AND (
            edge.max_weight_t IS NULL
            OR vehicle_record.gross_mass_t <= edge.max_weight_t
        );
END;
$$;


-------------------------------------------------------------------------------
-- 2. Diagnostic compatibility query
--
-- This is intended for inspection, reporting and route explanation.
-- It is not intended to be the primary pgRouting edge SQL.
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hvn.get_edge_compatibility_report
(
    p_vehicle_profile_id BIGINT,
    p_only_blocked BOOLEAN DEFAULT FALSE
)
RETURNS TABLE
(
    edge_id BIGINT,
    road_name TEXT,
    road_ref TEXT,
    road_class TEXT,

    assessment_status TEXT,
    is_routable BOOLEAN,
    primary_reason TEXT,
    reasons TEXT[],
    warnings TEXT[],

    max_height_m NUMERIC,
    max_width_m NUMERIC,
    max_length_m NUMERIC,
    max_weight_t NUMERIC
)
LANGUAGE plpgsql
STABLE
PARALLEL SAFE
AS $$
DECLARE
    vehicle_record hvn.vehicle_profile%ROWTYPE;
BEGIN
    SELECT *
    INTO vehicle_record
    FROM hvn.vehicle_profile AS vehicle
    WHERE vehicle.vehicle_profile_id = p_vehicle_profile_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Vehicle profile % does not exist.',
            p_vehicle_profile_id
            USING ERRCODE = 'P0002';
    END IF;

    RETURN QUERY
    SELECT
        edge.edge_id,
        edge.road_name,
        edge.road_ref,
        edge.road_class,

        CASE
            WHEN
                edge.motor_vehicle_allowed = FALSE

                OR (
                    vehicle_record.requires_hgv_access
                    AND edge.hgv_allowed = FALSE
                )

                OR (
                    vehicle_record.carries_dangerous_goods
                    AND edge.hazmat_allowed = FALSE
                )

                OR (
                    edge.max_height_m IS NOT NULL
                    AND vehicle_record.height_m > edge.max_height_m
                )

                OR (
                    edge.max_width_m IS NOT NULL
                    AND vehicle_record.width_m > edge.max_width_m
                )

                OR (
                    edge.max_length_m IS NOT NULL
                    AND vehicle_record.length_m > edge.max_length_m
                )

                OR (
                    edge.max_weight_t IS NOT NULL
                    AND vehicle_record.gross_mass_t > edge.max_weight_t
                )
            THEN 'BLOCKED'

            WHEN
                edge.motor_vehicle_allowed IS NULL

                OR (
                    vehicle_record.requires_hgv_access
                    AND edge.hgv_allowed IS NULL
                )

                OR (
                    vehicle_record.carries_dangerous_goods
                    AND edge.hazmat_allowed IS NULL
                )
            THEN 'PASS_WITH_WARNINGS'

            ELSE 'PASS'
        END,

        NOT (
            edge.motor_vehicle_allowed = FALSE

            OR (
                vehicle_record.requires_hgv_access
                AND edge.hgv_allowed = FALSE
            )

            OR (
                vehicle_record.carries_dangerous_goods
                AND edge.hazmat_allowed = FALSE
            )

            OR (
                edge.max_height_m IS NOT NULL
                AND vehicle_record.height_m > edge.max_height_m
            )

            OR (
                edge.max_width_m IS NOT NULL
                AND vehicle_record.width_m > edge.max_width_m
            )

            OR (
                edge.max_length_m IS NOT NULL
                AND vehicle_record.length_m > edge.max_length_m
            )

            OR (
                edge.max_weight_t IS NOT NULL
                AND vehicle_record.gross_mass_t > edge.max_weight_t
            )
        ),

        CASE
            WHEN edge.motor_vehicle_allowed = FALSE
                THEN 'MOTOR_VEHICLE_PROHIBITED'

            WHEN vehicle_record.requires_hgv_access
                 AND edge.hgv_allowed = FALSE
                THEN 'HGV_PROHIBITED'

            WHEN vehicle_record.carries_dangerous_goods
                 AND edge.hazmat_allowed = FALSE
                THEN 'HAZMAT_PROHIBITED'

            WHEN edge.max_height_m IS NOT NULL
                 AND vehicle_record.height_m > edge.max_height_m
                THEN 'HEIGHT_EXCEEDED'

            WHEN edge.max_width_m IS NOT NULL
                 AND vehicle_record.width_m > edge.max_width_m
                THEN 'WIDTH_EXCEEDED'

            WHEN edge.max_length_m IS NOT NULL
                 AND vehicle_record.length_m > edge.max_length_m
                THEN 'LENGTH_EXCEEDED'

            WHEN edge.max_weight_t IS NOT NULL
                 AND vehicle_record.gross_mass_t > edge.max_weight_t
                THEN 'WEIGHT_EXCEEDED'

            WHEN edge.motor_vehicle_allowed IS NULL
                THEN 'MOTOR_VEHICLE_ACCESS_UNSPECIFIED'

            WHEN vehicle_record.requires_hgv_access
                 AND edge.hgv_allowed IS NULL
                THEN 'HGV_ACCESS_UNSPECIFIED'

            WHEN vehicle_record.carries_dangerous_goods
                 AND edge.hazmat_allowed IS NULL
                THEN 'HAZMAT_ACCESS_UNSPECIFIED'

            ELSE 'COMPATIBLE'
        END,

        ARRAY_REMOVE(
            ARRAY[
                CASE
                    WHEN edge.motor_vehicle_allowed = FALSE
                    THEN 'MOTOR_VEHICLE_PROHIBITED'
                END,

                CASE
                    WHEN vehicle_record.requires_hgv_access
                         AND edge.hgv_allowed = FALSE
                    THEN 'HGV_PROHIBITED'
                END,

                CASE
                    WHEN vehicle_record.carries_dangerous_goods
                         AND edge.hazmat_allowed = FALSE
                    THEN 'HAZMAT_PROHIBITED'
                END,

                CASE
                    WHEN edge.max_height_m IS NOT NULL
                         AND vehicle_record.height_m > edge.max_height_m
                    THEN 'HEIGHT_EXCEEDED'
                END,

                CASE
                    WHEN edge.max_width_m IS NOT NULL
                         AND vehicle_record.width_m > edge.max_width_m
                    THEN 'WIDTH_EXCEEDED'
                END,

                CASE
                    WHEN edge.max_length_m IS NOT NULL
                         AND vehicle_record.length_m > edge.max_length_m
                    THEN 'LENGTH_EXCEEDED'
                END,

                CASE
                    WHEN edge.max_weight_t IS NOT NULL
                         AND vehicle_record.gross_mass_t > edge.max_weight_t
                    THEN 'WEIGHT_EXCEEDED'
                END
            ],
            NULL
        ),

        ARRAY_REMOVE(
            ARRAY[
                CASE
                    WHEN edge.motor_vehicle_allowed IS NULL
                    THEN 'MOTOR_VEHICLE_ACCESS_UNSPECIFIED'
                END,

                CASE
                    WHEN vehicle_record.requires_hgv_access
                         AND edge.hgv_allowed IS NULL
                    THEN 'HGV_ACCESS_UNSPECIFIED'
                END,

                CASE
                    WHEN vehicle_record.carries_dangerous_goods
                         AND edge.hazmat_allowed IS NULL
                    THEN 'HAZMAT_ACCESS_UNSPECIFIED'
                END
            ],
            NULL
        ),

        edge.max_height_m,
        edge.max_width_m,
        edge.max_length_m,
        edge.max_weight_t

    FROM hvn.routing_edge AS edge

    WHERE
        p_only_blocked = FALSE

        OR edge.motor_vehicle_allowed = FALSE

        OR (
            vehicle_record.requires_hgv_access
            AND edge.hgv_allowed = FALSE
        )

        OR (
            vehicle_record.carries_dangerous_goods
            AND edge.hazmat_allowed = FALSE
        )

        OR (
            edge.max_height_m IS NOT NULL
            AND vehicle_record.height_m > edge.max_height_m
        )

        OR (
            edge.max_width_m IS NOT NULL
            AND vehicle_record.width_m > edge.max_width_m
        )

        OR (
            edge.max_length_m IS NOT NULL
            AND vehicle_record.length_m > edge.max_length_m
        )

        OR (
            edge.max_weight_t IS NOT NULL
            AND vehicle_record.gross_mass_t > edge.max_weight_t
        );
END;
$$;


-------------------------------------------------------------------------------
-- 3. Documentation
-------------------------------------------------------------------------------

COMMENT ON FUNCTION hvn.get_routable_edges_for_vehicle(BIGINT) IS
    'Returns routing edges not blocked by known restrictions for the selected active vehicle profile.';

COMMENT ON FUNCTION hvn.get_edge_compatibility_report(BIGINT, BOOLEAN) IS
    'Returns set-based compatibility status, reasons and warnings for routing edges against one vehicle profile.';


COMMIT;
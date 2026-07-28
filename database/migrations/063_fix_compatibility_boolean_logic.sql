/*
===============================================================================
Migration: 063_fix_compatibility_boolean_logic.sql

Purpose:
    Make the set-based compatibility report Boolean evaluation null-safe.

Dependencies:
    - hvn.routing_edge
    - hvn.vehicle_profile
    - Migration 062

===============================================================================
*/

BEGIN;


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
    WITH evaluated AS
    (
        SELECT
            edge.*,

            (
                edge.motor_vehicle_allowed IS FALSE

                OR (
                    vehicle_record.requires_hgv_access
                    AND edge.hgv_allowed IS FALSE
                )

                OR (
                    vehicle_record.carries_dangerous_goods
                    AND edge.hazmat_allowed IS FALSE
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
            ) AS is_blocked,

            (
                edge.motor_vehicle_allowed IS NULL

                OR (
                    vehicle_record.requires_hgv_access
                    AND edge.hgv_allowed IS NULL
                )

                OR (
                    vehicle_record.carries_dangerous_goods
                    AND edge.hazmat_allowed IS NULL
                )
            ) AS has_access_warnings

        FROM hvn.routing_edge AS edge
    )

    SELECT
        edge.edge_id,
        edge.road_name,
        edge.road_ref,
        edge.road_class,

        CASE
            WHEN edge.is_blocked
                THEN 'BLOCKED'

            WHEN edge.has_access_warnings
                THEN 'PASS_WITH_WARNINGS'

            ELSE 'PASS'
        END AS assessment_status,

        NOT edge.is_blocked AS is_routable,

        CASE
            WHEN edge.motor_vehicle_allowed IS FALSE
                THEN 'MOTOR_VEHICLE_PROHIBITED'

            WHEN vehicle_record.requires_hgv_access
                 AND edge.hgv_allowed IS FALSE
                THEN 'HGV_PROHIBITED'

            WHEN vehicle_record.carries_dangerous_goods
                 AND edge.hazmat_allowed IS FALSE
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
        END AS primary_reason,

        ARRAY_REMOVE(
            ARRAY[
                CASE
                    WHEN edge.motor_vehicle_allowed IS FALSE
                    THEN 'MOTOR_VEHICLE_PROHIBITED'
                END,

                CASE
                    WHEN vehicle_record.requires_hgv_access
                         AND edge.hgv_allowed IS FALSE
                    THEN 'HGV_PROHIBITED'
                END,

                CASE
                    WHEN vehicle_record.carries_dangerous_goods
                         AND edge.hazmat_allowed IS FALSE
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
        ) AS reasons,

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
        ) AS warnings,

        edge.max_height_m,
        edge.max_width_m,
        edge.max_length_m,
        edge.max_weight_t

    FROM evaluated AS edge
    WHERE
        p_only_blocked = FALSE
        OR edge.is_blocked;
END;
$$;


COMMENT ON FUNCTION hvn.get_edge_compatibility_report(BIGINT, BOOLEAN) IS
    'Returns null-safe set-based compatibility status, routing decision, reasons and warnings for routing edges against one vehicle profile.';


COMMIT;
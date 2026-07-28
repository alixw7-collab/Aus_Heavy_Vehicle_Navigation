/*
===============================================================================
Migration: 061_evaluate_edge_vehicle_compatibility.sql

Purpose:
    Evaluate whether a vehicle profile is compatible with an individual
    routing edge.

Design principles:
    - Return an explainable assessment.
    - Separate hard prohibitions from incomplete source data.
    - Do not treat missing OSM restrictions as proof of legal access.
    - Do not create a materialised compatibility table containing every
      vehicle-by-edge combination.
    - Preserve routing performance by providing a lightweight Boolean helper.

Dependencies:
    - hvn.routing_edge
    - hvn.vehicle_profile

===============================================================================
*/

BEGIN;


-------------------------------------------------------------------------------
-- 1. Detailed compatibility evaluator
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hvn.evaluate_edge_vehicle_compatibility
(
    p_edge_id BIGINT,
    p_vehicle_profile_id BIGINT
)
RETURNS TABLE
(
    edge_id BIGINT,
    vehicle_profile_id BIGINT,

    assessment_status TEXT,
    is_routable BOOLEAN,
    has_warnings BOOLEAN,

    primary_reason TEXT,
    reasons TEXT[],
    warnings TEXT[],

    vehicle_height_m NUMERIC,
    edge_max_height_m NUMERIC,

    vehicle_width_m NUMERIC,
    edge_max_width_m NUMERIC,

    vehicle_length_m NUMERIC,
    edge_max_length_m NUMERIC,

    vehicle_gross_mass_t NUMERIC,
    edge_max_weight_t NUMERIC,

    motor_vehicle_allowed BOOLEAN,
    hgv_allowed BOOLEAN,
    hazmat_allowed BOOLEAN
)
LANGUAGE plpgsql
STABLE
PARALLEL SAFE
AS $$
DECLARE
    edge_record hvn.routing_edge%ROWTYPE;
    vehicle_record hvn.vehicle_profile%ROWTYPE;

    failure_reasons TEXT[] := ARRAY[]::TEXT[];
    warning_reasons TEXT[] := ARRAY[]::TEXT[];
BEGIN
    ---------------------------------------------------------------------------
    -- Load edge
    ---------------------------------------------------------------------------

    SELECT *
    INTO edge_record
    FROM hvn.routing_edge AS routing_edge
    WHERE routing_edge.edge_id = p_edge_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Routing edge % does not exist.',
            p_edge_id
            USING ERRCODE = 'P0002';
    END IF;


    ---------------------------------------------------------------------------
    -- Load vehicle profile
    ---------------------------------------------------------------------------

    SELECT *
    INTO vehicle_record
    FROM hvn.vehicle_profile AS vehicle_profile
    WHERE vehicle_profile.vehicle_profile_id = p_vehicle_profile_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Vehicle profile % does not exist.',
            p_vehicle_profile_id
            USING ERRCODE = 'P0002';
    END IF;


    ---------------------------------------------------------------------------
    -- Profile availability
    ---------------------------------------------------------------------------

    IF vehicle_record.is_active = FALSE THEN
        failure_reasons :=
            ARRAY_APPEND(
                failure_reasons,
                'VEHICLE_PROFILE_INACTIVE'
            );
    END IF;


    ---------------------------------------------------------------------------
    -- General motor-vehicle access
    ---------------------------------------------------------------------------

    IF edge_record.motor_vehicle_allowed = FALSE THEN
        failure_reasons :=
            ARRAY_APPEND(
                failure_reasons,
                'MOTOR_VEHICLE_PROHIBITED'
            );

    ELSIF edge_record.motor_vehicle_allowed IS NULL THEN
        warning_reasons :=
            ARRAY_APPEND(
                warning_reasons,
                'MOTOR_VEHICLE_ACCESS_UNSPECIFIED'
            );
    END IF;


    ---------------------------------------------------------------------------
    -- Heavy-goods-vehicle access
    ---------------------------------------------------------------------------

    IF vehicle_record.requires_hgv_access THEN
        IF edge_record.hgv_allowed = FALSE THEN
            failure_reasons :=
                ARRAY_APPEND(
                    failure_reasons,
                    'HGV_PROHIBITED'
                );

        ELSIF edge_record.hgv_allowed IS NULL THEN
            warning_reasons :=
                ARRAY_APPEND(
                    warning_reasons,
                    'HGV_ACCESS_UNSPECIFIED'
                );
        END IF;
    END IF;


    ---------------------------------------------------------------------------
    -- Dangerous-goods access
    ---------------------------------------------------------------------------

    IF vehicle_record.carries_dangerous_goods THEN
        IF edge_record.hazmat_allowed = FALSE THEN
            failure_reasons :=
                ARRAY_APPEND(
                    failure_reasons,
                    'HAZMAT_PROHIBITED'
                );

        ELSIF edge_record.hazmat_allowed IS NULL THEN
            warning_reasons :=
                ARRAY_APPEND(
                    warning_reasons,
                    'HAZMAT_ACCESS_UNSPECIFIED'
                );
        END IF;
    END IF;


    ---------------------------------------------------------------------------
    -- Physical restrictions
    --
    -- Equality is permitted:
    --     vehicle height 4.300 m
    --     posted maximum 4.300 m
    --
    -- Operational safety margins can be introduced later as explicit vehicle
    -- profile or routing-policy parameters. No hidden margin is applied here.
    ---------------------------------------------------------------------------

    IF edge_record.max_height_m IS NOT NULL
       AND vehicle_record.height_m > edge_record.max_height_m
    THEN
        failure_reasons :=
            ARRAY_APPEND(
                failure_reasons,
                'HEIGHT_EXCEEDED'
            );
    END IF;


    IF edge_record.max_width_m IS NOT NULL
       AND vehicle_record.width_m > edge_record.max_width_m
    THEN
        failure_reasons :=
            ARRAY_APPEND(
                failure_reasons,
                'WIDTH_EXCEEDED'
            );
    END IF;


    IF edge_record.max_length_m IS NOT NULL
       AND vehicle_record.length_m > edge_record.max_length_m
    THEN
        failure_reasons :=
            ARRAY_APPEND(
                failure_reasons,
                'LENGTH_EXCEEDED'
            );
    END IF;


    IF edge_record.max_weight_t IS NOT NULL
       AND vehicle_record.gross_mass_t > edge_record.max_weight_t
    THEN
        failure_reasons :=
            ARRAY_APPEND(
                failure_reasons,
                'WEIGHT_EXCEEDED'
            );
    END IF;


    ---------------------------------------------------------------------------
    -- Return assessment
    ---------------------------------------------------------------------------

    RETURN QUERY
    SELECT
        edge_record.edge_id,
        vehicle_record.vehicle_profile_id,

        CASE
            WHEN CARDINALITY(failure_reasons) > 0
                THEN 'BLOCKED'

            WHEN CARDINALITY(warning_reasons) > 0
                THEN 'PASS_WITH_WARNINGS'

            ELSE 'PASS'
        END AS assessment_status,

        CARDINALITY(failure_reasons) = 0 AS is_routable,

        CARDINALITY(warning_reasons) > 0 AS has_warnings,

        CASE
            WHEN CARDINALITY(failure_reasons) > 0
                THEN failure_reasons[1]

            WHEN CARDINALITY(warning_reasons) > 0
                THEN warning_reasons[1]

            ELSE 'COMPATIBLE'
        END AS primary_reason,

        failure_reasons,
        warning_reasons,

        vehicle_record.height_m,
        edge_record.max_height_m,

        vehicle_record.width_m,
        edge_record.max_width_m,

        vehicle_record.length_m,
        edge_record.max_length_m,

        vehicle_record.gross_mass_t,
        edge_record.max_weight_t,

        edge_record.motor_vehicle_allowed,
        edge_record.hgv_allowed,
        edge_record.hazmat_allowed;
END;
$$;


-------------------------------------------------------------------------------
-- 2. Lightweight routing helper
--
-- This helper returns TRUE when no known restriction blocks the vehicle.
-- Missing or unspecified access data produces warnings in the detailed
-- evaluator but does not make the edge unusable at this stage.
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hvn.edge_is_routable_for_vehicle
(
    p_edge_id BIGINT,
    p_vehicle_profile_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    SELECT evaluation.is_routable
    FROM hvn.evaluate_edge_vehicle_compatibility(
        p_edge_id,
        p_vehicle_profile_id
    ) AS evaluation;
$$;


-------------------------------------------------------------------------------
-- 3. Documentation
-------------------------------------------------------------------------------

COMMENT ON FUNCTION hvn.evaluate_edge_vehicle_compatibility(BIGINT, BIGINT) IS
    'Returns an explainable compatibility assessment between one routing edge and one vehicle profile.';

COMMENT ON FUNCTION hvn.edge_is_routable_for_vehicle(BIGINT, BIGINT) IS
    'Returns TRUE when no known edge restriction blocks the selected vehicle profile.';


COMMIT;
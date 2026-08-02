/*
===============================================================================
Project RoadTrain
Migration 098: Remove redundant route geometry join
===============================================================================

Purpose:
    Simplify hvn.route_between_coordinates() by reusing the directional
    geometry already returned by hvn.calculate_vehicle_route().

Reason:
    calculate_vehicle_route() already:
        - joins hvn.routing_edge;
        - determines travel direction;
        - reverses edge geometry where required;
        - returns the correctly oriented geometry.

    route_between_coordinates() was joining hvn.routing_edge a second time
    and repeating that geometry logic unnecessarily.
===============================================================================
*/

BEGIN;

CREATE OR REPLACE FUNCTION hvn.route_between_coordinates(
    p_start_latitude DOUBLE PRECISION,
    p_start_longitude DOUBLE PRECISION,
    p_end_latitude DOUBLE PRECISION,
    p_end_longitude DOUBLE PRECISION,
    p_vehicle_profile_id BIGINT,
    p_corridor_metres DOUBLE PRECISION DEFAULT 50000
)
RETURNS TABLE (
    route_sequence INTEGER,
    path_sequence INTEGER,
    node_id BIGINT,
    edge_id BIGINT,
    source_node_id BIGINT,
    target_node_id BIGINT,
    road_name TEXT,
    road_ref TEXT,
    road_class TEXT,
    edge_cost DOUBLE PRECISION,
    aggregate_cost DOUBLE PRECISION,
    edge_length_metres DOUBLE PRECISION,
    cumulative_length_metres DOUBLE PRECISION,
    edge_travel_time_seconds DOUBLE PRECISION,
    cumulative_travel_time_seconds DOUBLE PRECISION,
    traversed_forward BOOLEAN,
    geom geometry
)
LANGUAGE plpgsql
STABLE
PARALLEL RESTRICTED
AS $function$
DECLARE
    v_start_node_id BIGINT;
    v_end_node_id BIGINT;
BEGIN
    ---------------------------------------------------------------------------
    -- Validate coordinate ranges
    ---------------------------------------------------------------------------

    IF p_start_latitude IS NULL
       OR p_start_latitude < -90
       OR p_start_latitude > 90
    THEN
        RAISE EXCEPTION
            'Invalid start latitude: %. Latitude must be between -90 and 90.',
            p_start_latitude;
    END IF;

    IF p_start_longitude IS NULL
       OR p_start_longitude < -180
       OR p_start_longitude > 180
    THEN
        RAISE EXCEPTION
            'Invalid start longitude: %. Longitude must be between -180 and 180.',
            p_start_longitude;
    END IF;

    IF p_end_latitude IS NULL
       OR p_end_latitude < -90
       OR p_end_latitude > 90
    THEN
        RAISE EXCEPTION
            'Invalid destination latitude: %. Latitude must be between -90 and 90.',
            p_end_latitude;
    END IF;

    IF p_end_longitude IS NULL
       OR p_end_longitude < -180
       OR p_end_longitude > 180
    THEN
        RAISE EXCEPTION
            'Invalid destination longitude: %. Longitude must be between -180 and 180.',
            p_end_longitude;
    END IF;

    IF p_vehicle_profile_id IS NULL THEN
        RAISE EXCEPTION
            'Vehicle profile ID cannot be null.';
    END IF;

    IF p_corridor_metres IS NULL
       OR p_corridor_metres <= 0
    THEN
        RAISE EXCEPTION
            'Routing corridor must be greater than zero metres. Supplied value: %',
            p_corridor_metres;
    END IF;


    ---------------------------------------------------------------------------
    -- Confirm vehicle profile exists
    ---------------------------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM hvn.vehicle_profile AS vehicle
        WHERE vehicle.vehicle_profile_id = p_vehicle_profile_id
    )
    THEN
        RAISE EXCEPTION
            'Vehicle profile % does not exist.',
            p_vehicle_profile_id;
    END IF;


    ---------------------------------------------------------------------------
    -- Snap coordinates to routing nodes
    ---------------------------------------------------------------------------

    SELECT nearest.node_id
    INTO v_start_node_id
    FROM hvn.find_nearest_routing_node(
        p_start_latitude,
        p_start_longitude
    ) AS nearest;

    SELECT nearest.node_id
    INTO v_end_node_id
    FROM hvn.find_nearest_routing_node(
        p_end_latitude,
        p_end_longitude
    ) AS nearest;


    ---------------------------------------------------------------------------
    -- Validate snapped nodes
    ---------------------------------------------------------------------------

    IF v_start_node_id IS NULL THEN
        RAISE EXCEPTION
            'No routing node was found for start coordinate: latitude %, longitude %.',
            p_start_latitude,
            p_start_longitude;
    END IF;

    IF v_end_node_id IS NULL THEN
        RAISE EXCEPTION
            'No routing node was found for destination coordinate: latitude %, longitude %.',
            p_end_latitude,
            p_end_longitude;
    END IF;

    IF v_start_node_id = v_end_node_id THEN
        RAISE EXCEPTION
            'Start and destination coordinates resolve to the same routing node: %.',
            v_start_node_id;
    END IF;


    ---------------------------------------------------------------------------
    -- Return route directly
    --
    -- Geometry is already directionally aligned by calculate_vehicle_route().
    ---------------------------------------------------------------------------

    RETURN QUERY
    SELECT
        route.route_sequence,
        route.path_sequence,
        route.node_id,
        route.edge_id,
        route.source_node_id,
        route.target_node_id,
        route.road_name,
        route.road_ref,
        route.road_class,
        route.edge_cost,
        route.aggregate_cost,
        route.edge_length_metres,
        route.cumulative_length_metres,
        route.edge_travel_time_seconds,
        route.cumulative_travel_time_seconds,
        route.traversed_forward,
        route.geom

    FROM hvn.calculate_vehicle_route(
        v_start_node_id,
        v_end_node_id,
        p_vehicle_profile_id,
        p_corridor_metres
    ) AS route

    ORDER BY route.route_sequence;
END;
$function$;


COMMENT ON FUNCTION hvn.route_between_coordinates(
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    BIGINT,
    DOUBLE PRECISION
)
IS
'Snaps WGS84 coordinates to graph nodes and returns the vehicle-compatible route using geometry already oriented by calculate_vehicle_route().';

COMMIT;
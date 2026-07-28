/*
===============================================================================
Project RoadTrain
Migration 083: Calculate vehicle route from GPS coordinates
===============================================================================

Purpose:
    Provide a GPS-coordinate interface for the existing vehicle-aware routing
    engine.

Process:
    1. Find the nearest routing node to the start coordinate.
    2. Find the nearest routing node to the destination coordinate.
    3. Pass those node IDs to hvn.calculate_vehicle_route().
    4. Return the ordered route geometry and route metadata.

Coordinate System:
    Input coordinates are WGS84 latitude and longitude values (EPSG:4326).
===============================================================================
*/

BEGIN;

CREATE OR REPLACE FUNCTION hvn.calculate_vehicle_route_gps(
    p_start_latitude DOUBLE PRECISION,
    p_start_longitude DOUBLE PRECISION,
    p_end_latitude DOUBLE PRECISION,
    p_end_longitude DOUBLE PRECISION,
    p_vehicle_profile_id BIGINT,
    p_corridor_metres DOUBLE PRECISION DEFAULT 50000
)
RETURNS TABLE (
    route_sequence INTEGER,
    route_node BIGINT,
    edge_id BIGINT,
    source_node_id BIGINT,
    target_node_id BIGINT,
    road_name TEXT,
    road_ref TEXT,
    road_class TEXT,
    edge_cost DOUBLE PRECISION,
    cumulative_distance_metres DOUBLE PRECISION,
    cumulative_travel_time_seconds DOUBLE PRECISION,
    geom geometry
)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_start_node_id BIGINT;
    v_end_node_id BIGINT;
BEGIN
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

    IF v_start_node_id IS NULL THEN
        RAISE EXCEPTION
            'No routing node found near start coordinate: latitude %, longitude %',
            p_start_latitude,
            p_start_longitude;
    END IF;

    IF v_end_node_id IS NULL THEN
        RAISE EXCEPTION
            'No routing node found near destination coordinate: latitude %, longitude %',
            p_end_latitude,
            p_end_longitude;
    END IF;

    RETURN QUERY
    SELECT
        route.route_sequence,
        route.route_node,
        route.edge_id,
        route.source_node_id,
        route.target_node_id,
        route.road_name,
        route.road_ref,
        route.road_class,
        route.edge_cost,
        route.cumulative_distance_metres,
        route.cumulative_travel_time_seconds,
        route.geom
    FROM hvn.calculate_vehicle_route(
        v_start_node_id,
        v_end_node_id,
        p_vehicle_profile_id,
        p_corridor_metres
    ) AS route;
END;
$function$;

COMMENT ON FUNCTION hvn.calculate_vehicle_route_gps(
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    BIGINT,
    DOUBLE PRECISION
)
IS
'Calculates a vehicle-aware route between two WGS84 GPS coordinates by snapping each coordinate to the nearest routing graph node.';

COMMIT;
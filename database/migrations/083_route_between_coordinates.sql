/*
===============================================================================
Project RoadTrain
Migration 083: Route between GPS coordinates
===============================================================================

Purpose:
    Provide a coordinate-based interface to the Project RoadTrain routing
    engine.

Process:
    1. Snap the supplied start coordinate to the nearest routing node.
    2. Snap the supplied destination coordinate to the nearest routing node.
    3. Call hvn.calculate_vehicle_route().
    4. Join each route step to hvn.routing_edge.
    5. Return route geometry in the direction of travel.

Coordinate system:
    Input coordinates use WGS84 latitude and longitude values (EPSG:4326).

Geometry:
    Edge geometry is reversed when the route traverses an edge from its target
    node toward its source node.
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
    /*
     * Validate coordinate ranges before attempting spatial searches.
     */
    IF p_start_latitude IS NULL
       OR p_start_latitude < -90
       OR p_start_latitude > 90 THEN
        RAISE EXCEPTION
            'Invalid start latitude: %. Latitude must be between -90 and 90.',
            p_start_latitude;
    END IF;

    IF p_start_longitude IS NULL
       OR p_start_longitude < -180
       OR p_start_longitude > 180 THEN
        RAISE EXCEPTION
            'Invalid start longitude: %. Longitude must be between -180 and 180.',
            p_start_longitude;
    END IF;

    IF p_end_latitude IS NULL
       OR p_end_latitude < -90
       OR p_end_latitude > 90 THEN
        RAISE EXCEPTION
            'Invalid destination latitude: %. Latitude must be between -90 and 90.',
            p_end_latitude;
    END IF;

    IF p_end_longitude IS NULL
       OR p_end_longitude < -180
       OR p_end_longitude > 180 THEN
        RAISE EXCEPTION
            'Invalid destination longitude: %. Longitude must be between -180 and 180.',
            p_end_longitude;
    END IF;

    IF p_vehicle_profile_id IS NULL THEN
        RAISE EXCEPTION 'Vehicle profile ID cannot be null.';
    END IF;

    IF p_corridor_metres IS NULL OR p_corridor_metres <= 0 THEN
        RAISE EXCEPTION
            'Routing corridor must be greater than zero metres. Supplied value: %',
            p_corridor_metres;
    END IF;

    /*
     * Confirm that the requested vehicle profile exists.
     */
    IF NOT EXISTS (
        SELECT 1
        FROM hvn.vehicle_profile vp
        WHERE vp.vehicle_profile_id = p_vehicle_profile_id
    ) THEN
        RAISE EXCEPTION
            'Vehicle profile % does not exist.',
            p_vehicle_profile_id;
    END IF;

    /*
     * Snap the start coordinate to the routing graph.
     */
    SELECT nearest.node_id
    INTO v_start_node_id
    FROM hvn.find_nearest_routing_node(
        p_start_latitude,
        p_start_longitude
    ) AS nearest;

    /*
     * Snap the destination coordinate to the routing graph.
     */
    SELECT nearest.node_id
    INTO v_end_node_id
    FROM hvn.find_nearest_routing_node(
        p_end_latitude,
        p_end_longitude
    ) AS nearest;

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

    /*
     * Run the vehicle-aware route calculation and attach directional geometry.
     *
     * pgRouting normally returns a final destination record with edge_id = -1.
     * The LEFT JOIN preserves that record, while its geometry remains null.
     */
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

        CASE
            WHEN edge.geom IS NULL THEN NULL
            WHEN route.traversed_forward IS FALSE
                THEN ST_Reverse(edge.geom)
            ELSE edge.geom
        END AS geom

    FROM hvn.calculate_vehicle_route(
        v_start_node_id,
        v_end_node_id,
        p_vehicle_profile_id,
        p_corridor_metres
    ) AS route

    LEFT JOIN hvn.routing_edge AS edge
        ON edge.edge_id = route.edge_id

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
'Calculates a vehicle-compatible route between two WGS84 coordinates and returns ordered, directionally aligned edge geometry.';

COMMIT;
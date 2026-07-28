/*
===============================================================================
Project RoadTrain
Migration 082: Find nearest routing node
===============================================================================

Purpose:
    Convert a WGS84 GPS latitude/longitude coordinate into the nearest routing
    graph node.

Performance:
    The nearest candidate is selected using the GiST spatial index and the
    PostGIS KNN <-> operator.

Returns:
    - node ID
    - node longitude
    - node latitude
    - distance from the supplied coordinate in metres
===============================================================================
*/

BEGIN;

CREATE OR REPLACE FUNCTION hvn.find_nearest_routing_node(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION
)
RETURNS TABLE (
    node_id BIGINT,
    longitude DOUBLE PRECISION,
    latitude DOUBLE PRECISION,
    distance_metres DOUBLE PRECISION
)
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $function$

    SELECT
        rn.node_id,
        rn.longitude,
        rn.latitude,
        ST_DistanceSphere(
            rn.geom,
            ST_SetSRID(
                ST_MakePoint(p_longitude, p_latitude),
                4326
            )
        ) AS distance_metres
    FROM hvn.routing_node AS rn
    ORDER BY rn.geom <-> ST_SetSRID(
        ST_MakePoint(p_longitude, p_latitude),
        4326
    )
    LIMIT 1;

$function$;

COMMENT ON FUNCTION hvn.find_nearest_routing_node(
    DOUBLE PRECISION,
    DOUBLE PRECISION
)
IS
'Returns the nearest routing graph node to a supplied WGS84 latitude and longitude coordinate.';

COMMIT;
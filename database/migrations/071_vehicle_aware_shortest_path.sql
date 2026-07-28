/*
===============================================================================
Migration: 071_vehicle_aware_shortest_path.sql

Purpose:
    Calculate a vehicle-aware shortest path between two routing nodes.

Dependencies:
    - pgRouting
    - PostGIS
    - hvn.routing_edge
    - hvn.vehicle_profile
    - Migration 063

Notes:
    - The route is optimised using routing_edge.cost.
    - Known incompatible edges are excluded.
    - Missing restriction information does not automatically exclude an edge.
    - The search graph is limited to a corridor around the straight line
      between the start and destination nodes.
    - EPSG:3577 is used for metre-based Australian corridor buffering.

===============================================================================
*/

BEGIN;


CREATE OR REPLACE FUNCTION hvn.calculate_vehicle_route
(
    p_start_node_id BIGINT,
    p_end_node_id BIGINT,
    p_vehicle_profile_id BIGINT,
    p_corridor_metres DOUBLE PRECISION DEFAULT 50000
)
RETURNS TABLE
(
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
VOLATILE
PARALLEL UNSAFE
AS $$
DECLARE
    vehicle_record hvn.vehicle_profile%ROWTYPE;

    start_point geometry;
    end_point geometry;
    corridor_geom geometry;

    edge_sql TEXT;

    routing_srid INTEGER;
BEGIN
    ---------------------------------------------------------------------------
    -- Validate basic parameters
    ---------------------------------------------------------------------------

    IF p_start_node_id IS NULL THEN
        RAISE EXCEPTION
            'Start node ID must not be NULL.'
            USING ERRCODE = '22004';
    END IF;

    IF p_end_node_id IS NULL THEN
        RAISE EXCEPTION
            'End node ID must not be NULL.'
            USING ERRCODE = '22004';
    END IF;

    IF p_start_node_id = p_end_node_id THEN
        RAISE EXCEPTION
            'Start node and destination node must be different.'
            USING ERRCODE = '22023';
    END IF;

    IF p_corridor_metres IS NULL
       OR p_corridor_metres <= 0
    THEN
        RAISE EXCEPTION
            'Routing corridor must be greater than zero metres.'
            USING ERRCODE = '22023';
    END IF;


    ---------------------------------------------------------------------------
    -- Load and validate vehicle profile
    ---------------------------------------------------------------------------

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


    ---------------------------------------------------------------------------
    -- Determine routing geometry SRID
    ---------------------------------------------------------------------------

    SELECT ST_SRID(edge.geom)
    INTO routing_srid
    FROM hvn.routing_edge AS edge
    WHERE edge.geom IS NOT NULL
    LIMIT 1;

    IF routing_srid IS NULL OR routing_srid = 0 THEN
        RAISE EXCEPTION
            'Unable to determine the SRID of hvn.routing_edge.geom.';
    END IF;


    ---------------------------------------------------------------------------
    -- Resolve the start-node coordinate
    --
    -- A node may occur as either the source or target of an edge.
    ---------------------------------------------------------------------------

    SELECT candidate.point_geom
    INTO start_point
    FROM
    (
        SELECT ST_StartPoint(edge.geom) AS point_geom
        FROM hvn.routing_edge AS edge
        WHERE edge.source_node_id = p_start_node_id
          AND edge.geom IS NOT NULL

        UNION ALL

        SELECT ST_EndPoint(edge.geom) AS point_geom
        FROM hvn.routing_edge AS edge
        WHERE edge.target_node_id = p_start_node_id
          AND edge.geom IS NOT NULL
    ) AS candidate
    LIMIT 1;

    IF start_point IS NULL THEN
        RAISE EXCEPTION
            'Start node % does not exist in the routing graph.',
            p_start_node_id
            USING ERRCODE = 'P0002';
    END IF;


    ---------------------------------------------------------------------------
    -- Resolve the destination-node coordinate
    ---------------------------------------------------------------------------

    SELECT candidate.point_geom
    INTO end_point
    FROM
    (
        SELECT ST_StartPoint(edge.geom) AS point_geom
        FROM hvn.routing_edge AS edge
        WHERE edge.source_node_id = p_end_node_id
          AND edge.geom IS NOT NULL

        UNION ALL

        SELECT ST_EndPoint(edge.geom) AS point_geom
        FROM hvn.routing_edge AS edge
        WHERE edge.target_node_id = p_end_node_id
          AND edge.geom IS NOT NULL
    ) AS candidate
    LIMIT 1;

    IF end_point IS NULL THEN
        RAISE EXCEPTION
            'Destination node % does not exist in the routing graph.',
            p_end_node_id
            USING ERRCODE = 'P0002';
    END IF;


    ---------------------------------------------------------------------------
    -- Construct routing corridor
    --
    -- EPSG:3577 provides metre-based Australian Albers coordinates.
    -- The resulting corridor is transformed back to the routing graph SRID.
    ---------------------------------------------------------------------------

    corridor_geom :=
        ST_Transform(
            ST_Buffer(
                ST_Transform(
                    ST_MakeLine(
                        ST_Force2D(start_point),
                        ST_Force2D(end_point)
                    ),
                    3577
                ),
                p_corridor_metres
            ),
            routing_srid
        );


    ---------------------------------------------------------------------------
    -- Construct pgRouting edge SQL
    --
    -- %L safely inserts SQL literal values.
    ---------------------------------------------------------------------------

    edge_sql := FORMAT(
        $routing_sql$
            SELECT
                edge.edge_id AS id,
                edge.source_node_id AS source,
                edge.target_node_id AS target,
                edge.cost::FLOAT8 AS cost,
                edge.reverse_cost::FLOAT8 AS reverse_cost
            FROM hvn.routing_edge AS edge
            WHERE
                edge.geom && ST_GeomFromEWKT(%L)

                AND ST_Intersects(
                    edge.geom,
                    ST_GeomFromEWKT(%L)
                )

                AND edge.motor_vehicle_allowed IS DISTINCT FROM FALSE

                AND (
                    %L::BOOLEAN = FALSE
                    OR edge.hgv_allowed IS DISTINCT FROM FALSE
                )

                AND (
                    %L::BOOLEAN = FALSE
                    OR edge.hazmat_allowed IS DISTINCT FROM FALSE
                )

                AND (
                    edge.max_height_m IS NULL
                    OR %L::NUMERIC <= edge.max_height_m
                )

                AND (
                    edge.max_width_m IS NULL
                    OR %L::NUMERIC <= edge.max_width_m
                )

                AND (
                    edge.max_length_m IS NULL
                    OR %L::NUMERIC <= edge.max_length_m
                )

                AND (
                    edge.max_weight_t IS NULL
                    OR %L::NUMERIC <= edge.max_weight_t
                )

                AND edge.cost >= 0

                AND (
                    edge.reverse_cost >= 0
                    OR edge.reverse_cost = -1
                )
        $routing_sql$,

        ST_AsEWKT(corridor_geom),
        ST_AsEWKT(corridor_geom),

        vehicle_record.requires_hgv_access,
        vehicle_record.carries_dangerous_goods,

        vehicle_record.height_m,
        vehicle_record.width_m,
        vehicle_record.length_m,
        vehicle_record.gross_mass_t
    );


    ---------------------------------------------------------------------------
    -- Execute shortest-path calculation
    --
    -- pgRouting returns a final terminal row with edge = -1.
    -- That terminal row is excluded from the edge result.
    ---------------------------------------------------------------------------

    RETURN QUERY
    WITH route_path AS
    (
        SELECT
            route.seq,
            route.path_seq,
            route.node,
            route.edge,
            route.cost,
            route.agg_cost
        FROM pgr_dijkstra(
            edge_sql,
            p_start_node_id,
            p_end_node_id,
            directed := TRUE
        ) AS route
        WHERE route.edge <> -1
    ),

    route_edges AS
    (
        SELECT
            path.seq,
            path.path_seq,
            path.node,
            path.edge,
            path.cost,
            path.agg_cost,

            edge.source_node_id,
            edge.target_node_id,

            edge.road_name,
            edge.road_ref,
            edge.road_class,

            edge.length_metres::DOUBLE PRECISION
                AS edge_length_metres,

            edge.travel_time_seconds::DOUBLE PRECISION
                AS edge_travel_time_seconds,

            path.node = edge.source_node_id
                AS traversed_forward,

            CASE
                WHEN path.node = edge.source_node_id
                    THEN edge.geom
                ELSE ST_Reverse(edge.geom)
            END AS route_geom

        FROM route_path AS path
        JOIN hvn.routing_edge AS edge
          ON edge.edge_id = path.edge
    )

    SELECT
        route.seq::INTEGER AS route_sequence,
        route.path_seq::INTEGER AS path_sequence,

        route.node AS node_id,
        route.edge AS edge_id,

        route.source_node_id,
        route.target_node_id,

        route.road_name,
        route.road_ref,
        route.road_class,

        route.cost::DOUBLE PRECISION AS edge_cost,
        route.agg_cost::DOUBLE PRECISION AS aggregate_cost,

        route.edge_length_metres,

        SUM(route.edge_length_metres)
            OVER (
                ORDER BY route.path_seq
                ROWS BETWEEN UNBOUNDED PRECEDING
                         AND CURRENT ROW
            )::DOUBLE PRECISION
            AS cumulative_length_metres,

        route.edge_travel_time_seconds,

        SUM(route.edge_travel_time_seconds)
            OVER (
                ORDER BY route.path_seq
                ROWS BETWEEN UNBOUNDED PRECEDING
                         AND CURRENT ROW
            )::DOUBLE PRECISION
            AS cumulative_travel_time_seconds,

        route.traversed_forward,

        route.route_geom AS geom

    FROM route_edges AS route
    ORDER BY route.path_seq;
END;
$$;


COMMENT ON FUNCTION hvn.calculate_vehicle_route(
    BIGINT,
    BIGINT,
    BIGINT,
    DOUBLE PRECISION
) IS
    'Calculates a corridor-bounded, vehicle-restricted shortest path using pgRouting Dijkstra routing.';


COMMIT;
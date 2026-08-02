/*
===============================================================================
Adaptive Corridor Strategy
===============================================================================

Determines which routing corridor sequence should be used based on the
straight-line journey distance.

Returned values are corridor widths in metres.

These values are intentionally conservative for metropolitan routing while
allowing progressively wider searches for regional and remote Australia.
===============================================================================
*/

CREATE OR REPLACE FUNCTION hvn.select_corridor_sequence(

    p_straight_line_distance_metres DOUBLE PRECISION

)

RETURNS DOUBLE PRECISION[]

LANGUAGE plpgsql

IMMUTABLE

PARALLEL SAFE

AS
$$

BEGIN

    IF p_straight_line_distance_metres < 50000 THEN

        RETURN ARRAY[
            5000,
            10000,
            20000,
            50000
        ];

    ELSIF p_straight_line_distance_metres < 200000 THEN

        RETURN ARRAY[
            10000,
            20000,
            50000,
            100000
        ];

    ELSIF p_straight_line_distance_metres < 500000 THEN

        RETURN ARRAY[
            20000,
            50000,
            100000,
            200000
        ];

    ELSIF p_straight_line_distance_metres < 1000000 THEN

        RETURN ARRAY[
            50000,
            100000,
            200000,
            400000
        ];

    ELSE

        RETURN ARRAY[
            100000,
            200000,
            400000
        ];

    END IF;

END;

$$;

COMMENT ON FUNCTION hvn.select_corridor_sequence(
DOUBLE PRECISION
)

IS
'Returns the adaptive routing corridor ladder based on straight-line journey distance.';


/*
===============================================================================
Adaptive Coordinate Routing
===============================================================================

Attempts progressively wider routing corridors until:

    - a valid route is found; or
    - the maximum permitted corridor is reached.

The selected vehicle restrictions remain active for every attempt.

The routing metadata is repeated on each returned route row so that the caller
can identify:

    - straight-line journey distance;
    - corridor used;
    - attempt count;
    - all corridor widths attempted.
===============================================================================
*/

CREATE OR REPLACE FUNCTION hvn.route_between_coordinates_adaptive(
    p_start_latitude DOUBLE PRECISION,
    p_start_longitude DOUBLE PRECISION,
    p_end_latitude DOUBLE PRECISION,
    p_end_longitude DOUBLE PRECISION,
    p_vehicle_profile_id BIGINT,
    p_max_corridor_metres DOUBLE PRECISION DEFAULT 400000
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
    geom geometry,

    straight_line_distance_metres DOUBLE PRECISION,
    corridor_used_metres DOUBLE PRECISION,
    routing_attempt_count INTEGER,
    attempted_corridors_metres DOUBLE PRECISION[]
)
LANGUAGE plpgsql
STABLE
PARALLEL RESTRICTED
AS $function$
DECLARE
    v_straight_line_distance_metres DOUBLE PRECISION;
    v_corridor_sequence DOUBLE PRECISION[];
    v_corridor_metres DOUBLE PRECISION;

    v_attempted_corridors DOUBLE PRECISION[]
        := ARRAY[]::DOUBLE PRECISION[];

    v_attempt_count INTEGER := 0;
    v_rows_returned BIGINT := 0;
BEGIN
    ---------------------------------------------------------------------------
    -- Validate the maximum corridor
    ---------------------------------------------------------------------------

    IF p_max_corridor_metres IS NULL
       OR p_max_corridor_metres <= 0
    THEN
        RAISE EXCEPTION
            'Maximum routing corridor must be greater than zero metres.'
            USING ERRCODE = '22023';
    END IF;


    ---------------------------------------------------------------------------
    -- Calculate straight-line distance between the supplied coordinates
    ---------------------------------------------------------------------------

    v_straight_line_distance_metres :=
        ST_DistanceSphere(
            ST_SetSRID(
                ST_MakePoint(
                    p_start_longitude,
                    p_start_latitude
                ),
                4326
            ),

            ST_SetSRID(
                ST_MakePoint(
                    p_end_longitude,
                    p_end_latitude
                ),
                4326
            )
        );


    ---------------------------------------------------------------------------
    -- Select the appropriate corridor ladder
    ---------------------------------------------------------------------------

    v_corridor_sequence :=
        hvn.select_corridor_sequence(
            v_straight_line_distance_metres
        );


    ---------------------------------------------------------------------------
    -- Attempt each corridor in sequence
    ---------------------------------------------------------------------------

    FOREACH v_corridor_metres
    IN ARRAY v_corridor_sequence
    LOOP
        /*
         * Do not exceed the maximum corridor permitted by the caller.
         */
        IF v_corridor_metres > p_max_corridor_metres THEN
            CONTINUE;
        END IF;

        v_attempt_count := v_attempt_count + 1;

        v_attempted_corridors :=
            ARRAY_APPEND(
                v_attempted_corridors,
                v_corridor_metres
            );


        /*
         * Return the complete route if this corridor succeeds.
         *
         * If no rows are returned, execution continues to the next corridor.
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
            route.geom,

            v_straight_line_distance_metres,
            v_corridor_metres,
            v_attempt_count,
            v_attempted_corridors

        FROM hvn.route_between_coordinates(
            p_start_latitude,
            p_start_longitude,
            p_end_latitude,
            p_end_longitude,
            p_vehicle_profile_id,
            v_corridor_metres
        ) AS route;


        GET DIAGNOSTICS
            v_rows_returned = ROW_COUNT;


        /*
         * Stop widening as soon as a valid route has been returned.
         */
        IF v_rows_returned > 0 THEN
            RETURN;
        END IF;
    END LOOP;


    ---------------------------------------------------------------------------
    -- No route found within the permitted corridor ladder
    ---------------------------------------------------------------------------

    IF v_attempt_count = 0 THEN
        RAISE EXCEPTION
            'Maximum corridor of % metres is below the first corridor required '
            'for this journey.',
            p_max_corridor_metres
            USING ERRCODE = '22023';
    END IF;

    RAISE EXCEPTION
        'No vehicle-compatible route was found after % attempt(s). '
        'Attempted corridors: % metres. Maximum permitted corridor: % metres.',
        v_attempt_count,
        v_attempted_corridors,
        p_max_corridor_metres
        USING ERRCODE = 'P0001';
END;
$function$;


COMMENT ON FUNCTION hvn.route_between_coordinates_adaptive(
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    BIGINT,
    DOUBLE PRECISION
)
IS
'Calculates a vehicle-aware route using an adaptive corridor ladder and returns the successful corridor and attempt metadata.';
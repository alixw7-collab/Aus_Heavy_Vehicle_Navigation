BEGIN;

CREATE OR REPLACE FUNCTION hvn.route_instructions(
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
    distance_metres DOUBLE PRECISION,
    travel_time_seconds DOUBLE PRECISION
)
LANGUAGE sql
STABLE
AS
$$

WITH route AS MATERIALIZED
(
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

instructions AS
(
    SELECT

        route_sequence,

        CASE

            WHEN route_sequence = 1
            THEN 'DEPART'

            WHEN LEAD(route_sequence)
                 OVER (ORDER BY route_sequence)
                 IS NULL
            THEN 'ARRIVE'

            ELSE 'CONTINUE'

        END AS instruction_type,

        road_name,
        road_ref,
        road_class,

        edge_length_metres,
        edge_travel_time_seconds

    FROM route

    WHERE edge_id >= 0

)

SELECT

    ROW_NUMBER()
        OVER (ORDER BY route_sequence)
        AS instruction_sequence,

    instruction_type,

    CASE

        WHEN instruction_type='DEPART'
            THEN 'Depart via ' ||
                 COALESCE(road_name,'Unnamed Road')

        WHEN instruction_type='ARRIVE'
            THEN 'Arrive at destination'

        ELSE 'Continue on ' ||
             COALESCE(road_name,'Unnamed Road')

    END,

    road_name,

    road_ref,

    road_class,

    edge_length_metres,

    edge_travel_time_seconds

FROM instructions

ORDER BY route_sequence;

$$;

COMMENT ON FUNCTION hvn.route_instructions(
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    DOUBLE PRECISION,
    BIGINT,
    DOUBLE PRECISION
)
IS
'Returns simple turn-by-turn navigation instructions for a calculated route.';

COMMIT;
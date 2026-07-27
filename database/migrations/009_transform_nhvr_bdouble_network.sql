-- Project RoadTrain
-- Transform raw NHVR Queensland 26 metre B-double data
-- into the permanent access-network model.

BEGIN;

-- Prevent accidental duplicate loading.
-- This removes only the previously transformed records for this
-- particular internal network code.
DELETE FROM hvn.access_network_segment
WHERE network_code = 'NHVR_QLD_BDOUBLE_26M_GML';

INSERT INTO hvn.access_network_segment
(
    source_id,
    source_feature_id,
    network_code,
    network_name,
    jurisdiction_code,
    vehicle_class,
    maximum_length_m,
    mass_scheme,
    access_status,
    access_direction,
    conditions_text,
    source_attributes,
    effective_from,
    effective_to,
    retrieved_at,
    active,
    geom
)
SELECT
    1 AS source_id, -- REPLACE WITH ACTUAL source_id

    row_number() OVER (
        ORDER BY
            ST_XMin(ST_Envelope(raw.geom)),
            ST_YMin(ST_Envelope(raw.geom))
    )::TEXT AS source_feature_id,

    'NHVR_QLD_BDOUBLE_26M_GML' AS network_code,

    'Queensland 26 metre B-double network' AS network_name,

    'QLD' AS jurisdiction_code,

    'B_DOUBLE' AS vehicle_class,

    26.00 AS maximum_length_m,

    'GML' AS mass_scheme,

    'APPROVED' AS access_status,

    'BOTH' AS access_direction,

    NULL::TEXT AS conditions_text,

    to_jsonb(raw) - 'geom' AS source_attributes,

    NULL::DATE AS effective_from,

    NULL::DATE AS effective_to,

    CURRENT_TIMESTAMP AS retrieved_at,

    TRUE AS active,

    ST_Multi(
        ST_CollectionExtract(
            ST_MakeValid(
                ST_Transform(raw.geom, 7856)
            ),
            2
        )
    )::geometry(MultiLineString, 7856) AS geom

FROM staging.nhvr_qld_26m_bdouble_raw AS raw

WHERE raw.geom IS NOT NULL;

COMMIT;
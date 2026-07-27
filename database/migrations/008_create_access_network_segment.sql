-- Project RoadTrain
-- Version 0.2
-- Create permanent official access-network segment table

BEGIN;

CREATE TABLE IF NOT EXISTS hvn.access_network_segment
(
    access_network_segment_id BIGINT GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    source_id BIGINT NOT NULL,

    source_feature_id TEXT,

    network_code TEXT NOT NULL,

    network_name TEXT NOT NULL,

    jurisdiction_code TEXT NOT NULL DEFAULT 'QLD',

    vehicle_class TEXT NOT NULL,

    maximum_length_m NUMERIC(6,2),

    mass_scheme TEXT,

    access_status TEXT NOT NULL DEFAULT 'APPROVED',

    access_direction TEXT NOT NULL DEFAULT 'BOTH',

    conditions_text TEXT,

    source_attributes JSONB NOT NULL DEFAULT '{}'::jsonb,

    effective_from DATE,

    effective_to DATE,

    retrieved_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    active BOOLEAN NOT NULL DEFAULT TRUE,

    geom geometry(MultiLineString, 7856) NOT NULL,

    CONSTRAINT fk_access_network_segment_source
        FOREIGN KEY (source_id)
        REFERENCES hvn.road_rule_source(source_id),

    CONSTRAINT chk_access_network_status
        CHECK (
            access_status IN
            (
                'APPROVED',
                'CONDITIONAL',
                'PERMIT',
                'PROHIBITED',
                'UNKNOWN'
            )
        ),

    CONSTRAINT chk_access_network_direction
        CHECK (
            access_direction IN
            (
                'BOTH',
                'FORWARD',
                'REVERSE'
            )
        ),

    CONSTRAINT chk_access_network_dates
        CHECK (
            effective_to IS NULL
            OR effective_from IS NULL
            OR effective_to >= effective_from
        ),

    CONSTRAINT chk_access_network_length
        CHECK (
            maximum_length_m IS NULL
            OR maximum_length_m > 0
        )
);

COMMENT ON TABLE hvn.access_network_segment IS
'Cleaned official heavy-vehicle access-network geometry. This table is separate from the routable road-centreline network.';

COMMENT ON COLUMN hvn.access_network_segment.source_attributes IS
'Complete original source record retained as JSON for provenance and later field mapping.';

COMMENT ON COLUMN hvn.access_network_segment.geom IS
'Standardised GDA2020 / MGA Zone 56 multipart line geometry in metres.';

CREATE INDEX IF NOT EXISTS idx_access_network_segment_geom
    ON hvn.access_network_segment
    USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_access_network_segment_source
    ON hvn.access_network_segment(source_id);

CREATE INDEX IF NOT EXISTS idx_access_network_segment_network_code
    ON hvn.access_network_segment(network_code);

CREATE INDEX IF NOT EXISTS idx_access_network_segment_vehicle_class
    ON hvn.access_network_segment(vehicle_class);

CREATE INDEX IF NOT EXISTS idx_access_network_segment_active
    ON hvn.access_network_segment(active);

CREATE INDEX IF NOT EXISTS idx_access_network_segment_source_attributes
    ON hvn.access_network_segment
    USING GIN (source_attributes);

COMMIT;
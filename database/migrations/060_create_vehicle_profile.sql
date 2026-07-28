/*
===============================================================================
Migration: 060_create_vehicle_profile.sql

Purpose:
    Create vehicle profiles used to test routing edges against physical,
    access and dangerous-goods restrictions.

Design principles:
    - No assumed legal dimensions.
    - Every profile contains explicit vehicle measurements.
    - Vehicle profiles may represent real vehicles or test scenarios.
    - Profiles can be deactivated without being deleted.
    - Routing logic will be added in a later migration.

Dependencies:
    - Schema hvn

===============================================================================
*/

BEGIN;


-------------------------------------------------------------------------------
-- 1. Vehicle profile table
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS hvn.vehicle_profile
(
    vehicle_profile_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    profile_name TEXT
        NOT NULL,

    profile_code TEXT
        NOT NULL,

    description TEXT,

    vehicle_type TEXT
        NOT NULL,

    height_m NUMERIC(6, 3)
        NOT NULL,

    width_m NUMERIC(6, 3)
        NOT NULL,

    length_m NUMERIC(7, 3)
        NOT NULL,

    gross_mass_t NUMERIC(8, 3)
        NOT NULL,

    is_heavy_vehicle BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    carries_dangerous_goods BOOLEAN
        NOT NULL
        DEFAULT FALSE,

    requires_hgv_access BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    /*
     * Optional future network classification.
     *
     * Examples may eventually include:
     *     GENERAL_ACCESS
     *     B_DOUBLE
     *     ROAD_TRAIN
     *     PBS
     *
     * No routing meaning is assigned to these values yet.
     */
    required_network_code TEXT,

    is_active BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    source_name TEXT,

    source_reference TEXT,

    notes TEXT,

    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT vehicle_profile_profile_name_not_blank
        CHECK (BTRIM(profile_name) <> ''),

    CONSTRAINT vehicle_profile_profile_code_not_blank
        CHECK (BTRIM(profile_code) <> ''),

    CONSTRAINT vehicle_profile_vehicle_type_not_blank
        CHECK (BTRIM(vehicle_type) <> ''),

    CONSTRAINT vehicle_profile_height_positive
        CHECK (height_m > 0),

    CONSTRAINT vehicle_profile_width_positive
        CHECK (width_m > 0),

    CONSTRAINT vehicle_profile_length_positive
        CHECK (length_m > 0),

    CONSTRAINT vehicle_profile_mass_positive
        CHECK (gross_mass_t > 0),

    /*
     * These upper bounds detect obvious data-entry mistakes.
     * They are not statements of Australian legal limits.
     */
    CONSTRAINT vehicle_profile_height_plausible
        CHECK (height_m <= 20),

    CONSTRAINT vehicle_profile_width_plausible
        CHECK (width_m <= 20),

    CONSTRAINT vehicle_profile_length_plausible
        CHECK (length_m <= 200),

    CONSTRAINT vehicle_profile_mass_plausible
        CHECK (gross_mass_t <= 1000)
);


-------------------------------------------------------------------------------
-- 2. Case-insensitive profile code uniqueness
-------------------------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS vehicle_profile_code_uq
    ON hvn.vehicle_profile (LOWER(profile_code));


-------------------------------------------------------------------------------
-- 3. Useful lookup indexes
-------------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS vehicle_profile_active_idx
    ON hvn.vehicle_profile (is_active)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS vehicle_profile_vehicle_type_idx
    ON hvn.vehicle_profile (vehicle_type);

CREATE INDEX IF NOT EXISTS vehicle_profile_network_code_idx
    ON hvn.vehicle_profile (required_network_code)
    WHERE required_network_code IS NOT NULL;


-------------------------------------------------------------------------------
-- 4. Normalisation trigger
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hvn.normalise_vehicle_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.profile_name := BTRIM(NEW.profile_name);
    NEW.profile_code := UPPER(BTRIM(NEW.profile_code));
    NEW.vehicle_type := UPPER(BTRIM(NEW.vehicle_type));

    IF NEW.required_network_code IS NOT NULL THEN
        NEW.required_network_code :=
            UPPER(BTRIM(NEW.required_network_code));

        IF NEW.required_network_code = '' THEN
            NEW.required_network_code := NULL;
        END IF;
    END IF;

    IF NEW.source_name IS NOT NULL THEN
        NEW.source_name := BTRIM(NEW.source_name);

        IF NEW.source_name = '' THEN
            NEW.source_name := NULL;
        END IF;
    END IF;

    IF NEW.source_reference IS NOT NULL THEN
        NEW.source_reference := BTRIM(NEW.source_reference);

        IF NEW.source_reference = '' THEN
            NEW.source_reference := NULL;
        END IF;
    END IF;

    NEW.updated_at := CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS vehicle_profile_normalise_trg
    ON hvn.vehicle_profile;

CREATE TRIGGER vehicle_profile_normalise_trg
BEFORE INSERT OR UPDATE
ON hvn.vehicle_profile
FOR EACH ROW
EXECUTE FUNCTION hvn.normalise_vehicle_profile();


-------------------------------------------------------------------------------
-- 5. Documentation
-------------------------------------------------------------------------------

COMMENT ON TABLE hvn.vehicle_profile IS
    'Explicit vehicle dimensions and operating characteristics used for heavy-vehicle route assessment.';

COMMENT ON COLUMN hvn.vehicle_profile.profile_code IS
    'Stable application identifier for the profile, normalised to uppercase.';

COMMENT ON COLUMN hvn.vehicle_profile.height_m IS
    'Actual vehicle or combination height in metres.';

COMMENT ON COLUMN hvn.vehicle_profile.width_m IS
    'Actual vehicle or combination width in metres.';

COMMENT ON COLUMN hvn.vehicle_profile.length_m IS
    'Actual total vehicle or combination length in metres.';

COMMENT ON COLUMN hvn.vehicle_profile.gross_mass_t IS
    'Actual or assessed gross vehicle or combination mass in metric tonnes.';

COMMENT ON COLUMN hvn.vehicle_profile.carries_dangerous_goods IS
    'TRUE when the routing assessment must enforce dangerous-goods restrictions.';

COMMENT ON COLUMN hvn.vehicle_profile.requires_hgv_access IS
    'TRUE when explicit heavy-goods-vehicle restrictions must be evaluated.';

COMMENT ON COLUMN hvn.vehicle_profile.required_network_code IS
    'Optional network class required by the vehicle profile; routing interpretation is added separately.';

COMMENT ON COLUMN hvn.vehicle_profile.source_name IS
    'Origin of the dimensions or configuration, such as operator records, manufacturer data or manual entry.';

COMMENT ON COLUMN hvn.vehicle_profile.source_reference IS
    'Document, URL, fleet number or other reference supporting the profile values.';


COMMIT;
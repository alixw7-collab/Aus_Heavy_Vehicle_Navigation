/*
===============================================================================
Project RoadTrain

Migration 099
Vehicle Intelligence Foundation

Part A
Reference Schema

Purpose

Provides normalised reference tables for vehicle intelligence.

Operational data remains in schema:

    hvn

Reference / lookup data lives in:

    reference
===============================================================================
*/

CREATE SCHEMA IF NOT EXISTS reference;

COMMENT ON SCHEMA reference IS
'Reference data used throughout Project RoadTrain.';


/*
===============================================================================
Part B
Vehicle Categories
===============================================================================
*/

CREATE TABLE IF NOT EXISTS reference.vehicle_category (

    vehicle_category_id SMALLSERIAL PRIMARY KEY,

    category_code TEXT NOT NULL UNIQUE,

    category_name TEXT NOT NULL UNIQUE,

    description TEXT

);

INSERT INTO reference.vehicle_category
(
    category_code,
    category_name,
    description
)

VALUES

('RIGID','Rigid',
 'Rigid truck'),

('SEMI','Semi Trailer',
 'Prime mover and single trailer'),

('BDOUBLE','B-Double',
 'Standard Australian B-Double'),

('ADOUBLE','A-Double',
 'A-Double combination'),

('ABTRIPLE','AB-Triple',
 'AB-Triple combination'),

('BTRIPLE','B-Triple',
 'B-Triple combination'),

('ROADTRAIN','Road Train',
 'Road Train combination'),

('OVERSIZE','Oversize',
 'Oversize / Overmass vehicle')

ON CONFLICT DO NOTHING;



/*
===============================================================================
Part C
PBS Levels
===============================================================================
*/

CREATE TABLE IF NOT EXISTS reference.pbs_level (

    pbs_level_id SMALLSERIAL PRIMARY KEY,

    pbs_code TEXT UNIQUE,

    description TEXT

);

INSERT INTO reference.pbs_level
(
    pbs_code,
    description
)

VALUES

('NONE','Non PBS'),

('1','PBS Level 1'),

('2A','PBS Level 2A'),

('2B','PBS Level 2B'),

('3A','PBS Level 3A'),

('3B','PBS Level 3B'),

('4','PBS Level 4')

ON CONFLICT DO NOTHING;



/*
===============================================================================
Part D
Australian Jurisdictions
===============================================================================
*/

CREATE TABLE IF NOT EXISTS reference.jurisdiction (

    jurisdiction_id SMALLSERIAL PRIMARY KEY,

    jurisdiction_code TEXT UNIQUE,

    jurisdiction_name TEXT

);

INSERT INTO reference.jurisdiction
(
    jurisdiction_code,
    jurisdiction_name
)

VALUES

('QLD','Queensland'),

('NSW','New South Wales'),

('VIC','Victoria'),

('SA','South Australia'),

('WA','Western Australia'),

('NT','Northern Territory'),

('ACT','Australian Capital Territory'),

('TAS','Tasmania')

ON CONFLICT DO NOTHING;


/*
===============================================================================
Part E
Vehicle Combination Types
===============================================================================

A category may have several combination types.

Examples:
    Category: ROADTRAIN
    Types:
        DOUBLE_ROAD_TRAIN
        TRIPLE_ROAD_TRAIN

No legal access entitlement is inferred from these records.
===============================================================================
*/

CREATE TABLE IF NOT EXISTS reference.combination_type
(
    combination_type_id SMALLINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    vehicle_category_id SMALLINT
        NOT NULL,

    combination_code TEXT
        NOT NULL,

    combination_name TEXT
        NOT NULL,

    description TEXT,

    is_active BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    CONSTRAINT combination_type_category_fk
        FOREIGN KEY (vehicle_category_id)
        REFERENCES reference.vehicle_category (
            vehicle_category_id
        ),

    CONSTRAINT combination_type_code_not_blank
        CHECK (BTRIM(combination_code) <> ''),

    CONSTRAINT combination_type_name_not_blank
        CHECK (BTRIM(combination_name) <> '')
);


CREATE UNIQUE INDEX IF NOT EXISTS combination_type_code_uq
    ON reference.combination_type (
        UPPER(combination_code)
    );


INSERT INTO reference.combination_type
(
    vehicle_category_id,
    combination_code,
    combination_name,
    description
)
SELECT
    category.vehicle_category_id,
    values_to_insert.combination_code,
    values_to_insert.combination_name,
    values_to_insert.description
FROM
(
    VALUES
        (
            'RIGID',
            'RIGID_ONLY',
            'Rigid Truck',
            'Rigid truck without a trailer.'
        ),
        (
            'RIGID',
            'RIGID_DOG',
            'Rigid and Dog Trailer',
            'Rigid truck towing a dog trailer.'
        ),
        (
            'RIGID',
            'RIGID_PIG',
            'Rigid and Pig Trailer',
            'Rigid truck towing a pig trailer.'
        ),
        (
            'SEMI',
            'PRIME_SEMI',
            'Prime Mover and Semitrailer',
            'Prime mover towing one semitrailer.'
        ),
        (
            'BDOUBLE',
            'STANDARD_BDOUBLE',
            'Standard B-Double',
            'Prime mover, lead semitrailer and rear semitrailer.'
        ),
        (
            'ADOUBLE',
            'STANDARD_ADOUBLE',
            'Standard A-Double',
            'Prime mover and two trailers connected using a converter dolly.'
        ),
        (
            'BTRIPLE',
            'STANDARD_BTRIPLE',
            'Standard B-Triple',
            'Prime mover and three trailers using B-coupling arrangements.'
        ),
        (
            'ABTRIPLE',
            'STANDARD_ABTRIPLE',
            'Standard AB-Triple',
            'Combination containing both A-coupling and B-coupling arrangements.'
        ),
        (
            'ROADTRAIN',
            'DOUBLE_ROAD_TRAIN',
            'Double Road Train',
            'Road-train configuration containing two trailers.'
        ),
        (
            'ROADTRAIN',
            'TRIPLE_ROAD_TRAIN',
            'Triple Road Train',
            'Road-train configuration containing three trailers.'
        ),
        (
            'OVERSIZE',
            'OVERSIZE_OVERMASS',
            'Oversize or Overmass',
            'Vehicle requiring dimensions, mass and access conditions to be assessed individually.'
        )
) AS values_to_insert(
    category_code,
    combination_code,
    combination_name,
    description
)
JOIN reference.vehicle_category AS category
  ON category.category_code =
     values_to_insert.category_code

ON CONFLICT DO NOTHING;


/*
===============================================================================
Part F
Extend Vehicle Profiles
===============================================================================
*/

ALTER TABLE hvn.vehicle_profile
    ADD COLUMN IF NOT EXISTS vehicle_category_id SMALLINT,

    ADD COLUMN IF NOT EXISTS combination_type_id SMALLINT,

    ADD COLUMN IF NOT EXISTS pbs_level_id SMALLINT,

    ADD COLUMN IF NOT EXISTS primary_jurisdiction_id SMALLINT,

    ADD COLUMN IF NOT EXISTS axle_count SMALLINT,

    ADD COLUMN IF NOT EXISTS escort_required BOOLEAN
        NOT NULL
        DEFAULT FALSE,

    ADD COLUMN IF NOT EXISTS is_oversize BOOLEAN
        NOT NULL
        DEFAULT FALSE,

    ADD COLUMN IF NOT EXISTS is_overmass BOOLEAN
        NOT NULL
        DEFAULT FALSE;


/*
===============================================================================
Add Foreigh Keys Safely
===============================================================================
*/

DO $$
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conname =
            'vehicle_profile_vehicle_category_fk'
          AND conrelid =
            'hvn.vehicle_profile'::REGCLASS
    )
    THEN
        ALTER TABLE hvn.vehicle_profile
            ADD CONSTRAINT
                vehicle_profile_vehicle_category_fk
            FOREIGN KEY (vehicle_category_id)
            REFERENCES reference.vehicle_category (
                vehicle_category_id
            );
    END IF;


    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conname =
            'vehicle_profile_combination_type_fk'
          AND conrelid =
            'hvn.vehicle_profile'::REGCLASS
    )
    THEN
        ALTER TABLE hvn.vehicle_profile
            ADD CONSTRAINT
                vehicle_profile_combination_type_fk
            FOREIGN KEY (combination_type_id)
            REFERENCES reference.combination_type (
                combination_type_id
            );
    END IF;


    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conname =
            'vehicle_profile_pbs_level_fk'
          AND conrelid =
            'hvn.vehicle_profile'::REGCLASS
    )
    THEN
        ALTER TABLE hvn.vehicle_profile
            ADD CONSTRAINT
                vehicle_profile_pbs_level_fk
            FOREIGN KEY (pbs_level_id)
            REFERENCES reference.pbs_level (
                pbs_level_id
            );
    END IF;


    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conname =
            'vehicle_profile_primary_jurisdiction_fk'
          AND conrelid =
            'hvn.vehicle_profile'::REGCLASS
    )
    THEN
        ALTER TABLE hvn.vehicle_profile
            ADD CONSTRAINT
                vehicle_profile_primary_jurisdiction_fk
            FOREIGN KEY (primary_jurisdiction_id)
            REFERENCES reference.jurisdiction (
                jurisdiction_id
            );
    END IF;
END;
$$;


/*
===============================================================================
Add Basic Validation
===============================================================================
*/

DO $$
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conname =
            'vehicle_profile_axle_count_positive'
          AND conrelid =
            'hvn.vehicle_profile'::REGCLASS
    )
    THEN
        ALTER TABLE hvn.vehicle_profile
            ADD CONSTRAINT
                vehicle_profile_axle_count_positive
            CHECK (
                axle_count IS NULL
                OR axle_count > 0
            );
    END IF;
END;
$$;



/*
===============================================================================
Add Indexes for Profile Filtering
===============================================================================
*/

CREATE INDEX IF NOT EXISTS
    vehicle_profile_category_idx
ON hvn.vehicle_profile (
    vehicle_category_id
)
WHERE vehicle_category_id IS NOT NULL;


CREATE INDEX IF NOT EXISTS
    vehicle_profile_combination_type_idx
ON hvn.vehicle_profile (
    combination_type_id
)
WHERE combination_type_id IS NOT NULL;


CREATE INDEX IF NOT EXISTS
    vehicle_profile_pbs_level_idx
ON hvn.vehicle_profile (
    pbs_level_id
)
WHERE pbs_level_id IS NOT NULL;


/*
===============================================================================
Add Documentation
===============================================================================
*/

COMMENT ON COLUMN
    hvn.vehicle_profile.vehicle_category_id
IS
'Broad vehicle category selected from reference.vehicle_category.';


COMMENT ON COLUMN
    hvn.vehicle_profile.combination_type_id
IS
'Specific physical combination selected from reference.combination_type.';


COMMENT ON COLUMN
    hvn.vehicle_profile.pbs_level_id
IS
'Optional PBS classification reference. This field alone does not establish road access approval.';


COMMENT ON COLUMN
    hvn.vehicle_profile.primary_jurisdiction_id
IS
'Primary operating jurisdiction for profile organisation and future rule evaluation.';


COMMENT ON COLUMN
    hvn.vehicle_profile.axle_count
IS
'Total axle count where known.';


COMMENT ON COLUMN
    hvn.vehicle_profile.escort_required
IS
'Indicates that the operating profile requires escort arrangements; detailed conditions are evaluated separately.';


COMMENT ON COLUMN
    hvn.vehicle_profile.is_oversize
IS
'Indicates that the configured vehicle is being treated as oversize.';


COMMENT ON COLUMN
    hvn.vehicle_profile.is_overmass
IS
'Indicates that the configured vehicle is being treated as overmass.';



/*
===============================================================================
Part G
Assign Vehicle Intelligence Safely
===============================================================================

Purpose:
    Assign category, combination type, PBS level and jurisdiction to an
    existing vehicle profile using stable reference codes.

Validation:
    - Vehicle profile must exist.
    - Category code must exist.
    - Combination code must exist.
    - Combination type must belong to the selected category.
    - PBS and jurisdiction codes must exist when supplied.
===============================================================================
*/

CREATE OR REPLACE FUNCTION hvn.assign_vehicle_intelligence
(
    p_vehicle_profile_id BIGINT,
    p_vehicle_category_code TEXT,
    p_combination_code TEXT DEFAULT NULL,
    p_pbs_code TEXT DEFAULT NULL,
    p_jurisdiction_code TEXT DEFAULT NULL,
    p_axle_count SMALLINT DEFAULT NULL,
    p_escort_required BOOLEAN DEFAULT FALSE,
    p_is_oversize BOOLEAN DEFAULT FALSE,
    p_is_overmass BOOLEAN DEFAULT FALSE
)
RETURNS hvn.vehicle_profile
LANGUAGE plpgsql
AS $function$
DECLARE
    v_category_id SMALLINT;
    v_combination_type_id SMALLINT;
    v_pbs_level_id SMALLINT;
    v_jurisdiction_id SMALLINT;
    v_updated_profile hvn.vehicle_profile%ROWTYPE;
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM hvn.vehicle_profile
        WHERE vehicle_profile_id = p_vehicle_profile_id
    )
    THEN
        RAISE EXCEPTION
            'Vehicle profile % does not exist.',
            p_vehicle_profile_id
            USING ERRCODE = 'P0002';
    END IF;


    SELECT vehicle_category_id
    INTO v_category_id
    FROM reference.vehicle_category
    WHERE UPPER(category_code) =
          UPPER(BTRIM(p_vehicle_category_code));

    IF v_category_id IS NULL THEN
        RAISE EXCEPTION
            'Vehicle category code % does not exist.',
            p_vehicle_category_code
            USING ERRCODE = 'P0002';
    END IF;


    IF p_combination_code IS NOT NULL THEN
        SELECT combination_type_id
        INTO v_combination_type_id
        FROM reference.combination_type
        WHERE UPPER(combination_code) =
              UPPER(BTRIM(p_combination_code))
          AND vehicle_category_id = v_category_id;

        IF v_combination_type_id IS NULL THEN
            RAISE EXCEPTION
                'Combination code % does not belong to vehicle category %.',
                p_combination_code,
                p_vehicle_category_code
                USING ERRCODE = '23514';
        END IF;
    END IF;


    IF p_pbs_code IS NOT NULL THEN
        SELECT pbs_level_id
        INTO v_pbs_level_id
        FROM reference.pbs_level
        WHERE UPPER(pbs_code) =
              UPPER(BTRIM(p_pbs_code));

        IF v_pbs_level_id IS NULL THEN
            RAISE EXCEPTION
                'PBS code % does not exist.',
                p_pbs_code
                USING ERRCODE = 'P0002';
        END IF;
    END IF;


    IF p_jurisdiction_code IS NOT NULL THEN
        SELECT jurisdiction_id
        INTO v_jurisdiction_id
        FROM reference.jurisdiction
        WHERE UPPER(jurisdiction_code) =
              UPPER(BTRIM(p_jurisdiction_code));

        IF v_jurisdiction_id IS NULL THEN
            RAISE EXCEPTION
                'Jurisdiction code % does not exist.',
                p_jurisdiction_code
                USING ERRCODE = 'P0002';
        END IF;
    END IF;


    IF p_axle_count IS NOT NULL
       AND p_axle_count <= 0
    THEN
        RAISE EXCEPTION
            'Axle count must be greater than zero.'
            USING ERRCODE = '22023';
    END IF;


    UPDATE hvn.vehicle_profile
    SET
        vehicle_category_id = v_category_id,
        combination_type_id = v_combination_type_id,
        pbs_level_id = v_pbs_level_id,
        primary_jurisdiction_id = v_jurisdiction_id,
        axle_count = p_axle_count,
        escort_required = COALESCE(
            p_escort_required,
            FALSE
        ),
        is_oversize = COALESCE(
            p_is_oversize,
            FALSE
        ),
        is_overmass = COALESCE(
            p_is_overmass,
            FALSE
        )
    WHERE vehicle_profile_id = p_vehicle_profile_id
    RETURNING *
    INTO v_updated_profile;

    RETURN v_updated_profile;
END;
$function$;


COMMENT ON FUNCTION hvn.assign_vehicle_intelligence
(
    BIGINT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    SMALLINT,
    BOOLEAN,
    BOOLEAN,
    BOOLEAN
)
IS
'Assigns validated vehicle category, combination, PBS, jurisdiction and operating characteristics to an existing vehicle profile.';



/*
===============================================================================
Part H
Vehicle Profile Detail View
===============================================================================
*/

CREATE OR REPLACE VIEW hvn.vehicle_profile_detail AS
SELECT
    profile.vehicle_profile_id,
    profile.profile_code,
    profile.profile_name,
    profile.description,
    profile.vehicle_type,

    profile.height_m,
    profile.width_m,
    profile.length_m,
    profile.gross_mass_t,
    profile.axle_count,

    profile.is_heavy_vehicle,
    profile.carries_dangerous_goods,
    profile.requires_hgv_access,
    profile.escort_required,
    profile.is_oversize,
    profile.is_overmass,

    category.category_code,
    category.category_name,

    combination.combination_code,
    combination.combination_name,

    pbs.pbs_code,
    pbs.description AS pbs_description,

    jurisdiction.jurisdiction_code,
    jurisdiction.jurisdiction_name,

    profile.required_network_code,
    profile.is_active,
    profile.source_name,
    profile.source_reference,
    profile.notes,
    profile.created_at,
    profile.updated_at

FROM hvn.vehicle_profile AS profile

LEFT JOIN reference.vehicle_category AS category
  ON category.vehicle_category_id =
     profile.vehicle_category_id

LEFT JOIN reference.combination_type AS combination
  ON combination.combination_type_id =
     profile.combination_type_id

LEFT JOIN reference.pbs_level AS pbs
  ON pbs.pbs_level_id =
     profile.pbs_level_id

LEFT JOIN reference.jurisdiction AS jurisdiction
  ON jurisdiction.jurisdiction_id =
     profile.primary_jurisdiction_id;


COMMENT ON VIEW hvn.vehicle_profile_detail IS
'Readable vehicle profile view with resolved category, combination, PBS and jurisdiction reference values.';

COMMIT;

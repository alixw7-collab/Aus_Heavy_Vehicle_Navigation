/*
===============================================================================
Project RoadTrain
Migration 102: Create ADG dangerous-goods substance register
===============================================================================

Purpose:
    Create the database structures needed to import and retain the official
    Australian Dangerous Goods Code Table 3.2.3.

Source structure:
    National Transport Commission
    Australian Dangerous Goods Code
    Table 3.2.3

Design:
    1. reference.dg_source_edition
       Records the source edition and file provenance.

    2. staging.adg_table_3_2_3_raw
       Preserves imported spreadsheet values substantially as published.

    3. reference.dg_substance
       Stores validated, versioned dangerous-goods register records.

Important:
    - This migration creates structures only.
    - It does not import or interpret regulatory data.
    - The original NTC workbook remains the authoritative source.
    - UN number alone is not unique.
    - Provision and instruction fields remain TEXT because they may contain
      multiple codes, symbols and line breaks.
===============================================================================
*/

BEGIN;


-- ============================================================================
-- Required schemas
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS staging;

CREATE SCHEMA IF NOT EXISTS reference;


COMMENT ON SCHEMA staging IS
'Temporary and source-faithful import structures used before validation and promotion.';

COMMENT ON SCHEMA reference IS
'Versioned reference data used throughout Project RoadTrain.';


-- ============================================================================
-- ADG source editions
-- ============================================================================

CREATE TABLE IF NOT EXISTS reference.dg_source_edition
(
    dg_source_edition_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    edition_code TEXT
        NOT NULL,

    source_name TEXT
        NOT NULL,

    source_table TEXT
        NOT NULL,

    source_filename TEXT
        NOT NULL,

    source_url TEXT,

    file_sha256 TEXT,

    effective_from DATE,

    effective_to DATE,

    is_current BOOLEAN
        NOT NULL
        DEFAULT FALSE,

    source_notes TEXT,

    registered_at TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT dg_source_edition_code_not_blank
        CHECK (BTRIM(edition_code) <> ''),

    CONSTRAINT dg_source_name_not_blank
        CHECK (BTRIM(source_name) <> ''),

    CONSTRAINT dg_source_table_not_blank
        CHECK (BTRIM(source_table) <> ''),

    CONSTRAINT dg_source_filename_not_blank
        CHECK (BTRIM(source_filename) <> ''),

    CONSTRAINT dg_source_dates_valid
        CHECK (
            effective_to IS NULL
            OR effective_from IS NULL
            OR effective_to >= effective_from
        )
);


CREATE UNIQUE INDEX IF NOT EXISTS dg_source_edition_code_uq
    ON reference.dg_source_edition (
        UPPER(edition_code)
    );


CREATE UNIQUE INDEX IF NOT EXISTS dg_source_current_edition_uq
    ON reference.dg_source_edition (is_current)
    WHERE is_current IS TRUE;


COMMENT ON TABLE reference.dg_source_edition IS
'Provenance and version information for imported Australian Dangerous Goods reference sources.';

COMMENT ON COLUMN reference.dg_source_edition.file_sha256 IS
'Optional SHA-256 hash of the exact source file used for the import.';

COMMENT ON COLUMN reference.dg_source_edition.is_current IS
'Marks the source edition currently selected for new compliance evaluations. Historical editions remain retained.';


-- ============================================================================
-- Raw Table 3.2.3 staging import
-- ============================================================================

CREATE TABLE IF NOT EXISTS staging.adg_table_3_2_3_raw
(
    staging_import_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    /*
     * Workbook rows 1–4 contain headings and references.
     * The first imported data row is therefore source row 5.
     */
    source_row_number INTEGER
        GENERATED ALWAYS AS (
            staging_import_id + 4
        )
        STORED,

    un_number TEXT,

    name_and_description TEXT,

    class_or_division TEXT,

    subsidiary_hazard TEXT,

    packing_group TEXT,

    special_provisions TEXT,

    limited_quantity TEXT,

    excepted_quantity TEXT,

    packaging_instruction TEXT,

    packaging_special_provisions TEXT,

    large_packaging_instruction TEXT,

    large_packaging_special_provisions TEXT,

    ibc_instruction TEXT,

    ibc_special_provisions TEXT,

    portable_tank_instruction TEXT,

    portable_tank_special_provisions TEXT,

    bulk_container_instruction TEXT,

    import_batch_id UUID,

    imported_at TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);


CREATE INDEX IF NOT EXISTS adg_raw_un_number_idx
    ON staging.adg_table_3_2_3_raw (
        un_number
    );


CREATE INDEX IF NOT EXISTS adg_raw_source_row_idx
    ON staging.adg_table_3_2_3_raw (
        source_row_number
    );


CREATE INDEX IF NOT EXISTS adg_raw_import_batch_idx
    ON staging.adg_table_3_2_3_raw (
        import_batch_id
    )
    WHERE import_batch_id IS NOT NULL;


COMMENT ON TABLE staging.adg_table_3_2_3_raw IS
'Source-faithful staging table for columns A–Q of the NTC Australian Dangerous Goods Code Table 3.2.3 spreadsheet.';

COMMENT ON COLUMN staging.adg_table_3_2_3_raw.source_row_number IS
'Original Excel worksheet row number. Data starts at workbook row 5.';

COMMENT ON COLUMN staging.adg_table_3_2_3_raw.un_number IS
'UN number exactly as imported. Validation and conversion occur during promotion.';

COMMENT ON COLUMN staging.adg_table_3_2_3_raw.name_and_description IS
'Name and description exactly as published in Table 3.2.3.';

COMMENT ON COLUMN staging.adg_table_3_2_3_raw.import_batch_id IS
'Optional identifier allowing separate import attempts to be audited and compared.';


-- ============================================================================
-- Canonical dangerous-goods substance register
-- ============================================================================

CREATE TABLE IF NOT EXISTS reference.dg_substance
(
    dg_substance_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    dg_source_edition_id BIGINT
        NOT NULL,

    source_row_number INTEGER
        NOT NULL,

    un_number INTEGER
        NOT NULL,

    name_and_description TEXT
        NOT NULL,

    class_or_division TEXT
        NOT NULL,

    subsidiary_hazard TEXT,

    packing_group TEXT,

    special_provisions TEXT,

    limited_quantity TEXT,

    excepted_quantity TEXT,

    packaging_instruction TEXT,

    packaging_special_provisions TEXT,

    large_packaging_instruction TEXT,

    large_packaging_special_provisions TEXT,

    ibc_instruction TEXT,

    ibc_special_provisions TEXT,

    portable_tank_instruction TEXT,

    portable_tank_special_provisions TEXT,

    bulk_container_instruction TEXT,

    is_current BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    imported_at TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    superseded_at TIMESTAMPTZ,

    CONSTRAINT dg_substance_source_edition_fk
        FOREIGN KEY (dg_source_edition_id)
        REFERENCES reference.dg_source_edition (
            dg_source_edition_id
        ),

    CONSTRAINT dg_substance_source_row_positive
        CHECK (source_row_number >= 5),

    CONSTRAINT dg_substance_un_number_valid
        CHECK (
            un_number BETWEEN 1 AND 9999
        ),

    CONSTRAINT dg_substance_name_not_blank
        CHECK (
            BTRIM(name_and_description) <> ''
        ),

    CONSTRAINT dg_substance_class_not_blank
        CHECK (
            BTRIM(class_or_division) <> ''
        ),

    CONSTRAINT dg_substance_superseded_valid
        CHECK (
            superseded_at IS NULL
            OR superseded_at >= imported_at
        ),

    CONSTRAINT dg_substance_source_row_uq
        UNIQUE (
            dg_source_edition_id,
            source_row_number
        )
);


CREATE INDEX IF NOT EXISTS dg_substance_un_number_idx
    ON reference.dg_substance (
        un_number
    );


CREATE INDEX IF NOT EXISTS dg_substance_name_idx
    ON reference.dg_substance (
        name_and_description
    );


CREATE INDEX IF NOT EXISTS dg_substance_class_idx
    ON reference.dg_substance (
        class_or_division
    );


CREATE INDEX IF NOT EXISTS dg_substance_packing_group_idx
    ON reference.dg_substance (
        packing_group
    )
    WHERE packing_group IS NOT NULL;


CREATE INDEX IF NOT EXISTS dg_substance_source_edition_idx
    ON reference.dg_substance (
        dg_source_edition_id
    );


CREATE INDEX IF NOT EXISTS dg_substance_current_idx
    ON reference.dg_substance (
        un_number,
        class_or_division
    )
    WHERE is_current IS TRUE;


COMMENT ON TABLE reference.dg_substance IS
'Versioned register of dangerous-goods entries promoted from official ADG Table 3.2.3 source data.';

COMMENT ON COLUMN reference.dg_substance.un_number IS
'Numeric UN number. Applications should display it as four digits using LPAD(un_number::TEXT, 4, ''0'').';

COMMENT ON COLUMN reference.dg_substance.source_row_number IS
'Original worksheet row supporting traceability back to the official source file.';

COMMENT ON COLUMN reference.dg_substance.special_provisions IS
'Provision codes preserved as published. This field may contain multiple codes or line breaks.';

COMMENT ON COLUMN reference.dg_substance.is_current IS
'Indicates whether this particular source-edition record is currently applicable. It does not replace edition provenance.';


-- ============================================================================
-- Human-readable current-register view
-- ============================================================================

CREATE OR REPLACE VIEW reference.dg_substance_detail AS
SELECT
    substance.dg_substance_id,

    edition.edition_code,

    edition.source_name,

    edition.source_table,

    edition.source_filename,

    substance.source_row_number,

    substance.un_number,

    LPAD(
        substance.un_number::TEXT,
        4,
        '0'
    ) AS displayed_un_number,

    substance.name_and_description,

    substance.class_or_division,

    substance.subsidiary_hazard,

    substance.packing_group,

    substance.special_provisions,

    substance.limited_quantity,

    substance.excepted_quantity,

    substance.packaging_instruction,

    substance.packaging_special_provisions,

    substance.large_packaging_instruction,

    substance.large_packaging_special_provisions,

    substance.ibc_instruction,

    substance.ibc_special_provisions,

    substance.portable_tank_instruction,

    substance.portable_tank_special_provisions,

    substance.bulk_container_instruction,

    substance.is_current,

    substance.imported_at,

    substance.superseded_at

FROM reference.dg_substance AS substance

JOIN reference.dg_source_edition AS edition
  ON edition.dg_source_edition_id =
     substance.dg_source_edition_id;


COMMENT ON VIEW reference.dg_substance_detail IS
'Human-readable dangerous-goods register including source-edition provenance and four-digit UN number display.';


COMMIT;
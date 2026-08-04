/*
===============================================================================
Project RoadTrain
Migration 103: Import ADG Dangerous Goods List
===============================================================================

Source:
    National Transport Commission
    Australian Dangerous Goods Code
    Table 3.2.3

Purpose:
    Validate and promote raw Table 3.2.3 records from staging into the
    versioned dangerous-goods substance register.

Important:
    The source spreadsheet remains authoritative. Imported values are retained
    largely as published and are not interpreted as routing rules by this
    migration.
===============================================================================
*/

BEGIN;


/*
===============================================================================
Prepare staging table for a fresh import
===============================================================================
*/

TRUNCATE TABLE staging.adg_table_3_2_3_raw
RESTART IDENTITY;


/*
===============================================================================
Register the source edition
===============================================================================
*/

INSERT INTO reference.dg_source_edition
(
    edition_code,
    source_name,
    source_table,
    source_filename,
    effective_from,
    is_current
)
VALUES
(
    'ADG_7_9',
    'Australian Dangerous Goods Code',
    'Table 3.2.3',
    'Australian Dangerous Goods Code - Table 3.2.3.xlsx',
    NULL,
    TRUE
)
ON CONFLICT (edition_code)
DO UPDATE SET
    source_name = EXCLUDED.source_name,
    source_table = EXCLUDED.source_table,
    source_filename = EXCLUDED.source_filename,
    is_current = EXCLUDED.is_current;

COMMIT;
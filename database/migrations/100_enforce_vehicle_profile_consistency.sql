/*
===============================================================================
Project RoadTrain
Migration 100: Enforce vehicle profile consistency
===============================================================================

Purpose:
    Prevent invalid combinations of vehicle category and combination type,
    regardless of whether a profile is changed through the assignment function
    or by direct INSERT/UPDATE SQL.

Rules:
    - combination_type_id cannot be supplied without vehicle_category_id.
    - the selected combination type must belong to the selected category.
===============================================================================
*/

BEGIN;


CREATE OR REPLACE FUNCTION hvn.validate_vehicle_profile_intelligence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
    v_combination_category_id SMALLINT;
BEGIN
    /*
     * A specific combination requires a broad vehicle category.
     */
    IF NEW.combination_type_id IS NOT NULL
       AND NEW.vehicle_category_id IS NULL
    THEN
        RAISE EXCEPTION
            'Vehicle category must be supplied when combination type % is selected.',
            NEW.combination_type_id
            USING ERRCODE = '23514';
    END IF;


    /*
     * Confirm that the combination belongs to the selected category.
     */
    IF NEW.combination_type_id IS NOT NULL THEN
        SELECT combination.vehicle_category_id
        INTO v_combination_category_id
        FROM reference.combination_type AS combination
        WHERE combination.combination_type_id =
              NEW.combination_type_id;

        IF v_combination_category_id IS NULL THEN
            RAISE EXCEPTION
                'Combination type % does not exist.',
                NEW.combination_type_id
                USING ERRCODE = '23503';
        END IF;

        IF v_combination_category_id <>
           NEW.vehicle_category_id
        THEN
            RAISE EXCEPTION
                'Combination type % belongs to vehicle category %, not category %.',
                NEW.combination_type_id,
                v_combination_category_id,
                NEW.vehicle_category_id
                USING ERRCODE = '23514';
        END IF;
    END IF;


    /*
     * Basic profile relationship checks.
     */
    IF NEW.is_overmass
       AND NEW.gross_mass_t IS NULL
    THEN
        RAISE EXCEPTION
            'An overmass profile must have a gross mass value.'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$function$;


DROP TRIGGER IF EXISTS
    vehicle_profile_intelligence_validation_trg
ON hvn.vehicle_profile;


CREATE TRIGGER
    vehicle_profile_intelligence_validation_trg
BEFORE INSERT OR UPDATE OF
    vehicle_category_id,
    combination_type_id,
    gross_mass_t,
    is_overmass
ON hvn.vehicle_profile
FOR EACH ROW
EXECUTE FUNCTION
    hvn.validate_vehicle_profile_intelligence();


COMMENT ON FUNCTION
    hvn.validate_vehicle_profile_intelligence()
IS
'Enforces valid relationships between vehicle profile categories, combination types and operating attributes.';


COMMIT;
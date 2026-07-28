/*
===============================================================================
Migration: 070_enable_pgrouting.sql

Purpose:
    Enable pgRouting in the heavy_vehicle_navigation database.

Dependencies:
    - PostgreSQL extension files for pgRouting
    - PostGIS

===============================================================================
*/

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgrouting;

COMMIT;
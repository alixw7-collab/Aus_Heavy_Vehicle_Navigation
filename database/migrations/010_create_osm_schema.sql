BEGIN;

CREATE SCHEMA IF NOT EXISTS osm;

COMMENT ON SCHEMA osm IS
'OpenStreetMap data imported through osm2pgsql. This schema is reference and routing-source data, not authoritative heavy-vehicle access evidence.';

COMMIT;
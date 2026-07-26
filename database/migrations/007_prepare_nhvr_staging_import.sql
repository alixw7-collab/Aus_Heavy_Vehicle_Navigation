-- Project RoadTrain
-- Prepare staging schema for NHVR source imports

CREATE SCHEMA IF NOT EXISTS staging;

COMMENT ON SCHEMA staging IS
'Temporary imported source data. Source structure is preserved before transformation into permanent HVN tables.';
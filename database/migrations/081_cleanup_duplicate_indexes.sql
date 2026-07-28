/*
===============================================================================
Project RoadTrain
Migration 081: Remove duplicate routing indexes
===============================================================================

Purpose:
    Remove duplicate indexes created during Migration 080.

Reason:
    Equivalent indexes already existed from earlier migrations. Keeping both
    sets provides no benefit and increases storage and maintenance overhead.

Retained Indexes:
    routing_edge_geom_gix
    routing_edge_source_node_idx
    routing_edge_target_node_idx
    routing_edge_source_target_idx
===============================================================================
*/

BEGIN;

DROP INDEX IF EXISTS hvn.idx_routing_edge_geom_gist;

DROP INDEX IF EXISTS hvn.idx_routing_edge_source_node_id;

DROP INDEX IF EXISTS hvn.idx_routing_edge_target_node_id;

DROP INDEX IF EXISTS hvn.idx_routing_edge_source_target;

COMMIT;

ANALYZE hvn.routing_edge;
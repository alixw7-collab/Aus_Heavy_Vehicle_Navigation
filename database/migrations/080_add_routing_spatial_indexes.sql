/*
===============================================================================
Project RoadTrain
Migration 080: Add routing spatial and lookup indexes
===============================================================================

Purpose:
    Prepare the routing graph for efficient GPS-to-network searches.

Creates:
    - GiST spatial index on routing edge geometry
    - B-tree index on source node ID
    - B-tree index on target node ID
    - Composite source/target node index

Notes:
    - CREATE INDEX IF NOT EXISTS makes the migration safe to rerun.
    - The routing-node spatial index will be added in Migration 081 after
      hvn.routing_node is created.
===============================================================================
*/

BEGIN;

CREATE INDEX IF NOT EXISTS idx_routing_edge_geom_gist
    ON hvn.routing_edge
    USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_routing_edge_source_node_id
    ON hvn.routing_edge (source_node_id);

CREATE INDEX IF NOT EXISTS idx_routing_edge_target_node_id
    ON hvn.routing_edge (target_node_id);

CREATE INDEX IF NOT EXISTS idx_routing_edge_source_target
    ON hvn.routing_edge (
        source_node_id,
        target_node_id
    );

COMMIT;

ANALYZE hvn.routing_edge;
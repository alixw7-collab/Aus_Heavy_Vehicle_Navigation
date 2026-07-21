\# Database Change Log



\## Version 0.1 — Initial baseline



\### Added



\- `hvn` schema

\- `hvn.vehicle\_configuration`

\- `hvn.road\_segment`

\- `hvn.road\_access`

\- `hvn.road\_rule\_source`

\- PostGIS spatial support

\- Spatial index on road-segment geometry

\- Foreign-key relationships for road access



\### Known limitations



\- NHVR network data has not yet been imported.

\- Road segments do not yet form a validated routing graph.

\- Access rules have not yet been matched to routable road segments.

\- Directional restrictions are only represented at a basic level.

\- Temporary restrictions are not yet modelled.

\- Permit and notice structures are not yet finalised.


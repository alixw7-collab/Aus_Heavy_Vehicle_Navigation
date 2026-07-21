\# Project RoadTrain — Current State



\## Baseline version



Version: 0.1  

Baseline date: 21 July 2026



\## Project purpose



Develop an Australian heavy-vehicle access and navigation platform that combines:



\- official NHVR and road-manager access data;

\- vehicle-specific legal access rules;

\- practical driver and fleet knowledge;

\- auditable route validation;

\- eventual turn-by-turn heavy-vehicle navigation.



\## Initial prototype scope



\- Australia-first architecture

\- Queensland prototype

\- Nambour to Brisbane freight corridor

\- 26-metre B-Double

\- Official network-access validation

\- QGIS visualisation

\- PostgreSQL/PostGIS storage



\## Existing components



\- GitHub repository

\- Project folder structure

\- PostgreSQL database: `heavy\_vehicle\_navigation`

\- PostGIS enabled

\- Database schema: `hvn`

\- QGIS PostgreSQL connection

\- `vehicle\_configuration` table

\- `road\_segment` table

\- `road\_access` table

\- `road\_rule\_source` table



\## Current design principles



1\. Original source data is never overwritten.

2\. Every access rule must identify its source.

3\. Legal access and practical suitability are separate concepts.

4\. Unknown access is not treated as approved access.

5\. Road access is stored against individual road segments.

6\. The prototype must be capable of scaling to fleet use.

7\. QGIS is the development and validation interface.

8\. PostgreSQL/PostGIS is the system of record.



\## Next milestone



Import and inspect the official NHVR B-Double network in a staging schema before transforming it into the permanent database model.


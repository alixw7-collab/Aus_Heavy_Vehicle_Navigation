\# Project RoadTrain Roadmap



This document outlines the planned development roadmap for Project RoadTrain. The roadmap is intended to guide development while remaining flexible as the project evolves.



\---



\# Current Release



\*\*Version:\*\* v0.7.0



Completed:



\- PostgreSQL/PostGIS architecture

\- OSM import pipeline

\- Routing graph generation

\- Heavy vehicle restriction engine

\- Vehicle profiles

\- Vehicle compatibility engine

\- pgRouting integration

\- Vehicle-aware routing

\- Route geometry visualisation



\---



\# Sprint 8 — GPS Routing



\## Objectives



\- Add routing node table

\- Implement nearest-node search using spatial indexes

\- Route directly from GPS coordinates

\- Remove dependency on manually identifying graph node IDs



Deliverables:



\- Migration 080 – Routing indexes

\- Migration 081 – Routing node table

\- Migration 082 – Nearest node lookup

\- Migration 083 – GPS routing interface



\---



\# Sprint 9 — Turn Restrictions



Objectives:



\- Import OSM turn restrictions

\- Apply legal turning movements

\- Prevent illegal manoeuvres

\- Support one-way turn logic



\---



\# Sprint 10 — NHVR Integration



Objectives:



\- Import NHVR approved road network

\- Integrate permit-based routing

\- Introduce restriction provenance

\- Allow NHVR data to override OSM where appropriate



\---



\# Sprint 11 — Explainable Routing



Objectives:



\- Explain routing decisions

\- Identify blocked roads

\- Report restriction reasons

\- Produce routing reports



\---



\# Sprint 12 — REST API



Objectives:



\- Route calculation endpoint

\- Vehicle profile endpoint

\- Route explanation endpoint

\- GeoJSON output



\---



\# Sprint 13 — Web Application



Objectives:



\- Interactive map

\- Vehicle selection

\- Route visualisation

\- Restriction display



\---



\# Sprint 14 — Mobile Navigation



Objectives:



\- Android application

\- GPS tracking

\- Turn-by-turn navigation

\- Offline routing



\---



\# Long-Term Vision



Project RoadTrain aims to become an Australian heavy vehicle routing platform capable of:



\- Heavy vehicle legal compliance

\- NHVR integration

\- Dangerous Goods routing

\- Fleet optimisation

\- Permit-aware navigation

\- Explainable routing decisions

\- Future real-time traffic and road closure integration


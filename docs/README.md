🚛 Project RoadTrain
Australian Heavy Vehicle Routing Platform

Version 0.7.0



Project RoadTrain is a PostgreSQL/PostGIS-based routing engine designed specifically for heavy vehicles operating within Australia.



Unlike conventional navigation systems, Project RoadTrain is being developed to understand vehicle dimensions, mass limits, dangerous goods restrictions, NHVR approved networks, and other legal operating constraints when calculating routes.



The long-term objective is to provide an open, explainable routing platform suitable for freight operators, fleet management, transport planning and future in-cab navigation systems.



\---



\# Project Status



\*\*Current Version:\*\* v0.7.0



\## Completed



\- PostgreSQL database architecture

\- PostGIS spatial database

\- pgRouting integration

\- OpenStreetMap import pipeline

\- Road segmentation

\- Routing graph generation

\- Heavy vehicle restriction parsing

\- Vehicle profile system

\- Vehicle compatibility engine

\- Vehicle-aware shortest path routing

\- Route geometry generation



Current development has reached the point where valid heavy vehicle routes can be calculated and visualised directly from the routing graph.



\---



\# Why Project RoadTrain?



Traditional navigation applications primarily optimise for passenger vehicles.



Heavy vehicles operate under additional constraints including:



\- Maximum vehicle height

\- Vehicle width

\- Combination length

\- Gross mass

\- Dangerous Goods restrictions

\- Heavy Vehicle network approvals

\- Bridge restrictions

\- Road access limitations



Project RoadTrain aims to model these constraints as first-class routing rules rather than afterthoughts.



\---



\# Technology Stack



| Component | Technology |

|------------|------------|

| Database | PostgreSQL 18 |

| Spatial Database | PostGIS 3.6 |

| Routing Engine | pgRouting |

| OSM Import | osm2pgsql 2.3 |

| Language | SQL / PLpgSQL |

| Source Control | Git \& GitHub |



\---



\# Project Architecture



```

&#x20;               OpenStreetMap

&#x20;                     │

&#x20;                     ▼

&#x20;               osm2pgsql Import

&#x20;                     │

&#x20;                     ▼

&#x20;              PostgreSQL/PostGIS

&#x20;                     │

&#x20;       ┌─────────────┴─────────────┐

&#x20;       │                           │

&#x20;       ▼                           ▼

&#x20;Routing Graph              Restriction Engine

&#x20;       │                           │

&#x20;       └─────────────┬─────────────┘

&#x20;                     ▼

&#x20;            Vehicle Compatibility

&#x20;                     │

&#x20;                     ▼

&#x20;                pgRouting Engine

&#x20;                     │

&#x20;                     ▼

&#x20;               Calculated Route

&#x20;                     │

&#x20;                     ▼

&#x20;              Route Geometry Output

```



\---



\# Database Schemas



\## osm



Stores imported OpenStreetMap data.



\## staging



Temporary import and transformation tables.



\## hvn



Heavy Vehicle Navigation schema containing:



\- routing graph

\- restriction engine

\- vehicle profiles

\- compatibility functions

\- routing functions



\---



\# Current Features



\## Vehicle Profiles



Each vehicle profile stores:



\- height

\- width

\- length

\- gross mass

\- dangerous goods status



Multiple vehicle profiles can coexist without duplicating routing data.



\---



\## Restriction Engine



Current restriction types include:



\- Height

\- Width

\- Length

\- Weight

\- Motor vehicle restrictions

\- Heavy Goods Vehicle restrictions

\- Dangerous Goods restrictions



Each evaluated edge returns one of:



\- PASS

\- PASS\_WITH\_WARNINGS

\- BLOCKED



Blocked edges also record the reason for rejection.



\---



\## Routing Engine



The routing engine currently provides:



\- Vehicle-aware shortest path

\- Edge filtering

\- Geometry generation

\- Distance calculation

\- Travel time estimation



Built using pgRouting.



\---



\# Project Structure



```

database/

│

├── migrations/

├── scripts/

└── documentation/



docs/

│

├── architecture/

├── adr/

└── design/



data/

```



\---



\# Migration History



Current migration sequence:



001 – Database creation



006 – Staging schema



007 – NHVR staging import



008 – Access network segments



009 – NHVR transformation



010 – OSM schema



030 – Road segmentation



040 – Routing graph



050 – Heavy vehicle attributes



051 – Restriction parsing improvements



060 – Vehicle profiles



061 – Compatibility engine



062 – Vehicle edge filtering



063 – Boolean logic corrections



070 – pgRouting



071 – Vehicle-aware shortest path



\---



\# Roadmap



\## Sprint 8



\- GPS coordinate snapping

\- Nearest graph node selection



\## Sprint 9



\- Turn restrictions



\## Sprint 10



\- NHVR network integration



\## Sprint 11



\- Explainable routing decisions



\## Sprint 12



\- REST API



\## Sprint 13



\- Web application



\## Sprint 14



\- Mobile navigation client



\---



\# Design Principles



Project RoadTrain follows several core principles:



\- Explainable routing decisions

\- Migration-based schema evolution

\- Separation of source data and application data

\- No duplicated routing graphs per vehicle

\- Restriction provenance

\- Production-ready database architecture



\---



\# Future Development



Planned future capabilities include:



\- NHVR permit routing

\- Live road closures

\- Bridge databases

\- Roadworks integration

\- Fleet optimisation

\- Multi-stop route optimisation

\- Driver fatigue planning

\- Real-time traffic

\- Android navigation client



\---



\# Licence



This project is currently under active development.



Licence to be determined.



\---



\# Author



Alix Welsh



Project RoadTrain



Australian Heavy Vehicle Routing Platform


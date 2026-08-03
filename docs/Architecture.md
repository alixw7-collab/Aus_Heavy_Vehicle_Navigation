\# Project RoadTrain — Version 0.2 Architecture



\## 1. System Objective



Project RoadTrain Version 0.2 is a heavy-vehicle route-validation prototype.



It separates:



1\. routable road geometry;

2\. official access-network geometry;

3\. vehicle configurations;

4\. access rules;

5\. source evidence;

6\. route-validation results.



This separation is essential because an official approved-network layer is not automatically a connected navigation graph.



\## 2. High-Level Architecture



```text

Official NHVR data

&#x20;       |

&#x20;       v

PostGIS staging schema

&#x20;       |

&#x20;       | inspect, clean and transform

&#x20;       v

Official access-network tables

&#x20;       |

&#x20;       | spatial matching

&#x20;       v

Road access rules

&#x20;       |

&#x20;       +----------------------+

&#x20;                              |

OpenStreetMap or road-centreline data

&#x20;       |                      |

&#x20;       v                      v

PostGIS staging schema     Vehicle configuration

&#x20;       |                      |

&#x20;       v                      |

Permanent road segments <-----+

&#x20;       |

&#x20;       v

Route validation

&#x20;       |

&#x20;       v

QGIS map and validation report

```



\## 3. Technology Components



\### PostgreSQL



Stores relational project data.



\### PostGIS



Provides:



\* spatial geometry;

\* coordinate transformations;

\* spatial indexes;

\* line intersection;

\* proximity matching;

\* route geometry analysis.



\### QGIS



Provides:



\* source-data inspection;

\* data editing;

\* visual quality assurance;

\* map styling;

\* prototype route selection;

\* validation-result display.



\### Git and GitHub



Store:



\* SQL scripts;

\* migration scripts;

\* documentation;

\* QGIS project definitions where appropriate;

\* Python code when introduced;

\* test definitions.



Large raw GIS datasets are stored outside ordinary Git tracking.



\## 4. Database Schemas



\### `hvn`



Permanent application data.



Examples:



\* vehicle configurations;

\* road segments;

\* road-access rules;

\* source records;

\* validated routes.



\### `staging`



Temporary imported source data.



Examples:



\* raw NHVR network layers;

\* raw OpenStreetMap extracts;

\* road-authority datasets.



Staging tables may reflect source field names and structures.



\### `reference`



Controlled lookup values where needed.



Possible future examples:



\* access statuses;

\* direction codes;

\* source types;

\* road classes;

\* vehicle families.



The first prototype may retain some controlled values as database CHECK constraints before converting them to lookup tables.



\## 5. Data Flow



\### Step 1 — Acquire



Download official source data and retain the original file.



\### Step 2 — Register



Create or update a `road\_rule\_source` record describing the dataset.



\### Step 3 — Stage



Import source layers into the `staging` schema without forcing them into the permanent model.



\### Step 4 — Inspect



Record:



\* layer name;

\* fields;

\* geometry type;

\* coordinate reference system;

\* feature count;

\* data extent;

\* apparent network meaning;

\* limitations.



\### Step 5 — Transform



Clean and standardise source records.



\### Step 6 — Match



Spatially associate approved-network geometry with routable road segments.



\### Step 7 — Classify



Create road-access records for the target vehicle configuration.



\### Step 8 — Validate



Compare a proposed route with access records.



\### Step 9 — Present



Display results in QGIS and provide source evidence.



\## 6. Architectural Principles



\### Separate access geometry from routing geometry



NHVR data determines legal network access.



A routable centreline dataset supplies connected road geometry.



They must not be assumed to be interchangeable.



\### Preserve raw data



Raw source data is immutable.



Corrections and standardisation occur in staging or transformed tables.



\### Use internal identifiers



Permanent application tables use Project RoadTrain identifiers.



External source identifiers are retained only as source references.



\### Record provenance



Every transformed official rule must point back to the source dataset.



\### Treat unknown as unsafe



A missing access record does not prove prohibition, but it also does not prove approval.



The system must report UNKNOWN unless a supported rule determines otherwise.



\### Support history



Rules may be superseded without deleting historical evidence.



\### Delay routing-engine selection



Version 0.2 validates routes.



Graph routing software will be selected only after the access model and spatial matching process are proven.



\## 7. Version 0.2 Components



\### Required



\* `hvn.vehicle\_configuration`

\* `hvn.road\_segment`

\* `hvn.road\_access`

\* `hvn.road\_rule\_source`

\* `staging` schema

\* staged NHVR network table

\* staged road-centreline table

\* route-validation view or query

\* QGIS visualisation



\### Deferred



\* routing graph topology;

\* turn restrictions;

\* bridge structures;

\* customer sites;

\* practical suitability;

\* driver notes;

\* permits;

\* temporary restrictions;

\* live telemetry.



\## 8. Initial Validation Logic



For each road segment in a route:



1\. Find an active access rule for the selected vehicle.

2\. Confirm the rule is effective for the validation date.

3\. Inspect its access status.

4\. Record its source.

5\. If no applicable rule exists, classify the segment as UNKNOWN.



Overall route result:



\* PROHIBITED if any segment is prohibited;

\* PERMIT if none are prohibited and at least one requires a permit;

\* CONDITIONAL if none are prohibited or permit-only and at least one is conditional;

\* UNKNOWN if no higher-risk status exists and at least one segment is unknown;

\* APPROVED only when all segments are approved.



\## 9. Future Evolution



Once Version 0.2 is proven, the system can add:



\* automatic routing;

\* turn restrictions;

\* bridge and mass constraints;

\* PBS networks;

\* road-train networks;

\* practical route suitability;

\* customer access;

\* driver intelligence;

\* fleet operations;

\* mobile navigation.



\# Project RoadTrain — Version 0.6 Architecture

Project RoadTrain Architecture

1. Vision
2. Design Philosophy
3. Overall Architecture
4. Database Architecture
5. Routing Pipeline
6. Navigation Pipeline
7. Future Components
8. Version History


                    Mobile App
                         │
                    REST API (future)
                         │
                hvn.navigate()
                         │
      route_between_coordinates_adaptive()
                         │
          route_between_coordinates()
                         │
          calculate_vehicle_route()
                         │
                    pgRouting
                         │
                 routing_edge graph
                         │
                 OSM + NHVR Data
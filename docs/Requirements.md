\# Project RoadTrain — Version 0.2 Requirements



\## 1. Purpose



Version 0.2 will prove that Project RoadTrain can validate whether a proposed route is legally accessible to a defined heavy-vehicle configuration using authoritative road-access data.



This version is a route-validation prototype, not a turn-by-turn navigation system.



\## 2. Prototype Scope



The initial prototype will cover:



\* Queensland

\* Nambour to Brisbane freight corridor

\* 26-metre B-Double

\* General Mass Limits initially

\* Official NHVR access-network data

\* QGIS visualisation

\* PostgreSQL/PostGIS storage

\* Manual route selection or imported route geometry



\## 3. Primary User



The primary Version 0.2 user is:



\* an experienced heavy-vehicle driver validating a proposed route.



Future users may include:



\* fleet allocators;

\* compliance managers;

\* operations managers;

\* new drivers;

\* route planners.



\## 4. Core User Question



The system must answer:



> Can this defined heavy-vehicle configuration legally use every road segment in this proposed route?



\## 5. Functional Requirements



\### FR-001 — Vehicle configuration



The system must store a defined vehicle configuration containing, at minimum:



\* combination type;

\* overall length;

\* overall height;

\* overall width;

\* operating mass;

\* mass scheme;

\* PBS classification where applicable.



\### FR-002 — Road segments



The system must store a routable road-centreline network divided into individual road segments.



Each segment must have:



\* an internal immutable identifier;

\* geometry;

\* road name where available;

\* road class;

\* source dataset;

\* source feature identifier;

\* active status.



\### FR-003 — Access-network source



The system must store official heavy-vehicle access-network data separately from the routable road network.



Original downloaded data must not be overwritten.



\### FR-004 — Access rules



The system must associate access rules with:



\* a road segment;

\* a vehicle configuration or vehicle class;

\* an access status;

\* a source;

\* an effective period where available;

\* access conditions where applicable.



\### FR-005 — Access status



The permitted access-status values are:



\* APPROVED;

\* CONDITIONAL;

\* PERMIT;

\* PROHIBITED;

\* UNKNOWN.



UNKNOWN must never be treated as APPROVED.



\### FR-006 — Source traceability



Every official access rule must reference a source record.



The source record must identify, where available:



\* authority;

\* dataset or document name;

\* version;

\* retrieval date;

\* publication date;

\* effective date;

\* expiry date;

\* source location;

\* notes.



\### FR-007 — Route validation



The system must accept a route represented as a sequence of road segments or a route geometry.



It must test the route against the selected vehicle configuration.



\### FR-008 — Validation result



The route-validation result must identify:



\* overall result;

\* approved segments;

\* conditional segments;

\* permit-required segments;

\* prohibited segments;

\* unknown segments;

\* source information for each relevant access decision.



\### FR-009 — Conservative decision rule



A route may only receive an overall APPROVED result when every relevant segment is confirmed approved for the selected vehicle configuration.



A route containing any UNKNOWN segment must not receive an APPROVED result.



\### FR-010 — QGIS display



QGIS must be able to display road segments using access-status symbology.



The prototype should visually distinguish:



\* approved;

\* conditional;

\* permit required;

\* prohibited;

\* unknown.



\### FR-011 — Data staging



Imported external data must first enter a staging schema.



External data must be inspected and transformed before loading into permanent project tables.



\### FR-012 — Direction



The data model must allow directional access restrictions, even where the initial dataset does not supply them.



Supported values initially are:



\* BOTH;

\* FORWARD;

\* REVERSE.



\### FR-013 — Effective dates



The model must support rules that commence, expire or are superseded.



Historical rules must not be physically deleted merely because they are no longer active.



\### FR-014 — Validation evidence



A user must be able to determine why a segment was classified with a particular access status.



\## 6. Non-Functional Requirements



\### NFR-001 — Accuracy



The system must favour a conservative UNKNOWN result over an unsupported assumption.



\### NFR-002 — Auditability



Access decisions must be reproducible from stored data and sources.



\### NFR-003 — Data integrity



Foreign keys, constraints and controlled values must be used to prevent invalid records.



\### NFR-004 — Scalability



The architecture must be capable of expanding from one Queensland corridor to a national road network.



\### NFR-005 — Maintainability



Database changes must be recorded through version-controlled SQL migration scripts.



\### NFR-006 — Security



Passwords, connection strings, credentials and private keys must not be stored in GitHub.



\### NFR-007 — Performance



Spatial columns must use appropriate spatial indexes.



Frequently joined identifier fields must use conventional indexes.



\### NFR-008 — Source preservation



Raw source datasets must remain unchanged and must be retained outside normal Git storage where file size makes repository storage impractical.



\## 7. Out of Scope for Version 0.2



The following are explicitly excluded:



\* spoken navigation;

\* mobile application;

\* live traffic;

\* automatic route generation;

\* temporary road closures;

\* customer gate instructions;

\* driver-submitted hazards;

\* fleet vehicle tracking;

\* electronic work diary integration;

\* permit application;

\* bridge engineering assessment;

\* swept-path simulation;

\* commercial fleet deployment.



\## 8. Acceptance Criteria



Version 0.2 is accepted when:



1\. A Queensland NHVR B-Double network extract has been imported into a staging schema.

2\. The source data has been documented.

3\. A routable road-centreline sample has been imported.

4\. NHVR access geometry has been matched to road segments for the selected corridor.

5\. The 26-metre B-Double vehicle configuration exists.

6\. A test route from Nambour toward Brisbane can be validated.

7\. Every route segment receives an access status.

8\. Unknown or unmatched segments are clearly reported.

9\. QGIS displays the validation result.

10\. Each official access decision can be traced to its source.




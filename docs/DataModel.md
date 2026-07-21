\# Project RoadTrain — Version 0.2 Data Model



\## 1. Existing Permanent Tables



\### `hvn.vehicle\_configuration`



Purpose:



Stores the heavy-vehicle configuration being assessed.



Primary key:



\* `vehicle\_id`



Important fields:



\* `vehicle\_code`

\* `vehicle\_name`

\* `combination\_family`

\* `overall\_length\_m`

\* `overall\_height\_m`

\* `overall\_width\_m`

\* `operating\_mass\_t`

\* `mass\_scheme`

\* `pbs\_level`

\* `active`



\### `hvn.road\_segment`



Purpose:



Stores individual routable road-centreline segments.



Primary key:



\* `segment\_id`



Important fields:



\* `source\_dataset`

\* `source\_feature\_id`

\* `road\_name`

\* `road\_class`

\* `direction\_code`

\* `length\_m`

\* `source\_updated`

\* `active`

\* `geometry`



\### `hvn.road\_rule\_source`



Purpose:



Stores the authoritative or operational source supporting an access rule.



Primary key:



\* `source\_id`



Important fields:



\* `authority`

\* `document\_name`

\* `version`

\* `publication\_date`

\* `effective\_date`

\* `expiry\_date`

\* `retrieved\_at`

\* `document\_url`

\* `confidence\_level`

\* `notes`



\### `hvn.road\_access`



Purpose:



Associates a road segment and vehicle configuration with an access rule.



Primary key:



\* `access\_id`



Foreign keys:



\* `segment\_id` → `hvn.road\_segment.segment\_id`

\* `vehicle\_id` → `hvn.vehicle\_configuration.vehicle\_id`

\* `source\_id` → `hvn.road\_rule\_source.source\_id`



Important fields:



\* `access\_status`

\* `access\_direction`

\* `mass\_scheme`

\* `permit\_required`

\* `conditions\_text`

\* `effective\_from`

\* `effective\_to`

\* `verified\_at`

\* `confidence\_status`



\## 2. Relationships



```text

vehicle\_configuration

&#x20;       |

&#x20;       | one vehicle configuration

&#x20;       | may have many access rules

&#x20;       v

road\_access

&#x20;       ^

&#x20;       | many access rules may apply

&#x20;       | to road segments

&#x20;       |

road\_segment



road\_rule\_source

&#x20;       |

&#x20;       | one source may support

&#x20;       | many access rules

&#x20;       v

road\_access

```



\## 3. Staging Tables



Staging tables will be created only after inspecting the actual downloaded datasets.



Expected examples:



```text

staging.nhvr\_bdouble\_network\_raw

staging.osm\_roads\_raw

```



Their columns should initially preserve the source structure.



They must not be treated as permanent application tables.



\## 4. Proposed Version 0.2 Additions



\### `hvn.validation\_run`



Purpose:



Stores one route-validation event.



Proposed fields:



\* `validation\_id`

\* `vehicle\_id`

\* `validation\_name`

\* `validation\_date`

\* `origin\_text`

\* `destination\_text`

\* `overall\_status`

\* `created\_at`

\* `notes`



\### `hvn.validation\_segment`



Purpose:



Stores each road segment assessed during a validation run.



Proposed fields:



\* `validation\_segment\_id`

\* `validation\_id`

\* `segment\_id`

\* `sequence\_number`

\* `access\_id`

\* `resolved\_status`

\* `resolution\_notes`



These tables should not be created until the first imported datasets have been inspected and the route representation has been confirmed.



\## 5. Identifier Rules



\### Internal identifiers



Project RoadTrain primary keys are generated internally.



Examples:



\* `segment\_id`

\* `vehicle\_id`

\* `source\_id`

\* `access\_id`



\### Source identifiers



External identifiers are retained in separate fields.



Examples:



\* `source\_feature\_id`

\* dataset network identifiers;

\* OSM way identifiers;

\* NHVR feature identifiers.



External identifiers must not become permanent Project RoadTrain primary keys.



\## 6. Controlled Values



\### Access status



Allowed values:



\* `APPROVED`

\* `CONDITIONAL`

\* `PERMIT`

\* `PROHIBITED`

\* `UNKNOWN`



\### Direction



Allowed values:



\* `BOTH`

\* `FORWARD`

\* `REVERSE`



\### Confidence



Initial examples:



\* `OFFICIAL`

\* `ROAD\_MANAGER`

\* `FLEET\_VERIFIED`

\* `DRIVER\_VERIFIED`

\* `UNVERIFIED`



These values may later move into reference tables.



\## 7. Data Integrity Rules



\* A road-access record cannot exist without a road segment.

\* A road-access record cannot exist without a vehicle configuration.

\* An official road-access record must identify its source.

\* Expiry dates must not precede effective dates.

\* UNKNOWN must not be converted automatically to APPROVED.

\* Raw imported geometry must not overwrite permanent road geometry.

\* Deactivated source features should remain traceable for historical analysis.



\## 8. Spatial Principles



\* Road segments use line geometry.

\* Source data may use different coordinate reference systems.

\* Spatial matching must use a suitable projected coordinate system.

\* A spatial index must exist on significant geometry columns.

\* Matching must consider tolerance, overlap and parallel adjacent carriageways.

\* Spatial proximity alone must not automatically prove that two road features represent the same carriageway.



\## 9. Next Data-Modelling Decision



After inspecting the NHVR GeoPackage, determine whether it contains:



1\. approved network lines only;

2\. all roads with access attributes;

3\. separate network layers by vehicle class;

4\. directional attributes;

5\. network conditions;

6\. stable source feature identifiers.



That inspection will determine the exact staging-table and transformation design.




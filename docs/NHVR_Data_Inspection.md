\# NHVR Network Data Inspection



\## 1. Dataset Identification



\*\*Source authority:\*\* National Heavy Vehicle Regulator

\*\*Source system:\*\* NHVR National Network Map

\*\*Downloaded by:\*\* Alix Welsh

\*\*Download date:\*\* 21 July 2026

\*\*Original filename:\*\* `nhvr\_qld\_26m\_bdouble\_2026-07-21.gpkg`

\*\*Stored location:\*\* `data/nhvr/raw/`



\## 2. Selected Network



\*\*Jurisdiction:\*\* Queensland

\*\*Vehicle type:\*\* B-double

\*\*Maximum vehicle length:\*\* 26 metres

\*\*Mass scheme:\*\* General Mass Limits, where selectable

\*\*Other filters applied:\*\* None



\## 3. File Information



\*\*File format:\*\* GeoPackage

\*\*File size:\*\* 24,864 kb

\*\*Number of spatial layers:\*\* 

\*\*Number of non-spatial tables:\*\*



\## 4. Layer Summary



| Layer name           | Geometry type          | CRS                                | Feature count | Apparent purpose |

| -------------------- | ---------------------- | ---------------------------------: | ------------: | ---------------- |

| hvn\_assets           | Point (Point)          | EPSG:4326 - WGS 84 - Geographic    | 2474          |                  |

| hvn\_feature\_points   | Point (Point)          | EPSG:4326 - WGS 84 - Geographic    | 718           |                  |

| hvn\_feature\_polygons | Polygon (MultiPolygon) | EPSG:4326 - WGS 84 - Geographic    | 4             |                  |

| hvn\_road\_segments    | Line (LineString)      | EPSG:4326 - WGS 84 - Geographic    | 62673         |                  |



\## 5. Selected Primary Network Layer



\*\*Layer name:\*\* hvn\_road\_segments

\*\*Geometry type:\*\* Line (LineString)

\*\*CRS:\*\* EPSG:4326 - WGS 84 - Geographic

\*\*Feature count:\*\* 62673

\*\*Extent:\*\* Qld



\### Initial interpretation



Describe what one feature appears to represent.



Examples:



\* one complete road;

\* one road segment;

\* one access-network section;

\* one vehicle-access rule;

\* one multipart collection of approved roads.



\## 6. Field Inspection



| Field name                 | Data type | Example value | Likely meaning | Nulls observed |

| -------------------------- | --------- | ------------- | -------------- | -------------- |

| fid                        | integer64 | 0             |                |                |

| heavy\_vehicle\_network\_wkid | integer   | 0             |                |                |

| network\_name               | string    | 50            |                |                |

| road\_segment\_id            | integer64 | 0             |                |                |

| access\_code                | string    | 50            |                |                |

| access\_description         | string    | 0             |                |                |

| osm\_way\_id                 | integer64 | 0             |                |                |

| osm\_way\_version            | integer   | 0             |                |                |

| road\_name                  | string    | 255           |                |                |

| road\_manager\_codes         | string    | 0             |                |                |

| road\_manager\_names         | string    | 0             |                |                |



\## 7. Geometry Inspection



\### Geometry characteristics



\* Single-part or multipart:

\* Two-dimensional or three-dimensional:

\* Valid geometry:

\* Apparent segment length range:

\* Duplicate or overlapping features observed:

\* Separate carriageways observed:

\* Network gaps observed:



\### Visual observations



Record any obvious issues, including:



\* roads appearing offset from the QGIS basemap;

\* overlapping network classes;

\* disconnected line sections;

\* network lines covering only part of a road;

\* unusual geometry near intersections;

\* duplicated road sections;

\* missing local access roads.



\## 8. Access Information



Record whether the dataset appears to contain:



| Question                         | Yes / No / Unclear | Evidence |

| -------------------------------- | ------------------ | -------- |

| Approved routes only             | Yes                |          |

| Prohibited roads                 | No                 |          |

| Conditional access               | No                 |          |

| Permit-required sections         |                    |          |

| Directional restrictions         |                    |          |

| Road-manager identity            |                    |          |

| Access conditions                |                    |          |

| Effective dates                  |                    |          |

| Stable feature identifiers       |                    |          |

| Vehicle configuration attributes |                    |          |

| Mass-scheme attributes           |                    |          |



\## 9. Nambour–Brisbane Corridor Check



Inspect at least these locations:



\* Nambour;

\* Bruce Highway;

\* Caboolture;

\* Gateway Motorway;

\* Brisbane Markets, Rocklea.



Record whether the displayed network appears continuous between Nambour and Brisbane.



\### Apparent gaps



| Location | Road | Description of possible gap |

| -------- | ---- | --------------------------- |

|          |      |                             |



\## 10. Data Limitations



Record all limitations visible during inspection.



Possible examples:



\* approved-network geometry is not a routable graph;

\* source lines do not align precisely with the basemap;

\* no explicit access-status field exists;

\* only approved network features are supplied;

\* conditions are stored separately;

\* identifiers do not appear stable;

\* direction is not represented;

\* network selection is encoded only in the download parameters.



\## 11. Import Recommendation



Complete after inspection.



\*\*Recommended staging table name:\*\*



```text

staging.nhvr\_qld\_26m\_bdouble\_raw

```



\*\*Recommended import method:\*\*



\* QGIS Database Manager; or

\* `ogr2ogr`.



\*\*Geometry transformation required:\*\*



\*\*Fields that must be retained unchanged:\*\*



\*\*Fields requiring standardisation:\*\*



\*\*Questions requiring further investigation:\*\*



\## 12. Initial Conclusion



Summarise whether the dataset appears suitable for:



\* official access evidence;

\* spatial matching to a routable road network;

\* direct routing;

\* determining conditional access;

\* identifying permit requirements.




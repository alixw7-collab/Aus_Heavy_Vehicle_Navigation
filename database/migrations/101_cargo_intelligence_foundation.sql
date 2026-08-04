/*
===============================================================================
Project RoadTrain
Migration 101: Cargo Intelligence Foundation
===============================================================================

Purpose:
    Determine the cargo as a separate variable.

Australian Dangerous Goods (DG) Classes:
1 Explosives
2 Gases
3 Flammable Liquids
4 Flammable Solids
5 Oxidising Substances
6 Toxic/Infectious
7 Radioactive
8 Corrosive
9 Miscellaneous

Australian Dangerous Goods (DG) Packing Groups:
I
II
III
Not Applicable


Tunnel Categories:

Cargo
↓
Tunnel Category
↓
Road
↓
Tunnel
↓
Allowed?



Rules:
    - 


Reference Data
    │
    ▼
Vehicle Profiles
    │
    ▼
Cargo Profiles
    │
    ▼
Journey
    │
    ▼
Compliance Engine
    │
    ▼
Routing Engine

===============================================================================
*/



BEGIN;

CREATE TABLE IF NOT EXISTS reference.cargo_type
(
    cargo_type_id SMALLSERIAL PRIMARY KEY,

    cargo_code TEXT NOT NULL UNIQUE,

    cargo_name TEXT NOT NULL UNIQUE,

    description TEXT,

    is_regulated BOOLEAN
        NOT NULL
        DEFAULT FALSE,

    is_dangerous_goods BOOLEAN
        NOT NULL
        DEFAULT FALSE,

    is_active BOOLEAN
        NOT NULL
        DEFAULT TRUE
);

COMMENT ON TABLE reference.cargo_type IS
'Broad cargo classifications used for journey planning.';


INSERT INTO reference.cargo_type
(
    cargo_code,
    cargo_name,
    description,
    is_regulated,
    is_dangerous_goods
)

VALUES

('GENERAL',
 'General Freight',
 'General palletised freight.',
 FALSE,
 FALSE),

('REFRIGERATED',
 'Refrigerated Freight',
 'Temperature-controlled freight.',
 FALSE,
 FALSE),

('PETROLEUM',
 'Petroleum',
 'Bulk petroleum products.',
 TRUE,
 TRUE),

('LPG',
 'Liquefied Petroleum Gas',
 'Bulk LPG.',
 TRUE,
 TRUE),

('CHEMICAL',
 'Industrial Chemicals',
 'Industrial chemical products.',
 TRUE,
 TRUE),

('EXPLOSIVES',
 'Explosives',
 'Explosive materials.',
 TRUE,
 TRUE),

('WASTE',
 'Regulated Waste',
 'Waste requiring transport regulation.',
 TRUE,
 FALSE),

('LIVESTOCK',
 'Livestock',
 'Live animals.',
 TRUE,
 FALSE),

('OVERSIZE',
 'Oversize Load',
 'Oversize freight.',
 TRUE,
 FALSE),

('CONTAINER',
 'Container',
 'ISO shipping containers.',
 FALSE,
 FALSE)

ON CONFLICT DO NOTHING;
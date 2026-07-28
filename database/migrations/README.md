Database Migration Order

Migrations are executed in ascending numerical order.

Each migration should:
- Be idempotent where practical.
- Never modify previous migrations after they have been committed.
- Add new migrations rather than rewriting history.

Schemas:
- osm      = immutable imported OpenStreetMap data
- staging  = derived processing tables
- hvn      = routing engine tables
-- Project RoadTrain
-- OpenStreetMap road import configuration
-- Compatible with osm2pgsql flex output
-- Target schema: osm
-- Geometry storage CRS: EPSG:4326 (WGS 84)

local roads = osm2pgsql.define_way_table(
    'road_way',
    {
        { column = 'name',          type = 'text' },
        { column = 'ref',           type = 'text' },
        { column = 'highway',       type = 'text', not_null = true },
        { column = 'oneway',        type = 'text' },
        { column = 'junction',      type = 'text' },

        { column = 'maxspeed',      type = 'text' },
        { column = 'maxweight',     type = 'text' },
        { column = 'maxheight',     type = 'text' },
        { column = 'maxwidth',      type = 'text' },
        { column = 'maxlength',     type = 'text' },

        { column = 'access',        type = 'text' },
        { column = 'motor_vehicle', type = 'text' },
        { column = 'hgv',           type = 'text' },
        { column = 'hazmat',        type = 'text' },

        { column = 'bridge',        type = 'text' },
        { column = 'tunnel',        type = 'text' },
        { column = 'lanes',         type = 'text' },
        { column = 'surface',       type = 'text' },
        { column = 'smoothness',    type = 'text' },

        { column = 'tags',          type = 'jsonb' },

        {
            column = 'geom',
            type = 'linestring',
            projection = 4326,
            not_null = true
        }
    },
    {
        schema = 'osm'
    }
)

function osm2pgsql.process_way(object)
    if not object.tags.highway then
        return
    end

    roads:insert({
        name          = object.tags.name,
        ref           = object.tags.ref,
        highway       = object.tags.highway,
        oneway        = object.tags.oneway,
        junction      = object.tags.junction,

        maxspeed      = object.tags.maxspeed,
        maxweight     = object.tags.maxweight,
        maxheight     = object.tags.maxheight,
        maxwidth      = object.tags.maxwidth,
        maxlength     = object.tags.maxlength,

        access        = object.tags.access,
        motor_vehicle = object.tags.motor_vehicle,
        hgv           = object.tags.hgv,
        hazmat        = object.tags.hazmat,

        bridge        = object.tags.bridge,
        tunnel        = object.tags.tunnel,
        lanes         = object.tags.lanes,
        surface       = object.tags.surface,
        smoothness    = object.tags.smoothness,

        tags          = object.tags,
        geom          = object:as_linestring()
    })
end
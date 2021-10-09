local config = {}

config._serialization = require('serialization')

config._path = nil
config._file = nil

function config.isPathSet()
    return config._path == nil
end

function config.setPath(path)
    local file = io.open(path, "r")
    if file == nil then
        error(string.format('%s: File not found', path), 2)
        return
    end
    config._path = path
    config._file = file
end

function config.get(key)
    if config._file == nil then
        error("An attempt was made to call config.get before a path was set. Call config.setPath() beforehand.")
        return
    end
    local raw = config._file:read('*a')
    local cfg = config._serialization.unserialize(raw)
    return cfg[key]
end

return config
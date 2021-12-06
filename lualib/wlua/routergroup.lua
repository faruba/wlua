local log = require "log"
local wlua_methods = require "wlua.methods"
local util_json = require "util.json"
local util_file = require "util.file"

local M = {}
local mt = { __index = M }
local abort_index = 63

function M:new(app, base_path)
    log.debug("routergroup new")
    local instance = {
        app = app,
        base_path = base_path,
        handlers = {},
    }
    return setmetatable(instance, mt)
end

function M:calculate_absolute_path(relative_path)
    log.debug("calculate_absolute_path", self.base_path, relative_path)
    return util_file.path_join(self.base_path, relative_path)
end

function M:combine_handlers(handlers)
    local n = #self.handlers
    log.debug("combine_handlers. n:", n)
    assert(n+#handlers < abort_index, "too many handlers")

    local merged_handlers = {}
    for k,v in ipairs(self.handlers) do
        merged_handlers[k] = v
    end
    for k,v in ipairs(handlers) do
        merged_handlers[n+k] = v
    end
    return merged_handlers
end

function M:handle(method, relative_path, ...)
    local absolute_path = self:calculate_absolute_path(relative_path)
    local handlers = self:combine_handlers({...})
    self.app:add_route(method, absolute_path, handlers)
end

-- M:get(path, handle1, handle2, ...)
-- M:post(path, handle1, handle2, ...)
for method,_ in pairs(wlua_methods) do
    local l_name = string.lower(method)
    M[l_name] = function (self, path, ...)
        self:handle(method, path, ...)
    end
end


-- M:group("v1", ...)
function M:group(relative_path, ...)
    local absolute_path = self:calculate_absolute_path(relative_path)
    local routergroup = M:new(self.app, absolute_path)
    routergroup.handlers = self:combine_handlers({...})
    return routergroup
end

-- M:static_file("favicon.ico", "favicon.ico")
function M:static_file(relative_path, filepath)
    local function static_file_handler(c)
        c:file(filepath)
    end

    self:get(relative_path, static_file_handler)
    self:head(relative_path, static_file_handler)
    return self
end

-- M:static_dir("/static", "./")
function M:static_dir(relative_path, static_path)
    local function static_dir_handler(c)
        log.debug("static_dir_handler. c.params:", util_json.encode(c.params))
        local fpath = util_file.path_join(static_path, c.params.filepath)
        c:file(fpath)
    end
    local url_pattern = util_file.path_join(relative_path, "{filepath:.*}")
    self:get(url_pattern, static_dir_handler)
    self:head(url_pattern, static_dir_handler)
end

-- M:use(middleware1, middleware2, ...)
function M:use(...)
    local i = #self.handlers
    for _,v in pairs({...}) do
        i = i + 1
        self.handlers[i] = v
    end
end

return M

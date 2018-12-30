local mysql = require 'resty.mysql'
local cjson = require 'cjson'
local util = require 'util'
local conf = require 'conf'

local ngxlog = ngx.log

local random = math.random

local mysql_prefix = 'jdbc:mysql://'
local datasources = {}

local function parse_mysql_option(str)
    local options = {}
    for _, str in ipairs(util.split(str, '&')) do
        local kvs = util.split(str, '=')
        if kvs[1] and kvs[2] and kvs[1] ~= '' and kvs[2] ~= '' then
            options[kvs[1]] = kvs[2]
        end
    end
    return options
end

local function parse_mysql(config)
    if not config.url then
        return nil, '\'url\' must config'
    end
    local info = util.split(string.sub(config.url, string.len(mysql_prefix) + 1), '/')
    local addr_info, db_info = util.split(info[1], ':'), info[2] 
    --parse host info
    local addr = { host = addr_info[1], port = addr_info[2] }

    --parse jdbc url args
    local db, options = nil, {}
    local idx = string.find(db_info, '?', 1, true)
    if idx then
        if idx < string.len(db_info) then
            options = parse_mysql_option(string.sub(db_info, idx + 1))
        end
        db =  string.sub(db_info, 1, idx - 1)
    else
        db = db_info
    end

    if not addr.host or not addr.port or not db then
        return nil, 'invalid \'url\' config'
    end

    return {
        addr = addr,
        db = db,
        options = options or {}
    }
end

for name, config in pairs(conf.datasources) do
    if config.driver == 'mysql' then
        local datasource, err = parse_mysql(config)
        if not datasource then
            ngxlog(ngx.ERR, 'parse mysql config err:', err)
        else
            datasources[name] = datasource
        end
    else
        ngxlog(ngx.ERR, 'now we only support mysql driver')
    end
end

ngxlog(ngx.DEBUG, 'datasource config:', cjson.encode(datasources))

local _M = {}

local mt = {__index = _M}

function _M.new(name)
    if not name or not datasources[name] then
        return nil, 'no such datasource \'' .. (name or nil) .. '\''
    end

    return setmetatable({datasource = datasources[name]}, mt)
end

local function connect(datasource)
    local options = datasource.options

    local db = mysql:new()
    db:set_timeout(options.connectTimeout or 5000)
    local opts = {
        host = datasource.addr.host,
        port = datasource.addr.port,
        database = datasource.db,
        user = options.user,
        password = options.password,
        charset = options.characterEncoding or 'utf8'
    }
    local ok, err = db:connect(opts)
    if not ok then
        return nil, err
    end

    --[[
    local reused = db:get_reused_times()
    if not reused or reused <= 0 then
        local res, err, errno, sqlstate = db:query('set names '' .. opts.charset .. ''')
        if not res then
            ngxlog(ngx.ERR, 'execute[ set names utf8] error: ', err, ': ', errno, ' ', sqlstate)
        end
    end
    --]]

    db:set_timeout(options.socketTimeout or 5000)
    return db
end

--[[
--sql: single result set query 
--response:
--format of query: 
--{
--  {col1=xxx, col2=xxx},
--  {col1=xxx, col2=xxx}
--  ...
--}
--
--format of update: 
--{
--  insert_id = 0,
--  server_status = 2,
--  warning_count = 0,
--  affected_rows = 1,
--  message = xxx
--}
--]]
function _M.exec_one(self, sql)
    local datasource = self.datasource
    ngxlog(ngx.DEBUG, 'run \'', sql, '\' on mysql[', datasource.addr.host, ':', datasource.addr.port, ']')
  
    local db, err = connect(datasource)
    if not db then
        return nil, err
    end

    local res, err, errno, sqlstate = db:query(sql)
    if not res then
        ngxlog(ngx.ERR, 'execute[', sql, ']error: ', err, ': ', errno, ' ', sqlstate)
        return nil, err
    end
    local ok, err = db:set_keepalive(60000, 50)
    if not ok then
        ngxlog(ngx.ERR, 'set mysql connection keepalive failure: ', err)
    end

    return res
end

--[[
--sql: multi result set query
--response:
 --list of exec_one result
 --
--]]
function _M.exec_multi(self, sql)
    local datasource = self.datasource
    ngxlog(ngx.DEBUG, 'run \'', sql, '\' on mysql[', datasource.addr.host, ':', datasource.addr.port, ']')
  
    local db, err = connect(datasource)
    if not db then
        return nil, err
    end
    local res, err, errno, sqlstate = db:query(sql)
    if not res then
        ngxlog(ngx.ERR, 'execute[', sql, ']error: ', err, ': ', errno, ' ', sqlstate)
        return nil, err
    end
    local ress = {res}
    while err == 'again' do
        res, err, errno, sqlstate = db:read_result()
        if not res then
            ngxlog(ngx.ERR, 'execute[', sql, ']error: ', err, ': ', errno, ' ', sqlstate)
            return nil, err
        end
        ress[#ress + 1] = res
    end

    local ok, err = db:set_keepalive(60000, 50)
    if not ok then
        ngxlog(ngx.ERR, 'set mysql connection keepalive failure: ', err)
    end

    return ress
end

return _M

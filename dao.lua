local mysql = require 'mysql'
local cjson = require 'cjson'
local conf = require 'conf'
local util = require 'util'

local strsub = string.sub
local strfind = string.find
local strlen = string.len
local concat = table.concat

local ngxlog = ngx.log

local METHODS = {}

local MYSQL_TYPE = {
    tinyint = true,
    smallint = true,
    mediumint = true,
    int = true,
    bigint = true,
    varchar = true,
    char = true,
    text = true,
    longtext = true,
    date = true,
    timestamp = true,
    datetime = true,
    float = true,
    double = true
}

local function formatVal(type, val)
        if strfind(type, 'int') 
            or strfind(type, 'float') 
            or strfind(type, 'decimal') 
            or strfind(type, 'double') then
            return val
        else
            return ngx.quote_sql_str(val)
        end
end

local function generateQuery(colSet, conditions)
    local match = {}
    for k, v in pairs(conditions or {}) do
        if not colSet[k] then
            return nil, 'no such attr: ' .. k
        end
        match[#match + 1] = '`' .. k .. '`=' .. formatVal(colSet[k].Type, v)
    end
    if #match == 0 then
        return '1=1'
    end

    return concat(match, 'and')
end

--[[
--we provide follow method
 --select(conditions, fields). query row by conditions and output fields
 --update(conditions, newvalue). update row to newvalue where conditions is match
 --insert(record, opt). add new row to table, supprot return_insert_id option when primary key is autoincrement
 --delete(conditions). delete row by conditions
--]]
local function register(namespace, db, methods)
    for k, v in pairs(methods) do
        local sqlDesc = {}
        local lastPos = 1
        local ctx = {}
        while true do
            local m, err = ngx.re.match(v, '{\\s*(\\w+)\\s*,\\s*type=(\\w+)\\s*}', 'jo', ctx)
            if not m then
                sqlDesc[#sqlDesc + 1] = strsub(v, lastPos)
                break
            end

            if not MYSQL_TYPE[m[2]] then
                error('error format in sql \'' .. v .. '\': invalid db type: ' .. m[2])
            end

            sqlDesc[#sqlDesc + 1] = strsub(v, lastPos, ctx.pos-1-strlen(m[0]))
            sqlDesc[#sqlDesc + 1] = {
                field = m[1],
                type = m[2]
            }
            lastPos = ctx.pos
        end

        ngxlog(ngx.DEBUG, 'sql desc:', cjson.encode(sqlDesc))

        METHODS[namespace..'#'..k] = function(param, opt)
            local singleParam
            if type(param) ~= 'table' then
                singleParam = param
            end

            local sql = {}
            for _, v in ipairs(sqlDesc) do
                if type(v) == 'table' then
                    if not singleParam and not param[v.field] then
                        return nil, 'missing paramater:' .. v.field
                    end
                    sql[#sql+1] = formatVal(v.type, singleParam or param[v.field])
                else
                    sql[#sql+1] = v
                end
            end
            local res, err = db:exec_one(concat(sql))
            if not res then
                return nil, err
            end

            if opt and opt.only_one then
                return res[1]
            else
                return res
            end
        end
    end

    local res, err = db:exec_one('desc ' .. namespace .. ';');
    if not res then
        ngxlog(ngx.WARN, 'no such table: ', namespace, '; ignore')
        return
    end

    ngxlog(ngx.DEBUG, 'table[', namespace, '] metadata: ', cjson.encode(res))

    local colSet = {}
    local priCol
    for _, col in ipairs(res) do
        colSet[col.Field] = col
        if col.Key == 'PRI' then
            priCol = col
        end
    end

    METHODS[namespace..'#select'] = function(conditions, fields)
        local selected = {}
        for _, field in ipairs(fields or {}) do
            if not colSet[field] then
                return nil, 'no such attr: ' .. field
            end

            selected[#selected + 1] = field
        end
        local f
        if #selected == 0 then
            f = '*'
        else
            f = concat(selected, ',')
        end

        local sql = {'select', f, 'from', namespace, 'where', generateQuery(colSet, conditions)}

        local res, err = db:exec_one(concat(sql, ' ')) 
        if not res then 
            return nil, err
        end

        return res
    end

    METHODS[namespace..'#update'] = function(conditions, record)
        local kvs = {}
        for k, v in pairs(record) do
            if not colSet[k] then
                return nil, 'no such attr: ' .. k
            end
            if k ~= priCol.Field then
                kvs[#kvs+1] = k .. '=' .. formatVal(colSet[k].Type, v)
            end
        end

        local sql = {'update', namespace, 'set', concat(kvs, ','), 'where', generateQuery(colSet, conditions)}

        local res, err = db:exec_one(concat(sql, ' ')) 
        if not res then
            return nil, err
        end
        return res.affected_rows
    end

    METHODS[namespace..'#insert'] = function(record, opt)
        local keys = {}
        local vals = {}
        for k, v in pairs(record) do
            if not colSet[k] then
                return nil, 'no such attr: ' .. k
            end
            keys[#keys + 1] = '`' .. k .. '`'
            vals[#vals + 1] = formatVal(colSet[k].Type, v)
        end

        local sql = {'insert into', namespace, '(', concat(keys, ',') ,')values(', concat(vals, ','), ')'}

        local res, err = db:exec_one(concat(sql, ' ')) 
        if not res then
            return nil, err
        end

        if opt and opt.return_insert_id then
            return res.insert_id
        else
            return res.affected_rows
        end
    end

    METHODS[namespace..'#delete'] = function(conditions)
        local sql = {'delete from', namespace, 'where', generateQuery(colSet, conditions)}

        local res, err = db:exec_one(concat(sql, ' ')) 
        if not res then
            return nil, err
        end
        return res.affected_rows
    end
end

local _M = {}

local mapper_dir = 'mapper'

function _M.init()
    local mapper_path = conf.mapper_path
    if mapper_path:byte(1) ~= 47 then --if not absoublte path, default directory is nginx work path
        mapper_path = ngx.config.prefix() .. conf.mapper_path
    end
    local tmp_path = ngx.config.prefix() .. 'file.tmp.' .. ngx.worker.pid()
    local ok = os.execute('ls ' .. mapper_path .. '> ' .. tmp_path)
    if ok ~= 0 then
        ngxlog(ngx.ERR, 'init dao failure:could not found mapper location')
        return
    end

    local fd, err = io.open(tmp_path, 'r')
    if not fd then
        ngxlog(ngx.ERR, 'init dao failure:', err)
        return
    end

    local content, err = fd:read('*a')
    os.remove(tmp_path)
    if not content then
        ngxlog(ngx.ERR, 'init dao failure:', err)
        return
    end

    local files = util.split(content, '%s+')
    ngxlog(ngx.DEBUG, 'found mappers: ', cjson.encode(files))
    for _, file in ipairs(files) do
        local ns = ngx.re.match(file, '(\\w+)\\.lua$', 'jo')
        if ns then
            ns = ns[1]
            local t = require(mapper_dir .. '.' .. ns)
            local table = rawget(t, 'table')
            if table then
                ns = table
            end
            t.namespace = ns
            local db, err = mysql.new(rawget(t, 'db'))
            if not db then
                ngxlog(ngx.ERR, 'init dao failure:', err)
                return
            end
            register(ns, mysql.new(rawget(t, 'db')), rawget(t, 'method'))
        end
    end
end

function _M.exec(self, key)
    local table = rawget(self, 'table')
    return METHODS[table ..'#'..key]
end

_M.init()

return _M

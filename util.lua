local restystring = require 'resty.string'

local strfind = string.find
local strgmatch = string.gmatch
local strsub = string.sub
local strgsub = string.gsub
local strlen = string.len
local strbyte = string.byte
local floor = math.floor

local _M = {}

--[[ NOTE: where delim can not be one of these characters(^$()%.[]*+-?) ]]
function _M.split(str, delim, maxNb)   
    if delim == nil then delim = ',' end

    if strfind(str, delim) == nil then  
        return { str };
    end

    if maxNb == nil or maxNb < 1 then  
        maxNb = 0;    -- No limit   
    end

    -- let last field happy
    local str = str .. delim;

    local result = {};
    local pat = '(.-)' .. delim;   
    local nb = 0;
    local lastPos;   
    for part in strgmatch(str, pat) do  
        nb = nb + 1;
        result[nb] = part;
        if nb == maxNb then break end  
    end  

    return result;   
end

local function _table_to_sort_kv(info)
    -- k-v table
    local array = {}
    for k, v in pairs(info) do
        array[#array + 1] = k;
    end

    table.sort(array);

    local str = {};
    for _, key in ipairs(array) do
        local val = info[key];
        if type(val) ~= 'table' then
            str[#str + 1] = key .. '=' .. tostring(val) .. '&';
        end
    end

    return table.concat(str);
end

function _M.get_time_ms(time, h, m, s)
    local tmp = _M.split(time, ' ');
    if #tmp ~= 2 then
        return nil;
    end

    local tm1 = _M.split(tmp[1], '-');
    local tm2 = _M.split(tmp[2], ':');

    if #tm1 ~= 3 or #tm2 ~= 3 then
        return nil;
    end

    local tm_s = {
        year = tm1[1],
        month = tm1[2],
        day = tm1[3],
        hour = tm2[1],
        min = tm2[2],
        second = tm2[3],
    }

    return os.date('%s', os.time(tm_s));
end


function _M.trim(str)
    local tmp = string.gsub(str, '^%s+', '');
    local tmp = string.gsub(tmp, '%s+$', '');
    return tmp;
end


function _M.concat_table(table1, table2)
    if type(table1) ~= 'table' or type(table2) ~= 'table' then
        return {};
    end
    for i,v in ipairs(table2) do
        table.insert(table1, v);
    end
    return table1;
end

_M.debug = true;

return _M;

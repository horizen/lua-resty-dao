local dao = require "dao"

local method = {
}

return setmetatable({db='test', table='ext', method=method}, {__index = dao.exec})

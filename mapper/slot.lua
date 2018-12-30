local dao = require "dao"

local method = {
    getAll = [[select * from slot a, ext b where a.id=b.id]]
}

return setmetatable({db='test', table='slot', method=method}, {__index = dao.exec})

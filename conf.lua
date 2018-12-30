local _M = {}

--datasource config
_M.datasources = {
    test = {
        --db driver, now we only support mysql
        driver = 'mysql',
        --jdbc url. more detail please see https://dev.mysql.com/doc/connector-j/8.0/en/connector-j-reference-jdbc-url-format.html
        url = 'jdbc:mysql://127.0.0.1:3306/test'
    },
}

--where mapper file location
--absolute path or relative path base nginx work directory
--_M.mapper_path = 'src/dao/mapper/'
_M.mapper_path = '/Users/yaowei/github/horizen/lua_resty_dao/lib/mapper/'

return _M

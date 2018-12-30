Name
====

lua-resty-dao Simple database dal library

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Description](#description)
* [Synopsis](#synopsis)
* [Methods](#methods)
    * [new](#new)
    * [connect](#connect)
    * [set_timeout](#set_timeout)
    * [set_keepalive](#set_keepalive)
    * [get_reused_times](#get_reused_times)
    * [close](#close)
    * [send_req](#send_req)
    * [receive](#receive)
    * [request](#request)

* [License](#license)


Status
======
This library is considered production ready.

Description
===========
This Lua library is a simple database client that provides abstract access like mybtais and is easy to use

Synopsis
=======

worker_processes  1;

error_log logs/error.log warn;

events {
    worker_connections  1024;
}


http {
    lua_package_path '${prefix}src/?.lua;;';

    init_worker_by_lua_file dao.lua;
    server {
        listen   8000;
        location /test {
            content_by_lua_file test.lua
        }
    }
}

Example use
---
to use the library, we first need database configurtion



[Back to TOC](#table-of-contents)

Build-in Methods
=======

insert
---
`syntax: res = mapper:insert(record_table, opt_table?)`

Insert a new record, the first argument is key-value lua table where match for database table schema

An option Lua table can be specified as the last argument to this method to specify various connect options:

* `return_insert_id`

    Specifies return primary id when the table have auto increment primary key

when return_insert_id is the method return primary id, or else it return affected rows

[Back to TOC](#table-of-contents)

update
-------
`syntax: ret = mapper:update(condition_table, newvalue_table)`

Update to newvalue when condition is match

The first argument is key-value format table for query condition, second argument is table than hold key-value pair for new value

It return affected rows number

[Back to TOC](#table-of-contents)

select
----------
`syntax: res = mapper:select(condition_table?, output_fields_table?)`

Select fields from db when condition is match

The first argument is key-value format table for query condition, second argument is array for mark output fields

When first argument is not specified, it means select all rows

When second argument is not spedified, it means output all fields

The method return an array of rows, the format is like

{
  {key1=value1, key2=value2},

  {key1=value1, key2=values}

}

[Back to TOC](#table-of-contents)

delete
------------
`syntax: res = mapper:delete(condition_table?)`

The first argument is key-value format table for query condition, if not specified the behavior is delete all rows

It return affected rows number

[Back to TOC](#table-of-contents)

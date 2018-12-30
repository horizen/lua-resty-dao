local slot = require 'mapper.slot'
local ext = require 'mapper.ext'
local cjson = require 'cjson'

local dao = require 'dao'
dao.init()

--[[
CREATE DATABASE test DEFAULT CHARSET=utf8;
CREATE TABLE `slot` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `name` varchar(256) NOT NULL COMMENT '姓名',
  `age` int(11) NOT NULL COMMENT '年龄',
  PRIMARY KEY (`id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

  CREATE TABLE `ext` (
   `id` int(11) NOT NULL COMMENT 'id',
   `address` varchar(256) NOT NULL COMMENT '地址',
   `phone` varchar(15) NOT NULL COMMENT '联系方式',
   PRIMARY KEY (`id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
--]]

local id = slot.insert({name='yw',age='20'}, {return_insert_id=true})
ngx.say('insert slot return ', id)
ngx.say('select age ', cjson.encode(slot.select({id=id}, {'age'})))
ngx.say('update return ', slot.update({id=id}, {name='wj'}))
ngx.say('select all fields ', cjson.encode(slot.select({id=id})))
id = slot.insert({name='yw',age='20'}, {return_insert_id=true})
ngx.say('select all ', cjson.encode(slot.select()))

ngx.say('insert ext return ', ext.insert({id=id, address='test',phone='1202390232'}))

ngx.say('inner join ', cjson.encode(slot.getAll()))

ngx.say('delete slot ', slot.delete())
ngx.say('delte ext ', ext.delete())

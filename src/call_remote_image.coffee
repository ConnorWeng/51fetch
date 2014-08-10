http = require 'http'

database = require './database'
config = require './config'

db = new database
  host: 'rdsqr7ne2m2ifjm.mysql.rds.aliyuncs.com'
  user: 'wangpi51'
  password: '51374b78b104'
  database: 'ecmall51'
  port: 3306

db.getGoodsWithRemoteImage (err, goods) ->
  if err then throw err
  makeLocal good for good in goods

makeLocal = (good) ->
  http.get "#{config.remote_service_address}&goodid=#{good.goods_id}", (res) ->
    console.log "goods_id: #{good.goods_id}, status: #{res.statusCode}"

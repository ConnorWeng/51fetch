http = require 'http'
url = require 'url'
querystring = require 'querystring'
Q = require 'q'
{log, error} = require 'util'
config = require './config'
{crawlStore, setDatabase} = require './taobao_crawler'
database = require './database'

db = new database config.database[args[0]]
setDatabase db
getStores = Q.nbind db.getStores, db

http.createServer((req, res) ->
  querys = querystring.parse url.parse(req.url).query
  storeId = querys.store_id
  getStores "store_id = #{storeId}"
    .then (store) ->
      crawl store, ->
  res.end 'ok'
).listen 9000

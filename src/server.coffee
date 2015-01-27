http = require 'http'
Q = require 'q'
{log, error} = require 'util'
config = require './config'
{crawlStore, setDatabase} = require './taobao_crawler'
database = require './database'

args = process.argv.slice 2
port = 9000

db = new database config.database[args[0]]
setDatabase db
getStores = Q.nbind db.getStores, db

http.createServer((req, res) ->
  urlParts = req.url.split '/'
  if urlParts.length is 3 and urlParts[1] is 'store'
    storeId = urlParts[2]
    log "ready to crawl store #{storeId}"
    getStores "store_id = #{storeId}"
      .then (stores) ->
        crawlStore stores[0], ->
  res.end 'ok'
).listen port

log "server is listening: #{port}"

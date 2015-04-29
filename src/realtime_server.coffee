http = require 'http'
Q = require 'q'
{log, error} = require 'util'
env = require('jsdom').env
jquery = require('jquery')
config = require './config'
{setRateLimits, crawlStore, setDatabase, getCrawler, extractItemsFromContent, extractImWw} = require './taobao_crawler'
database = require './database'

args = process.argv.slice 2
port = 30005

db = new database config.database[args[0]]
setDatabase db
setRateLimits 100
query = Q.nbind db.query, db

tasks = []

http.createServer((req, res) ->
  urlParts = req.url.split '/'
  if urlParts.length is 3 and urlParts[1] is 'store'
    storeId = urlParts[2]
    halfHourAgo = db.getDateTime() - 1 * 30 * 60
    query "select count(1) cnt from ecm_goods where store_id = #{storeId} and last_update > #{halfHourAgo}; select count(1) total from ecm_goods where store_id = #{storeId}; select * from ecm_store where store_id = #{storeId};"
      .then (result) ->
        store = result[2][0]
        log "store #{storeId}: in hour count #{result[0][0].cnt}, total #{result[1][0].total}, url #{store.shop_http}, halfHourAgo #{halfHourAgo}"
        if result[0][0].cnt is 0
          log "store #{storeId}: ready crawl if need"
          crawlStore store, false, ->
            res.end 'ok'
        else
          log "store #{storeId}: has updated in an hour, so no need crawl for now"
          res.end 'ok'
      , (err) ->
          error "id:#{storeId} query returns err: #{err}"
          res.end 'err'
).listen port

log "server is listening: #{port}"

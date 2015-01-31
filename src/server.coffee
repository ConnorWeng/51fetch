http = require 'http'
Q = require 'q'
{log, error} = require 'util'
config = require './config'
{crawlStore, setDatabase} = require './taobao_crawler'
{startCrawl} = require './crawler'
database = require './database'

args = process.argv.slice 2
port = 9000

db = new database config.database[args[0]]
setDatabase db
getStores = Q.nbind db.getStores, db
query = Q.nbind db.query, db

http.createServer((req, res) ->
  urlParts = req.url.split '/'
  if urlParts.length is 3 and urlParts[1] is 'store'
    storeId = urlParts[2]
    hourAgo = db.getDateTime() - 1 * 60 * 60
    query "select count(1) cnt from ecm_goods where store_id = #{storeId} and last_update > #{hourAgo}; select count(1) total from ecm_goods where store_id = #{storeId}; select shop_http from ecm_store where store_id = #{storeId};"
      .then (res) ->
        log "store #{storeId}: cnt #{res[0][0].cnt}, total #{res[1][0].total}, url #{res[2][0].shop_http}, hourAgo #{hourAgo}"
        if res[0][0].cnt is 0
          log "store #{storeId}: ready crawl if need"
          crawlStoreIfNeed storeId, res[2][0].shop_http, res[1][0].total, hourAgo
        else
          log "store #{storeId}: has updated in an hour, so no need crawl for now"
  res.end 'ok'
).listen port

crawlStoreIfNeed = (storeId, shopHttp, total, time) ->
  url = "#{shopHttp}/search.htm?search=y&orderType=newOn_desc"
  startCrawl url, {},
    handler: (page) ->
      log "store #{storeId}: search result #{page.searchResult}"
      if parseInt(page.searchResult) isnt total
        getStores "store_id = #{storeId}"
          .then (stores) ->
            crawlStore stores[0], ->
      Q 'trival'
    searchResult:
      selector: '.search-result span'
      type: 'text'

log "server is listening: #{port}"

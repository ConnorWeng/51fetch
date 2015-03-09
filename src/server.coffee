http = require 'http'
Q = require 'q'
{log, error} = require 'util'
env = require('jsdom').env
jquery = require('jquery')
config = require './config'
{crawlStore, setDatabase, getCrawler, extractItemsFromContent, extractImWw} = require './taobao_crawler'
database = require './database'

args = process.argv.slice 2
port = 9000

db = new database config.database[args[0]]
setDatabase db
c = getCrawler()
query = Q.nbind db.query, db

http.createServer((req, res) ->
  urlParts = req.url.split '/'
  if urlParts.length is 3 and urlParts[1] is 'store'
    storeId = urlParts[2]
    hourAgo = db.getDateTime() - 1 * 60 * 60
    query "select count(1) cnt from ecm_goods where store_id = #{storeId} and last_update > #{hourAgo}; select count(1) total from ecm_goods where store_id = #{storeId}; select * from ecm_store where store_id = #{storeId};"
      .then (res) ->
        store = res[2][0]
        log "store #{storeId}: in hour count #{res[0][0].cnt}, total #{res[1][0].total}, url #{store.shop_http}, hourAgo #{hourAgo}"
        if res[0][0].cnt is 0
          log "store #{storeId}: ready crawl if need"
          crawlStoreIfNeed store
        else
          log "store #{storeId}: has updated in an hour, so no need crawl for now"
  res.end 'ok'
).listen port

crawlStoreIfNeed = (store) ->
  storeId = store['store_id']
  shopHttp = store['shop_http']
  url = "#{shopHttp}/search.htm?search=y&orderType=newOn_desc"
  c.queue [
    'uri': url
    'forceUTF8': true
    'callback': (err, result) ->
      if result.body is ''
        error "id:#{storeId} doesn't exist"
      else
        env result.body, (err, window) ->
          $ = jquery window
          imWw = extractImWw $, store['store_id'], store['store_name']
          if imWw then db.updateImWw store['store_id'], store['store_name'], imWw
          items = extractItemsFromContent $, store
          db.saveItems store['store_id'], store['store_name'], items, url, '所有宝贝', ->
          window.close()
  ]

log "server is listening: #{port}"

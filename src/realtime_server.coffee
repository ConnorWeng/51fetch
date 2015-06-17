http = require 'http'
{parse} = require 'url'
Q = require 'q'
{log, error} = require 'util'
env = require('jsdom').env
jquery = require('jquery')
config = require './config'
{crawlItemViaApi, $fetch, crawlItemsInStore, setRateLimits, crawlStore, setDatabase, getCrawler, extractItemsFromContent, extractImWw} = require './taobao_crawler'
{getTaobaoItem} = require './taobao_api'
database = require './database'

args = process.argv.slice 2
port = 30005

db = new database config.database[args[0]]
setDatabase db
setRateLimits 100
query = Q.nbind db.query, db

needCrawlItemsViaApi = true if args.length is 2 and args[1] is 'api'

response = (res, jsonp, body) ->
  if jsonp
    type = 'text/javascript'
    content = "#{jsonp}(#{body});"
  else
    type = 'text/plain'
    content = "#{body}"
  res.writeHead 200,
    'Content-Length': content.length
    'Content-Type': "#{type};charset=utf-8"
  res.write content
  res.end()

handleStore = (req, res, storeId, jsonp_callback) ->
  halfHourAgo = db.getDateTime() - 1 * 30 * 60
  query "select count(1) cnt from ecm_goods where store_id = #{storeId} and last_update > #{halfHourAgo}; select count(1) total from ecm_goods where store_id = #{storeId}; select * from ecm_store where store_id = #{storeId} and state = 1;"
    .then (result) ->
      store = result[2][0]
      if not store
        error "id:#{storeId} not passed or not exists"
        response res, jsonp_callback, "{'error': true, 'message': 'id:#{storeId} not passed or not exists'}"
        return
      log "store #{storeId}: in half hour count #{result[0][0].cnt}, total #{result[1][0].total}, url #{store.shop_http}, halfHourAgo #{halfHourAgo}"
      if result[0][0].cnt is 0
        log "store #{storeId}: ready crawl if need"
        crawlStore store, false, ->
          if needCrawlItemsViaApi
            crawlItemsInStore storeId, ->
              response res, jsonp_callback, "{'status': 'ok'}"
          else
            response res, jsonp_callback, "{'status': 'ok'}"
      else
        log "store #{storeId}: has updated in half hour, so no need crawl for now"
        response res, jsonp_callback, "{'status': 'ok'}"
    , (err) ->
        error "id:#{storeId} query returns err: #{err}"
        response res, jsonp_callback, "{'error': true, 'message': 'id:#{storeId} query returns err: #{err}'}"

handleNewItem = (req, res, itemUri, jsonp_callback) ->
  matches = itemUri.match /id=(\d+)/
  goodsId = matches?[1]
  getTaobaoItem goodsId, 'title,nick,pic_url,price,', (err, good) ->
    if err
      response res, jsonp_callback, "{'error': true, 'message': 'failed to call taobao api'}"
      return;
    goodHttp = "http://item.taobao.com/item.htm?id=#{goodsId}"
    items = [
      goodsName: good.title
      defaultImage: good.pic_url
      price: good.price
      goodHttp: goodHttp
    ]
    db.getStores "im_ww = '#{good.nick}'", (err, stores) ->
      if err or not stores?
        response res, jsonp_callback, "{'error': true, 'message': 'cannot find store which url is #{shopHttp}'}"
      else
        store = stores[0]
        storeId = store['store_id']
        storeName = store['store_name']
        db.saveItems storeId, storeName, items, goodHttp, '所有宝贝', 1, ->
          crawlItemsInStore storeId, ->
            response res, jsonp_callback, "{'status': 'ok'}"

handleUpdateItem = (req, res, goodsId, jsonp_callback) ->
  db.query "select * from ecm_goods where goods_id = #{goodsId}", (err, goods) ->
    good = goods[0]
    crawlItemViaApi good, () ->
      log "#{good['goods_id']}:#{good['goods_name']} updated manually"
      response res, jsonp_callback, "{'status': 'ok'}"

handleDeleteItem = (req, res, numIid, jsonp_callback) ->
  likeGoodHttp = "http://item.taobao.com/item.htm?id=#{numIid}%"
  db.query "call delete_good('#{likeGoodHttp}')", (err, result) ->
    if err
      response res, jsonp_callback, "{'error': true, 'message': 'handle delete item failed'}"
    else
      response res, jsonp_callback, "{'status': 'ok'}"

matchUrlPattern = (urlParts, pattern) ->
  match = true;
  patternParts = pattern.split '/'
  for p, i in patternParts
    if (p.indexOf('{') isnt 0) and (urlParts[i] isnt p)
      match = false
  match

http.createServer((req, res) ->
  urlObj = parse req.url, true
  urlParts = urlObj.pathname.split '/'
  if matchUrlPattern urlParts, '/store/{storeId}'
    storeId = urlParts[2]
    handleStore req, res, storeId, urlObj.query.jsonp_callback
  else if matchUrlPattern urlParts, '/item'
    handleNewItem req, res, urlObj.query.itemUri, urlObj.query.jsonp_callback
  else if matchUrlPattern urlParts, '/update'
    handleUpdateItem req, res, urlObj.query.goodsId, urlObj.query.jsonp_callback
  else if matchUrlPattern urlParts, '/delete'
    handleDeleteItem req, res, urlObj.query.numIid, null
).listen port

log "server is listening: #{port}"

if process.env.NODE_ENV is 'test'
  exports.matchUrlPattern = matchUrlPattern

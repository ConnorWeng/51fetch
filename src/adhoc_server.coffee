http = require 'http'
{parse} = require 'url'
Q = require 'q'
phpjs = require 'phpjs'
{log, error} = require './util'
env = require('jsdom').env
jquery = require('jquery')
config = require './config'
{getTaobaoItemsOnsaleBatch, getTaobaoItemsSellerListBatch} = require './taobao_api'
{crawlTaobaoItem, crawlItemViaApi, $fetch, crawlItemsInStore, crawlStore, setDatabase, extractItemsFromContent, extractImWw, parsePrice, removeSingleQuotes, parseSkus} = require './taobao_crawler'
database = require './database'

args = process.argv.slice 2
port = 30005

db = new database config.database[args[0]]
setDatabase db
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
            crawlItemsInStore storeId, null, ->
              response res, jsonp_callback, "{'status': 'ok'}"
          else
            response res, jsonp_callback, "{'status': 'ok'}"
      else
        log "store #{storeId}: has updated in half hour, so no need crawl for now"
        response res, jsonp_callback, "{'status': 'wait'}"
    , (err) ->
        error "id:#{storeId} query returns err: #{err}"
        response res, jsonp_callback, "{'error': true, 'message': 'id:#{storeId} query returns err: #{err}'}"

handleNewItem = (req, res, numIid, nick, title, price, jsonp_callback) ->
  log "#{nick} add a new item: #{title} #{price}"
  query "select * from ecm_store s left join ecm_member_auth a on s.im_ww = a.vendor_user_nick and a.state = 1 where s.im_ww = '#{nick}'", (err, stores) ->
    if err or not stores[0]?
      response res, jsonp_callback, "{'error': true, 'message': 'cannot find store which im_ww is #{nick}'}"
    else
      store = stores[0]
      storeId = store['store_id']
      storeName = store['store_name']
      accessToken = store['access_token']
      if accessToken
        goodHttp = "http://item.taobao.com/item.htm?id=#{numIid}"
        items = [
          goodsName: title
          defaultImage: ''
          price: parsePrice price, store['see_price'], title
          taobaoPrice: parsePrice price
          goodHttp: goodHttp
        ]
        db.saveItems storeId, storeName, items, goodHttp, '所有宝贝', 1, ->
          crawlItemsInStore storeId, accessToken, ->
            response res, jsonp_callback, "{'status': 'ok'}"
      else
        response res, jsonp_callback, "{'error': true, 'message': '#{nick} no session'}"

submitNewItem = (req, res, itemUri, jsonp_callback) ->
  matches = itemUri.match /id=(\d+)/
  goodsId = matches?[1]
  crawlTaobaoItem goodsId, (err, good) ->
    if err
      response res, jsonp_callback, "{'error': true, 'message': 'failed to call taobao api'}"
      return;
    query "select * from ecm_store s left join ecm_member_auth a on s.im_ww = a.vendor_user_nick and a.state = 1 where s.im_ww = '#{good.nick}'", (err, stores) ->
      if err or not stores[0]?
        response res, jsonp_callback, "{'error': true, 'message': 'cannot find store which url is #{goodHttp}'}"
      else
        store = stores[0]
        storeId = store['store_id']
        storeName = store['store_name']
        goodHttp = "http://item.taobao.com/item.htm?id=#{goodsId}"
        items = [
          goodsName: good.title
          defaultImage: good.pic_url
          price: parsePrice good.price, store['see_price'], good.title
          taobaoPrice: parsePrice good.price
          goodHttp: goodHttp
        ]
        db.saveItems storeId, storeName, items, goodHttp, '所有宝贝', 1, ->
          crawlItemsInStore storeId, store['access_token'], ->
            response res, jsonp_callback, "{'status': 'ok'}"

handleUpdateItem = (req, res, goodsId, jsonp_callback) ->
  db.query "select * from ecm_goods g left join ecm_store s on g.store_id = s.store_id left join ecm_member_auth a on s.im_ww = a.vendor_user_nick and a.state = 1 where g.goods_id = #{goodsId}", (err, goods) ->
    good = goods[0]
    crawlItemViaApi good, good['access_token'], () ->
      log "#{good['goods_id']}:#{good['goods_name']} updated manually"
      response res, jsonp_callback, "{'status': 'ok'}"

handleDeleteItem = (req, res, numIid, jsonp_callback) ->
  likeGoodHttp = "http://item.taobao.com/item.htm?id=#{numIid}%"
  db.query "call delete_good('#{likeGoodHttp}')", (err, result) ->
    if err
      response res, jsonp_callback, "{'error': true, 'message': 'handle delete item failed'}"
    else
      response res, jsonp_callback, "{'status': 'ok'}"

handleChangeItem  = (req, res, numIid, jsonp_callback) ->
  likeGoodHttp = "http://item.taobao.com/item.htm?id=#{numIid}%"
  query "select * from ecm_goods g left join ecm_store s on g.store_id = s.store_id left join ecm_member_auth a on s.im_ww = a.vendor_user_nick and a.state = 1 where g.good_http like '#{likeGoodHttp}'"
    .then (result) ->
      if result?[0]?
        good = result[0]
        goodsId = good['goods_id']
        accessToken = good['access_token']
        crawlItemViaApi good, accessToken, () ->
          log "#{good['goods_id']}:#{good['goods_name']} updated manually"
          response res, jsonp_callback, "{'status': 'ok'}"
      else
        throw new Error('good not found')
    .then undefined, (reason) ->
      response res, jsonp_callback, "{'error': true, 'message': 'handle change item failed: #{reason}'}"

syncStore = (req, res, storeId, jsonp_callback) ->
  query "select * from ecm_store s inner join ecm_member_auth a on s.im_ww = a.vendor_user_nick and s.store_id = #{storeId} and s.state = 1 and a.state = 1"
    .then (stores) ->
      if stores.length > 0
        store = stores[0]
      else
        throw new Error('cannot find any auto synced stores')
      getTaobaoItemsOnsaleBatch 'title,pic_url,price,num_iid,modified', '1', store['access_token'], [], (err, itemsOnsale) ->
        if itemsOnsale and itemsOnsale[0]?.title?
          sql = ''
          items = []
          numIids = ''
          for item in itemsOnsale
            items.push {
              goodsName: item.title
              defaultImage: item.pic_url
              price: parsePrice item.price, store['see_price'], item.title
              taobaoPrice: parsePrice item.price
              goodHttp: "http://item.taobao.com/item.htm?id=#{item.num_iid}"
            }
            numIids += "#{item.num_iid},"
          numIids = numIids.substr 0, numIids.length - 1
          existedGoods store['store_id'], (goodHttps) ->
            log "store #{store['store_id']} exists goods length: #{goodHttps.length}"
            log "store #{store['store_id']} taobao goods length: #{numIids.split(',').length}"
            log "store #{store['store_id']} after filtered length: #{numIids.split(',').length}"
            getTaobaoItemsSellerListBatch numIids, 'num_iid,created,sku,props_name,property_alias,title,cid,seller_cids,desc', store['access_token'], [], (err, itemsInBatch) ->
              if err
                log "store #{store['store_id']} #{err}"
                response res, jsonp_callback, "{'error': true, 'message': 'sync failed: #{err}'}"
              sql += "update ecm_goods set description = '#{removeSingleQuotes(oneItem.desc)}', add_time = #{phpjs.strtotime(oneItem.created)}, last_update = #{db.getDateTime()} where store_id = #{store['store_id']} and good_http = 'http://item.taobao.com/item.htm?id=#{oneItem.num_iid}';" for oneItem in itemsInBatch
              for oneItem in itemsInBatch
                if oneItem.seller_cids
                  cids = oneItem.seller_cids.split ','
                  for cid in cids
                    if cid and ~goodHttps.indexOf("http://item.taobao.com/item.htm?id=#{oneItem.num_iid}")
                      sql += "replace into ecm_category_goods(cate_id, goods_id) values (#{cid}, (select goods_id from ecm_goods where good_http='http://item.taobao.com/item.htm?id=#{oneItem.num_iid}' limit 1));"
                skus = parseSkus oneItem.skus, oneItem.propertyAlias, store['see_price'], oneItem.title
                for sku in skus
                  specVid1 = sku[0]?.vid || 0
                  specVid2 = sku[1]?.vid || 0
                  quantity = sku[0]?.quantity || 1000
                  price = sku[0]?.price || parsePrice(oneItem.price, store['see_price'], oneItem.title)
                  taobaoPrice = sku[0]?.taobaoPrice || parsePrice(oneItem.price)
                  sql += "update ecm_goods_spec set stock = #{quantity}, price = #{price}, taobao_price = #{taobaoPrice} where goods_id = (select goods_id from ecm_goods where store_id = #{store['store_id']} and good_http = 'http://item.taobao.com/item.htm?id=#{oneItem.num_iid}') and spec_vid_1 = '#{specVid1}' and spec_vid_2 = '#{specVid2}';"
              db.saveItems store['store_id'], store['store_name'], items, '', '所有宝贝', 1, ->
                db.query sql, (err, result) ->
                  if err then error err
                  crawlItemsInStore store['store_id'], store['access_token'], ->
                    log "store #{store['store_id']} updated #{items.length} items"
                    db.deleteDelistItems store['store_id'], items.length, ->
                      response res, jsonp_callback, "{'status': 'ok'}"
        else
          error "store #{store['store_id']} error: #{err}"
          response res, jsonp_callback, "{'error': true, 'message': 'sync failed: #{err}'}"
    .catch (reason) ->
      error reason
      response res, jsonp_callback, "{'error': true, 'message': 'sync failed: #{reason}'}"

existedGoods = (storeId, callback) ->
  sql = "select g.good_http from ecm_goods g where g.store_id = #{storeId} and exists (select 1 from ecm_goods_spec s where s.goods_id = g.goods_id)"
  db.query sql, (err, res) ->
    if err then throw err
    goodHttps = []
    if res
      goodHttps.push g.good_http for g in res
    callback goodHttps

matchUrlPattern = (urlParts, pattern) ->
  match = true;
  patternParts = pattern.split '/'
  for p, i in patternParts
    if (p.indexOf('{') isnt 0) and (urlParts[i] isnt p)
      match = false
  match

server = http.createServer((req, res) ->
  urlObj = parse req.url, true
  urlParts = urlObj.pathname.split '/'
  if matchUrlPattern urlParts, '/store/{storeId}'
    storeId = urlParts[2]
    handleStore req, res, storeId, urlObj.query.jsonp_callback
  else if matchUrlPattern urlParts, '/item'
    submitNewItem req, res, urlObj.query.itemUri, urlObj.query.jsonp_callback
  else if matchUrlPattern urlParts, '/update'
    handleUpdateItem req, res, urlObj.query.goodsId, urlObj.query.jsonp_callback
  else if matchUrlPattern urlParts, '/delete'
    handleDeleteItem req, res, urlObj.query.numIid, null
  else if matchUrlPattern urlParts, '/add'
    handleNewItem req, res, urlObj.query.numIid, urlObj.query.nick, urlObj.query.title, urlObj.query.price, null
  else if matchUrlPattern urlParts, '/change'
    handleChangeItem req, res, urlObj.query.numIid, null
  else if matchUrlPattern urlParts, '/stores/{storeId}?sync'
    storeId = urlParts[2]
    syncStore req, res, storeId, urlObj.query.jsonp_callback
)
server.on 'clientError', (err, socket) ->
  error "Bad request: #{err}"
server.listen port

log "server is listening: #{port}"

if process.env.NODE_ENV is 'test'
  exports.matchUrlPattern = matchUrlPattern

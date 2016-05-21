Q = require 'q'
phpjs = require 'phpjs'
{log} = require 'util'
{getTaobaoItemsOnsale, getTaobaoItemsSellerListBatch} = require '../src/taobao_api'
{setDatabase, crawlItemsInStore, parsePrice, parseSkus} = require '../src/taobao_crawler'
database = require '../src/database'
config = require '../src/config'
args = process.argv.slice 2

db = new database(config.database[args[0]])
query = Q.nbind db.query, db

setDatabase db
storesNeedUpdate = []

update = () ->
  if storesNeedUpdate.length > 0
    store = storesNeedUpdate.shift()
    getTaobaoItemsOnsale 'title,pic_url,price,num_iid,modified', store['access_token'], (err, itemsOnsale) ->
      if itemsOnsale and itemsOnsale[0]?.title?
        sql = ''
        items = []
        numIids = ''
        for item in itemsOnsale
          items.push {
            goodsName: item.title
            defaultImage: item.pic_url
            price: parsePrice item.price, store['see_price'], item.title
            goodHttp: "http://item.taobao.com/item.htm?id=#{item.num_iid}"
          }
          numIids += "#{item.num_iid},"
        numIids = numIids.substr 0, numIids.length - 1
        existedGoods store['store_id'], (goodHttps) ->
          log "store #{store['store_id']} exists goods length: #{goodHttps.length}"
          log "store #{store['store_id']} taobao goods length: #{numIids.split(',').length}"
          numIids = filterItems numIids, goodHttps
          log "store #{store['store_id']} after filtered length: #{numIids.split(',').length}"
          getTaobaoItemsSellerListBatch numIids, 'num_iid,created,sku,props_name,property_alias,title', store['access_token'], [], (err, itemsInBatch) ->
            sql += "update ecm_goods set add_time = #{phpjs.strtotime(oneItem.created)} where store_id = #{store['store_id']} and good_http = 'http://item.taobao.com/item.htm?id=#{oneItem.num_iid}';" for oneItem in itemsInBatch
            for oneItem in itemsInBatch
              skus = parseSkus oneItem.skus, oneItem.propertyAlias, store['see_price'], oneItem.title
              for sku in skus
                specVid1 = sku[0]?.vid || 0
                specVid2 = sku[1]?.vid || 0
                quantity = sku[0]?.quantity || 1000
                sql += "update ecm_goods_spec set stock = #{quantity} where goods_id = (select goods_id from ecm_goods where store_id = #{store['store_id']} and good_http = 'http://item.taobao.com/item.htm?id=#{oneItem.num_iid}') and spec_vid_1 = '#{specVid1}' and spec_vid_2 = '#{specVid2}';"
            db.saveItems store['store_id'], store['store_name'], items, '', '所有宝贝', 1, ->
              db.query sql, ->
                crawlItemsInStore store['store_id'], store['access_token'], ->
                  log "store #{store['store_id']} updated #{items.length} items"
                  update()
      else
        console.error "store #{store['store_id']} error: #{err}"
        update()

existedGoods = (storeId, callback) ->
  sql = "select g.good_http from ecm_goods g where g.store_id = #{storeId} and exists (select 1 from ecm_goods_spec s where s.goods_id = g.goods_id)"
  db.query sql, (err, res) ->
    if err then throw err
    goodHttps = []
    if res
      goodHttps.push g.good_http for g in res
    callback goodHttps

filterItems = (numIids, existedGoods) ->
  notExistedNumIids = []
  for numIid in numIids.split ','
    goodHttp = "http://item.taobao.com/item.htm?id=#{numIid}"
    if not ~existedGoods.indexOf(goodHttp)
      notExistedNumIids.push numIid
  notExistedNumIids.join ','

query 'select * from ecm_store s inner join ecm_member_auth a on s.im_ww = a.vendor_user_nick and s.store_id > 0 and s.state = 1 order by s.store_id'
  .then (stores) ->
    storesNeedUpdate = stores
    log "There are total #{stores.length} stores need to be updated."
    update()
  .catch (reason) ->
    console.error reason

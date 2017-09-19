Q = require 'q'
phpjs = require 'phpjs'
{log} = require '../src/util'
{getTaobaoItemsOnsaleBatch, getTaobaoItemsSellerListBatch} = require '../src/taobao_api'
{setDatabase, crawlItemsInStore, parsePrice, parseSkus, removeSingleQuotes} = require '../src/taobao_crawler'
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
        existedGoods store['store_id'], (goodHttps, goodIds) ->
          log "store #{store['store_id']} exists goods length: #{goodHttps.length}"
          log "store #{store['store_id']} taobao goods length: #{numIids.split(',').length}"
          # numIids = filterItems numIids, goodHttps
          log "store #{store['store_id']} after filtered length: #{numIids.split(',').length}"
          getTaobaoItemsSellerListBatch numIids, 'num_iid,created,sku,props_name,property_alias,title,cid,seller_cids,desc,item_img.url', store['access_token'], [], (err, itemsInBatch) ->
            if err
              log "store #{store['store_id']} #{err}"
              return update()
            sql += "update ecm_goods set description = '#{removeSingleQuotes(oneItem.desc)}', add_time = #{phpjs.strtotime(oneItem.created)}, last_update = #{db.getDateTime()} where store_id = #{store['store_id']} and good_http = 'http://item.taobao.com/item.htm?id=#{oneItem.num_iid}';" for oneItem in itemsInBatch
            for oneItem in itemsInBatch
              if oneItem.item_imgs?.item_img? and ~goodHttps.indexOf("http://item.taobao.com/item.htm?id=#{oneItem.num_iid}")
                db.updateItemImgs goodIds[goodHttps.indexOf("http://item.taobao.com/item.htm?id=#{oneItem.num_iid}")], oneItem.item_imgs.item_img, ->
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
              db.query sql, (err, res) ->
                if err then console.error err
                crawlItemsInStore store['store_id'], store['access_token'], ->
                  log "store #{store['store_id']} updated #{items.length} items"
                  db.deleteDelistItems store['store_id'], items.length, ->
                    update()
      else
        console.error "store #{store['store_id']} error: #{err}"
        update()

existedGoods = (storeId, callback) ->
  sql = "select g.goods_id, g.good_http from ecm_goods g where g.store_id = #{storeId} and exists (select 1 from ecm_goods_spec s where s.goods_id = g.goods_id)"
  db.query sql, (err, res) ->
    if err then throw err
    goodHttps = []
    goodIds = []
    if res
      for g in res
        goodHttps.push g.good_http
        goodIds.push g.goods_id
    callback goodHttps, goodIds

filterItems = (numIids, existedGoods) ->
  notExistedNumIids = []
  for numIid in numIids.split ','
    goodHttp = "http://item.taobao.com/item.htm?id=#{numIid}"
    if not ~existedGoods.indexOf(goodHttp)
      notExistedNumIids.push numIid
  notExistedNumIids.join ','

if args.length > 2
  start = args[1]
  end = args[2]

query "select * from ecm_store s inner join ecm_member_auth a on s.im_ww = a.vendor_user_nick and s.store_id > #{if start? then start else '0'} and s.store_id < #{if end? then end else '9999999'} and s.state = 1 and a.state = 1 order by s.store_id DESC"
  .then (stores) ->
    storesNeedUpdate = stores
    log "There are total #{stores.length} stores need to be updated."
    update()
  .catch (reason) ->
    console.error reason

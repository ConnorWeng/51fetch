Q = require 'q'
{getTaobaoItemsOnsale} = require '../src/taobao_api'
{setDatabase, crawlItemsInStore} = require '../src/taobao_crawler'
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
    getTaobaoItemsOnsale 'title,pic_url,price,num_iid', store['access_token'], (err, itemsOnsale) ->
      if itemsOnsale and itemsOnsale[0]?.title?
        items = []
        items.push {
          goodsName: item.title
          defaultImage: item.pic_url
          price: item.price
          goodHttp: "http://item.taobao.com/item.htm?id=#{item.num_iid}"
        } for item in itemsOnsale
        db.saveItems store['store_id'], store['store_name'], items, '', '所有宝贝', 1, ->
          crawlItemsInStore store['store_id'], store['access_token'], ->
            console.log "store #{store['store_id']} updated #{items.length} items"
            update()
      else
        console.error "store #{store['store_id']} error: #{err}"
        update()

query 'select * from ecm_store s inner join ecm_member_auth a on s.im_ww = a.vendor_user_nick'
  .then (stores) ->
    storesNeedUpdate = stores
    console.log "There are total #{stores.length} stores need to be updated."
    update()
  .catch (reason) ->
    console.error reason

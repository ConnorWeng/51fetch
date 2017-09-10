Q = require 'q'
{log, error, inspect, debug, trace, removeNumbersAndSymbols} = require './util'
database = require './database'

db = new database()
query = Q.nbind db.query, db

query "select store_id, store_name from ecm_store where state = 1 and see_price = '减半'"
  .then (stores) ->
    fixStore stores, 0
  .catch (err) ->
    error err

fixStore = (stores, index) ->
  storeId = stores[index].store_id
  storeName = stores[index].store_name
  query "select price, taobao_price from ecm_goods where store_id = #{storeId}"
    .then (goods) ->
      for good in goods
        if parseFloat(good['taobao_price']) / parseFloat(good['price']) isnt 2 and parseFloat(good['price']) > 0 and parseFloat(good['taobao_price']) > 0
          delta = parseFloat(good['taobao_price']) - parseFloat(good['price'])
          if delta > 0
            log "store #{storeId} #{storeName} wrong, taobao: #{good['taobao_price']}, price: #{good['price']}, should be 减#{delta}"
            log "update ecm_store set see_price = '减#{delta}' where store_id = #{storeId};"
            log "update ecm_store_vvic set see_price = '减#{delta}' where ecm_store_id = #{storeId};"
            break
      if index + 1 < stores.length
        fixStore stores, index + 1
    .catch (err) ->
      throw err

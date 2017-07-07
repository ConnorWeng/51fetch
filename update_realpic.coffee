Q = require 'q'
{log, error} = require './src/util'
{getItemCats} = require './src/taobao_api'
{crawlTaobaoItem, isRealPic, getNumIidFromUri} = require './src/taobao_crawler'
database = require './src/database'
config = require './src/config'
args = process.argv.slice 2

db = new database(config.database[args[0]])
addTime = args[1]

fetchTaobaoItem = Q.nfbind crawlTaobaoItem
query = Q.nbind db.query, db

goods = []

query "select goods_id, add_time, realpic, good_http from ecm_goods where add_time > #{addTime} and realpic is null"
  .then (res) ->
    goods = res
    log "there are #{goods.length} goods need update"
    updateRealPic()
  , (err) ->
    error err

updateRealPic = ->
  if goods.length > 0
    good = goods.shift()
    fetchTaobaoItem getNumIidFromUri(good.good_http)
      .then (item) ->
        realpic = isRealPic item.title, item.props_name
        if realpic is 1
          query "update ecm_goods set realpic = 1 where goods_id = #{good.goods_id}"
            .then (res) ->
              log "id:#{good.goods_id}'s realpic is updated to 1"
              updateRealPic()
        else
          query "update ecm_goods set realpic = 0 where goods_id = #{good.goods_id}"
            .then (res) ->
              log "id:#{good.goods_id}'s realpic is updated to 0"
              updateRealPic()
      .then undefined, (err) ->
        error err
        updateRealPic()
  else
    log 'complete.'

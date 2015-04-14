{log, error} = require 'util'
{setDatabase, crawlItemViaApi} = require './src/taobao_crawler'
database = require './src/database'
config = require './src/config'
args = process.argv.slice 2

db = new database(config.database[args[0]])
setDatabase db

unfetchedGoods = []

crawl = ->
  if unfetchedGoods.length > 0
    good = unfetchedGoods.shift()
    crawlItemViaApi good, ->
      log "#{good.goods_id}: #{good.goods_name} updated"
      crawl()
  else
    log 'complete'
    db.end()

db.getUnfetchedGoods (err, result) ->
  if err then throw err
  unfetchedGoods = result
  crawl()

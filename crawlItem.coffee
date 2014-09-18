{crawlItem} = require './src/taobao_crawler'
database = require './src/database'

unfetchedGoods = []
db = new database

crawl = ->
  if unfetchedGoods.length > 0
    good = unfetchedGoods.shift()
    crawlItem good.good_http, crawl
  else
    console.log 'complete'
    db.end()

db.getUnfetchedGoods (err, result) ->
  if err then throw err
  unfetchedGoods = result
  crawl()

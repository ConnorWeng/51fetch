{setDatabase, crawlItemViaApi} = require './src/taobao_crawler'
database = require './src/database'

unfetchedGoods = []
db = new database
  host: 'rdsqr7ne2m2ifjm.mysql.rds.aliyuncs.com'
  user: 'wangpi51'
  password: '51374b78b104'
  database: 'ecmall51'
  port: 3306
setDatabase db

crawl = ->
  if unfetchedGoods.length > 0
    good = unfetchedGoods.shift()
    crawlItemViaApi good.good_http, ->
      console.log "#{good.goods_id}: #{good.goods_name} updated"
      crawl()
  else
    console.log 'complete'
    db.end()

db.getUnfetchedGoods (err, result) ->
  if err then throw err
  unfetchedGoods = result
  crawl()

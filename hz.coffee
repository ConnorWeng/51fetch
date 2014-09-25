taobao_crawler = require('./src/taobao_crawler')
database = require('./src/database')
stores = []

db = new database
  host: 'rdsqr7ne2m2ifjm.mysql.rds.aliyuncs.com'
  user: 'wangpi51'
  password: '51374b78b104'
  database: 'wangpi51_hz'
  port: 3306

taobao_crawler.setDatabase db

crawl = ->
  if stores.length > 0
    store = stores.shift()
    taobao_crawler.crawlStore store, crawl
  else
    console.log('completed.')

taobao_crawler.getAllStores 'state = 1 order by store_id', (err, unfetchedStores) ->
  if err
    throw err
  stores = unfetchedStores
  crawl()

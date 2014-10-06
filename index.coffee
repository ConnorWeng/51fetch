{getAllStores, crawlStore, setDatabase} = require './src/taobao_crawler'
database = require './src/database'
config = require './src/config'
args = process.argv.slice 2

db = new database(config.database[args[0]])
setDatabase db

stores = []

crawl = ->
  if stores.length > 0
    store = stores.shift()
    crawlStore store, crawl
  else
    console.log 'completed.'

condition = if args[1] then args[1] else ''

getAllStores "#{condition} state = 1 order by store_id", (err, unfetchedStores) ->
  if err then throw err
  stores = unfetchedStores
  crawl()

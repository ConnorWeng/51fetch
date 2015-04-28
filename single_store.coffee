{crawlStore, getAllStores, setDatabase} = require './src/taobao_crawler'
config = require './src/config'
database = require './src/database'
stores = []
args = process.argv.slice 2

db = new database(config.database[args[0]]);
setDatabase db

crawl = ->
  if stores.length > 0
    store = stores.shift()
    crawlStore store, true, crawl
  else
    console.log 'completed.'

getAllStores 'store_id = ' + args[1] + ' and state = 1 order by store_id DESC', (err, unfetchedStores) ->
  if err then throw err
  console.log 'store_length:' + unfetchedStores.length
  stores = unfetchedStores
  crawl()

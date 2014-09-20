{crawlStore, getAllStores} = require './src/taobao_crawler'
stores = []
args = process.argv.slice 2

crawl = ->
  if stores.length > 0
    store = stores.shift()
    crawlStore store, crawl
  else
    console.log 'completed.'

getAllStores 'store_id = ' + args[0] + ' and state = 1 order by store_id DESC', (err, unfetchedStores) ->
  if err then throw err
  console.log 'store_length:' + unfetchedStores.length
  stores = unfetchedStores
  crawl()

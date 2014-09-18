{getAllStores, crawlStore} = require './src/taobao_crawler'

stores = []

crawl = ->
  if stores.length > 0
    store = stores.shift()
    crawlStore store, crawl
  else
    console.log 'completed.'

getAllStores '1 order by store_id limit 1', (err, unfetchedStores) ->
  if err then throw err
  stores = unfetchedStores
  crawl()

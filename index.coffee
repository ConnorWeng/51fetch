{getAllStores, crawlStore, setDatabase, getDatabase} = require './src/taobao_crawler'
database = require './src/database'
config = require './src/config'
args = process.argv.slice 2

process.on 'exit', (code) ->
  console.log [
    "updateStoreCateContentCounter: #{db.updateStoreCateContentCounter}"
    "updateImWwCounter: #{db.updateImWwCounter}"
    "clearCidsCounter: #{db.clearCidsCounter}"
    "deleteDelistItemsCounter: #{db.deleteDelistItemsCounter}"
    "saveItemsCounter: #{db.saveItemsCounter}"
  ].join ' | '
  console.log "about to exit with code: #{code}"

process.on 'uncaughtException', (err) ->
  console.log 'caught exception:' + err

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
  console.log "There are total #{stores.length} stores need to be fetched."
  crawl()

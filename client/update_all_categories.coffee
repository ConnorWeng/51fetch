{getSellercatsList} = require '../src/taobao_api'
{getAllStores, setDatabase} = require '../src/taobao_crawler'
database = require '../src/database'
config = require '../src/config'
args = process.argv.slice 2

db = new database(config.database[args[0]])
setDatabase db
storesNeedUpdate = []

update = () ->
  if storesNeedUpdate.length > 0
    store = storesNeedUpdate.shift()
    getSellercatsList store['im_ww'], (err, cats) ->
      if cats
        db.updateCategories store['store_id'], cats, (err, result) ->
          if not err
            console.log "#{store['store_id']} updated"
          else
            console.error "#{store['store_id']} error: #{err}"
          update()
      else
        console.error "#{store['store_id']} error: #{err}"
        update()
  else
    console.log 'completed.'

getAllStores '1 order by store_id', (err, stores) ->
  if err then throw err
  storesNeedUpdate = stores
  console.log "There are total #{stores.length} stores' categories need to be updated."
  update()

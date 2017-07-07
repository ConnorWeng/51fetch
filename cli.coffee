{log} = require 'util'
{buildOuterIid, crawlAllItemsInStore, crawlItemsInStore, getAllStores, crawlStore, setDatabase, getDatabase} = require './src/taobao_crawler'
database = require './src/database'
config = require './src/config'
{getIPProxy} = require './src/crawler'
args = process.argv.slice 2

process.on 'exit', (code) ->
  log "about to exit with code: #{code}"

process.on 'uncaughtException', (err) ->
  log 'caught exception:' + err

crawlAll = false
crawlItemsOnly = false
dbName = args[args.length-2]
storeId = args[args.length-1]

for arg in args
  if arg is '-a' then crawlAll = true
  if arg is '-i' then crawlItemsOnly = true

db = new database(config.database[dbName])
setDatabase db

crawlItems = if crawlAll then crawlAllItemsInStore else crawlItemsInStore

crawl = (store) ->
  log "#{store['store_name']} need to be fetched."
  crawlStore store, false, ->
    log "id:#{store['store_id']} #{store['store_name']} access_token: #{store['access_token']}"
    crawlItems store['store_id'], store['access_token'], ->
      log "all goods fetched, start to build outer iid"
      buildOuterIid store['store_id'], ->
        process.exit 0

crawlGoods = (store) ->
  log "goods in #{store['store_name']} need to be fetched."
  crawlItems store['store_id'], store['access_token'], ->
    log "all goods fetched, start to build outer iid"
    buildOuterIid store['store_id'], ->
      process.exit 0

db.query "select * from ecm_store s left join ecm_member_auth a on s.im_ww = a.vendor_user_nick and a.state = 1 where s.state = 1 and s.store_id = #{storeId}", (err, stores) ->
  if err then throw err
  getIPProxy()
  setTimeout ->
    if crawlItemsOnly
      crawlGoods stores[0]
    else
      crawl stores[0]
  , 5000                        # 延迟5秒开始爬取，确保首次获取ip代理操作已经完成

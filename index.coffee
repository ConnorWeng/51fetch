{Pool} = require 'generic-pool'
{buildOuterIid, crawlItemsInStore, getAllStores, crawlStore, setDatabase, getDatabase} = require './src/taobao_crawler'
database = require './src/database'
config = require './src/config'
{getIPProxy} = require './src/crawler'
args = process.argv.slice 2
ip = args[1]

process.on 'exit', (code) ->
  db.query "update ecm_crawl_config set exit_code = #{code} where ip = '#{ip}'", ->
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

fullCrawl = if args.length >= 3 and args[2] is 'fullCrawl' then true else false
needCrawlItemsViaApi = if args.length is 4 and args[3] is 'api' then true else false

pool = Pool
  name: 'taobao store crawler',
  max: 10
  create: (callback) -> callback(1)
  destroy: (client) ->

stores = []

crawl = (store) ->
  pool.acquire (err, poolRef) ->
    if (err)
      console.error "pool acquire error: #{err}"
      pool.release poolRef
      log 'exiting with code: 95'
      process.exit 95

    crawlStore store, fullCrawl, ->
      db.query "update ecm_crawl_config set now_id = #{store['store_id']}, last_update = '#{new Date()}' where ip = '#{ip}'", ->
        if needCrawlItemsViaApi
          console.log "id:#{store['store_id']} #{store['store_name']} access_token: #{store['access_token']}"
          crawlItemsInStore store['store_id'], store['access_token'], ->
            buildOuterIid store['store_id'], ->
              pool.release poolRef
        else
          db.query "update ecm_crawl_config set last_update = '#{new Date()}'", ->
            pool.release poolRef

db.query "select * from ecm_store s left join ecm_member_auth a on s.im_ww = a.vendor_user_nick and a.state = 1 where s.state = 1 and s.store_id > (select now_id from ecm_crawl_config where ip = '#{ip}') and s.store_id <= (select end_id from ecm_crawl_config where ip = '#{ip}') order by s.store_id", (err, unfetchedStores) ->
  if err then throw err
  stores = unfetchedStores
  getIPProxy()
  setTimeout ->
    console.log "There are total #{stores.length} stores need to be fetched."
    crawl store for store in stores
  , 5000                        # 延迟5秒开始爬取，确保首次获取ip代理操作已经完成

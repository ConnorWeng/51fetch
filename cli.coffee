{buildOuterIid, crawlItemsInStore, getAllStores, crawlStore, setDatabase, getDatabase} = require './src/taobao_crawler'
database = require './src/database'
config = require './src/config'
{getIPProxy} = require './src/crawler'
args = process.argv.slice 2

process.on 'uncaughtException', (err) ->
  console.log 'caught exception:' + err

db = new database(config.database[args[0]])
setDatabase db

crawl = (store) ->
  crawlStore store, false, ->
    console.log "id:#{store['store_id']} #{store['store_name']} access_token: #{store['access_token']}"
    crawlItemsInStore store['store_id'], store['access_token'], ->
      buildOuterIid store['store_id'], ->
        process.exit 0

db.query "select * from ecm_store s left join ecm_member_auth a on s.im_ww = a.vendor_user_nick and a.state = 1 where s.state = 1 and s.store_id = #{args[1]}", (err, stores) ->
  if err then throw err
  getIPProxy()
  setTimeout ->
    console.log "#{stores[0]['store_name']} need to be fetched."
    crawl stores[0]
  , 5000                        # 延迟5秒开始爬取，确保首次获取ip代理操作已经完成

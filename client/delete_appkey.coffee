Q = require 'q'
{log} = require 'util'
{fetch} = require '../src/crawler'
database = require '../src/database'
config = require '../src/config'
args = process.argv.slice 2

db = new database(config.database[args[0]])

query = Q.nbind db.query, db

unhandledAppkeys = []

query 'select appkey from ecm_taoapi_self'
  .then (rows) ->
    unhandledAppkeys = rows
    handle()

handle = () ->
  if unhandledAppkeys.length > 0
    appkey = unhandledAppkeys.shift()['appkey']
    log appkey
    fetch "https://oauth.taobao.com/authorize?response_type=code&client_id=#{appkey}&redirect_uri=http://yjsc.51zwd.com%2Ftaobao-upload-multi-store%2Findex.php%3Fg%3DTaobao%26m%3DIndex%26a%3DtestAuthBack&state=&view=web"
      .then (result) ->
        if ~result.indexOf "Can not find the client_id:#{appkey}"
          log "#{appkey} is expired"
          query "update ecm_taoapi_self set overflow = 47 where appkey = #{appkey}"
      .then () ->
        handle()
  else
    process.exit 0

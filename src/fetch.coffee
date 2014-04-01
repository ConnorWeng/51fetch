taobao = require './taobao_fetch.js'
db = require './database.js'

databaseConfig =
  host: 'localhost'
  user: 'root'
  password: '57826502'
  database: 'test2'
  port: 3306

exports.allStores = () ->
  db(databaseConfig).getStores 'true limit 2', (err, stores) ->
    console.log "the amount of all stores are #{stores.length}"
    fetchStore store for store in stores

fetchStore = (store) ->
  fetchUrl store['shop_http']

fetchUrl = (url) ->
  taobao.requestHtmlContent url, (err, content) ->
    if not err
      taobao.extractItemsFromContent content, (err, items) ->
        if not err then db(databaseConfig).saveItems(items)
      taobao.nextPage content, (err, url) ->
        if not err and url isnt null then fetchUrl url

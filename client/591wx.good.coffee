{log, error} = require 'util'
{crawl} = require '../src/crawler'
database = require '../src/database'
config = require '../src/config'

db = new database(config.database['nt'])

stores = []

db.runSql "select * from ecm_store where shop_http != ''", (err, res) ->
  if err
    error err
  else
    stores = res
    crawlStore()

crawlStore = ->
  if stores.length > 0
    store = stores.shift()
    crawlFirstPageOfStore store, crawlStore
  else
    log 'complete.'

crawlFirstPageOfStore = (store, callback) ->
  crawl store.shop_http,
    items_sql: ($) ->
      sql = ''
      $('.box_goods').each ->
        $goods = $ @
        goodsName = $goods.find('p:eq(1) a').text().trim()
        defaultImage = 'http://www.591wx.com' + $goods.find('.box_img img').attr('src').trim()
        goodHttp = $goods.find('p:eq(1) a').attr('href').trim()
        sql += "insert into ecm_goods(store_id, goods_name, default_image, good_http) values (#{store.store_id}, '#{goodsName}', '#{defaultImage}', '#{goodHttp}');"
      sql
    , (err, res) ->
      if err
        error err
      else
        db.runSql res['items_sql'], (err, res) ->
          console.log res
          crawlStore()

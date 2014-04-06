http = require 'http'
jsdom = require 'jsdom'
iconv = require 'iconv-lite'
db = require './database.js'

class taobao_fetch
  constructor: () ->
    @db = new db()

  fetchStore: (store) ->
    shopUrl = store['shop_http'] + "/search.htm?search=y&orderType=newOn_desc"
    console.log "id:#{store['store_id']} #{store['store_name']}: #{shopUrl}"
    @fetchUrl shopUrl, store['store_id'], store['store_name']

  fetchUrl: (url, storeId, storeName) ->
    @requestHtmlContent url, (err, content) =>
      if not err
        @extractItemsFromContent content, (err, items) =>
          if not err then @db.saveItems(storeId, storeName, items)
        @nextPage content, (err, url) =>
          if not err and url isnt null then @fetchUrl url, storeId, storeName

  fetchAllStores: () ->
    @db.getStores '1 order by store_id', (err, stores) =>
      console.log "the amount of all stores are #{stores.length}"
      @fetchStore store for store in stores

  requestHtmlContent: (url, callback) ->
    result = ''
    http.get url, (res) ->
      res.on 'data', (chunk) ->
        result += iconv.decode chunk, 'GBK'
      res.on 'end', () ->
        callback null, result

  extractItemsFromContent: (content, callback) ->
    jsdom.env content, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) ->
      $ = window.$
      items = []
      $('dl.item').each () ->
        $item = $(this)
        items.push
          goodsName: $item.find('a.item-name').text()
          defaultImage: $item.find('img').attr('data-ks-lazyload')
          price: $item.find('.c-price').text().trim()
          goodHttp: $item.find('a.item-name').attr('href')
      callback err, items

  nextPage: (content, callback) ->
    jsdom.env content, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) ->
      $ = window.$
      $nextLink = $('a.J_SearchAsync.next')
      if $nextLink.length > 0
        callback null, $nextLink.attr('href')
      else
        callback null, null

module.exports = taobao_fetch

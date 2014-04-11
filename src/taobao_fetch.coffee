http = require 'http'
jsdom = require 'jsdom'
iconv = require 'iconv-lite'
db = require './database.js'
Pool = require('generic-pool').Pool

class taobao_fetch
  constructor: () ->
    @db = new db()
    @stores = []
    @pool = Pool
      name: 'fetch'
      max: 5
      create: (callback) =>
        if @stores.length > 0
          store = @stores.shift()
          store.fetchedCategoriesCount = 0
          callback null, store
        else
          @pool.drain () =>
            @pool.destroyAllNow()
      destroy: (client) ->

  fetchStore: () ->
    @pool.acquire (err, store) =>
      shopUrl = store['shop_http'] + "/search.htm?search=y&orderType=newOn_desc"
      console.log "id:#{store['store_id']} #{store['store_name']}: #{shopUrl}"
      @fetchCategoriesUrl shopUrl, (err, urls) =>
        if not err and urls isnt null
          @fetchUrl url, store, urls.length for url in urls
        else
          console.error "error in fetchCategoriesUrl of url: #{shopUrl}"

  fetchCategoriesUrl: (shopUrl, callback) =>
    @requestHtmlContent shopUrl, (err, content) =>
      if err or typeof content isnt 'string' or content is ''
        return callback new Error('content cannot be handled by jsdom'), null
      jsdom.env content, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) ->
        $ = window.$
        urls = []
        $('a.cat-name').each () ->
          url = $(this).attr('href')
          if urls.indexOf(url) is -1 and url.indexOf('category-') isnt -1 and url.indexOf('#bd') is -1 then urls.push url
        callback null, urls

  fetchUrl: (url, store, categoriesCount) ->
    @requestHtmlContent url, (err, content) =>
      if not err
        @extractItemsFromContent content, (err, items) =>
          if not err and items.length > 0
            @db.saveItems store['store_id'], store['store_name'], items, url
          else
            console.error "error in extractItemsFromContent of #{store['store_id']}"
        @nextPage content, (err, url) =>
          if not err and url isnt null
            @fetchUrl url, store, categoriesCount
          else
            store.fetchedCategoriesCount += 1
            if store.fetchedCategoriesCount is categoriesCount
              @pool.release store

  fetchAllStores: () ->
    @db.getStores 'store_id > 10 order by store_id limit 10', (err, stores) =>
      console.log "the amount of all stores are #{stores.length}"
      @stores = stores
      @fetchStore() for store in stores

  requestHtmlContent: (url, callback) ->
    result = ''
    http.get url, (res) ->
      res.on 'data', (chunk) ->
        result += iconv.decode chunk, 'GBK'
      res.on 'end', () ->
        callback null, result

  extractItemsFromContent: (content, callback) ->
    if typeof content isnt 'string' or content is ''
      return callback new Error('content cannot be handled by jsdom'), null
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
    if typeof content isnt 'string' or content is ''
      return callback new Error('content cannot be handled by jsdom'), null
    jsdom.env content, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) ->
      $ = window.$
      $nextLink = $('a.J_SearchAsync.next')
      if $nextLink.length > 0
        callback null, $nextLink.attr('href')
      else
        callback null, null

module.exports = taobao_fetch

Crawler = require('crawler').Crawler
db = require './database.js'

class taobao_crawler
  constructor: () ->
    @db = new db()
    @crawler = new Crawler
      'forceUTF8': true
      'callback': @crawlerPage
      'onDrain': @destroyDBPool
      'maxConnections': 1

  fetchAllStores: () ->
    @db.getStores '1 order by store_id', (err, stores) =>
      if err
        throw err
      console.log "the amount of all stores are #{stores.length}"
      @stores = stores
      @fetchStore store for store in stores

  fetchStore: (store) ->
    shopUri = @makeUriWithStoreInfo "#{store['shop_http']}/search.htm?search=y&orderType=newOn_desc", store
    @updateStoreCateContent shopUri, store, (err, categoryUris) =>
      if err
        return console.error err
      @crawler.queue categoryUris

  updateStoreCateContent: (shopUri, store, callback) ->
    @crawler.queue [
      'uri': shopUri
      'forceUTF8': true
      'callback': (err, result, $) =>
        if err
          return callback err, null
        catsTreeHtml = @extractCatsTreeHtml $, store
        if catsTreeHtml isnt ''
          @db.updateStoreCateContent store['store_id'], store['store_name'], catsTreeHtml
          uris = []
          $('a.cat-name').each (index, element) =>
            uri = $(element).attr('href')
            if uris.indexOf(uri) is -1 and ~uri.indexOf('category-') and ~uri.indexOf('#bd') then uris.push @makeUriWithStoreInfo uri, store
          callback null, uris
        else
          callback new Error('catsTreeHtml is empty'), null
    ]

  extractCatsTreeHtml: ($, store) ->
    catsTreeHtml = $('ul.cats-tree').parent().html()
    if catsTreeHtml?
      catsTreeHtml = catsTreeHtml.trim().replace(/\"http.+category-(\d+).+\"/g, '"showCat.php?cid=$1&shop_id=' + store['store_id'] + '"').replace(/\r\n/g, '')
    else
      console.error "id:#{store['store_id']} #{store['store_name']}: catsTreeHtml is empty."
      catsTreeHtml = ''

  crawlerPage: (err, result, $) =>
    if err
      return console.error err
    store = @parseStoreFromUri result.uri
    items = @extractItemsFromContent $, store
    @db.saveItems store['store_id'], store['store_name'], items, result.uri
    @queueNextPage $, store

  extractItemsFromContent: ($, store) ->
    items = []
    $('dl.item').each (index, element) =>
      $item = $(element)
      items.push
        goodsName: $item.find('a.item-name').text()
        defaultImage: $item.find('img').attr('data-ks-lazyload')
        price: @parsePrice $item.find('.c-price').text().trim(), store['see_price']
        goodHttp: $item.find('a.item-name').attr('href')
    @filterItems items

  filterItems: (unfilteredItems) ->
    items = item for item in unfilteredItems when not ~item.goodsName.indexOf('邮费') and
      not ~item.goodsName.indexOf('运费') and
      not ~item.goodsName.indexOf('淘宝网 - 淘！我喜欢') and
      not ~item.goodsName.indexOf('订金专拍')

  queueNextPage: ($, store) ->
    $nextLink = $('a.J_SearchAsync.next')
    if $nextLink.length > 0
      @crawler.queue @makeUriWithStoreInfo $nextLink.attr('href'), store

  makeUriWithStoreInfo: (uri, store) ->
    uri + "###{store['store_name']}###{store['store_id']}###{store['see_price']}"

  parseStoreFromUri: (uri) ->
    uriParts = uri.split '##'
    store =
      'store_name': uriParts[1]
      'store_id': uriParts[2]
      'see_price': uriParts[3]

  parsePrice: (price, seePrice) ->
    rawPrice = parseFloat price
    if not seePrice? then return rawPrice.toFixed(2)
    if seePrice.indexOf('减半') isnt -1
      (rawPrice / 2).toFixed(2)
    else if seePrice.indexOf('减') is 0
      (rawPrice - parseFloat(seePrice.substr(1))).toFixed(2)
    else if seePrice is '实价'
      rawPrice.toFixed(2)
    else if seePrice.indexOf('*') is 0
      (rawPrice * parseFloat(seePrice.substr(1))).toFixed(2)
    else
      console.error "不支持该see_price: #{seePrice}"
      rawPrice

  destroyDBPool: () =>
    @db.end()

module.exports = taobao_crawler

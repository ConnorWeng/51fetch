Crawler = require('crawler').Crawler
db = require './database.js'

class taobao_crawler
  constructor: () ->
    @db = new db()
    @crawler = new Crawler
      'forceUTF8': true
      'callback': @crawlerPage
      'onDrain': @destroyDBPool

  fetchAllStores: () ->
    @db.getStores '1 order by store_id', (err, stores) =>
      if err
        throw err
      else
        console.log "the amount of all stores are #{stores.length}"
        @stores = stores
        @fetchStore store for store in stores

  fetchStore: (store) ->
    shopUrl = @makeUriWithStoreInfo "#{store['shop_http']}/search.htm?search=y&orderType=newOn_desc", store
    @crawler.queue shopUrl

  crawlerPage: (err, result, $) ->
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
    uriParts = result.uri.split '##'
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

  destroyDBPool: () ->
    @db.end()

module.exports = taobao_crawler

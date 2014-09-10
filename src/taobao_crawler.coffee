http = require 'http'
async = require 'async'
env = require('jsdom').env
jquery = require('jquery')
crawler = require('crawler').Crawler
database = require('./database')
config = require './config'

c = new crawler
  'forceUTF8': true
  'maxConnections': 1
  'jQuery': false
db = new database()

exports.setDatabase = (newDb) ->
  db = newDb

exports.setCrawler = (newCrawler) ->
  c = newCrawler

exports.getAllStores = (condition, callback) ->
  db.getStores condition, callback

exports.crawlItem = (itemUri, done) ->
  async.waterfall [
    queueItemUri itemUri
    updateItemDetail itemUri
  ], (err, result) ->
    if err then console.error err
    done()

queueItemUri = (itemUri) ->
  (callback) ->
    c.queue [
      'uri': itemUri
      'jQuery': false
      'forceUTF8': true
      'callback': callback
    ]

updateItemDetail = (itemUri) ->
  (result, callback) ->
    body = result.body
    desc = ''
    skus = ''
    async.waterfall [
      fetchDescFrom body
      (result, callback) ->
        desc = result
        callback null
      fetchSkusFrom body
      (result, callback) ->
        skus = result
        callback null
      (callback) ->
        updateItemDetailInDatabase desc, skus, itemUri, callback
    ], (err, result) ->
      if err
        console.error err
      else
        console.log "updated item: #{itemUri}"
      callback null

updateItemDetailInDatabase = (desc, skus, itemUri, callback) ->
  goodsId = ''
  price = ''
  async.waterfall [
    (callback) ->
      db.getGood itemUri, callback
    (good, callback) ->
      goodsId = good.goods_id
      price = good.price
      db.updateGoods desc, itemUri, callback
    (result, callback) ->
      db.updateSpecs skus, goodsId, price, callback
    (result, callback) ->
      if result.length > 0
        db.updateDefaultSpec goodsId, result[0].insertId, callback
      else
        callback new Error('updateSpecs\'s result is empty')
    (result, callback) ->
      http.get "#{config.remote_service_address}&goodid=#{goodsId}", (res) ->
        if res.statusCode is 200 then callback null else callback new Error('remote update default image service error')
  ], (err, result) ->
    if err then console.error err
    callback null

fetchDescFrom = (body) ->
  (callback) ->
    startIndex = body.indexOf 'http://dsc.taobaocdn.com'
    endIndex = body.indexOf '")', startIndex + 1
    length = endIndex - startIndex
    descUri = body.substr startIndex, length
    c.queue [
      'uri': descUri
      'jQuery': false
      'forceUTF8': true
      'callback': (err, result) ->
        if err then callback err
        eval result.body
        callback null, desc
    ]

fetchSkusFrom = (body) ->
  (callback) ->
    sizeProperties = getSkuProperties body, '<ul data-property="尺码" class="J_TSaleProp tb-clearfix">'
    if sizeProperties.length is 0
      sizeProperties = getSkuProperties body, '<ul data-property="尺寸" class="J_TSaleProp tb-clearfix">'
    colorProperties = getSkuProperties body, '<ul data-property="颜色分类" class="J_TSaleProp tb-clearfix tb-img">'
    if colorProperties.length is 0
      colorProperties = getSkuProperties body, '<ul data-property="主要颜色" class="J_TSaleProp tb-clearfix tb-img">'
    skuProperties = []
    for sizeProp in sizeProperties
      for colorProp in colorProperties
        skuProperties.push [colorProp, sizeProp]
    callback null, skuProperties

getSkuProperties = (body, tag) ->
  startIndex = body.indexOf tag
  endIndex = body.indexOf '</ul>', startIndex
  part = body.substring startIndex, endIndex + 5
  pattern = /<span>(.+)<\/span>/ig
  skuProperties = []
  while (matches = pattern.exec part) isnt null
    skuProperties.push matches[1]
  skuProperties

exports.crawlStore = (store, done) ->
  async.waterfall [
    queueStoreUri(store)
    makeJsDom
    updateCateContentAndFetchAllCateUris(store)
    crawlAllPagesOfAllCates
  ], (err, result) ->
    if err then console.error err
    done()

queueStoreUri = (store) ->
  (callback) ->
    c.queue [
      'uri': makeUriWithStoreInfo "#{store['shop_http']}/search.htm?search=y&orderType=newOn_desc", store
      'forceUTF8': true
      'callback': callback
    ]

makeJsDom = (result, callback) ->
  env result.body, callback

updateCateContentAndFetchAllCateUris = (store) ->
  (window, callback) ->
    $ = jquery window
    catsTreeHtml = extractCatsTreeHtml $, store
    if catsTreeHtml isnt ''
      db.updateStoreCateContent store['store_id'], store['store_name'], catsTreeHtml
      uris = []
      $('a.cat-name').each (index, element) ->
        uri = $(element).attr('href')
        if uris.indexOf(uri) is -1 and ~uri.indexOf('category-') and ~uri.indexOf('#bd')
          uris.push makeUriWithStoreInfo(uri, store)
      if uris.length is 0 then uris.push makeUriWithStoreInfo($('a.by-new').attr('href'), store)
      window.close()
      callback null, uris
    else
      window.close()
      callback new Error('NoCategoryContent'), null

crawlAllPagesOfAllCates = (uris, callback) ->
  quitCrawlingPages = ->
    c.options.onDrain = false
    callback null, null
  c.options.onDrain = quitCrawlingPages
  for uri in uris
    store = parseStoreFromUri uri
    c.queue [
      'uri': makeUriWithStoreInfo uri, store
      'forceUTF8': true
      'callback': saveItemsFromPageAndQueueNext
    ]

saveItemsFromPageAndQueueNext = (err, result, callback) ->
  env result.body, (errors, window) ->
    $ = jquery window
    store = parseStoreFromUri result.uri
    items = extractItemsFromContent $, store
    db.saveItems store['store_id'], store['store_name'], items, result.uri
    nextUri = nextPageUri $
    window.close()
    if nextUri?
      c.queue [
        'uri': makeUriWithStoreInfo nextUri, store
        'forceUTF8': true
        'callback': saveItemsFromPageAndQueueNext
      ]
    callback?()

nextPageUri = ($) ->
  $('div.pagination a.next').attr('href')

crawlFirstPageOfAllCates = (uris, callback) ->
  count = uris.length
  crawlDone = () ->
    count -= 1
    if count is 0 then callback null, null
  if uris.length > 0
    crawlPage uri, crawlDone for uri in uris
  else
    callback null, null

crawlPage = (pageUri, done) ->
  async.waterfall [
    queuePageUri(pageUri)
    saveItemsFromPage
  ], (err, result) ->
    if err then console.error err
    done()

queuePageUri = (pageUri) ->
  (callback) ->
    c.queue [
      'uri': pageUri
      'jQuery': false
      'forceUTF8': true
      'callback': callback
    ]

saveItemsFromPage = (result, callback) ->
  env result.body, (errors, window) ->
    $ = jquery window
    store = parseStoreFromUri result.uri
    items = extractItemsFromContent $, store
    db.saveItems store['store_id'], store['store_name'], items, result.uri
    window.close()
    callback null, null

extractCatsTreeHtml = ($, store) ->
  catsTreeHtml = $('ul.cats-tree').parent().html()
  if catsTreeHtml?
    catsTreeHtml = catsTreeHtml.trim().replace(/\"http.+category-(\d+).+\"/g, '"showCat.php?cid=$1&shop_id=' + store['store_id'] + '"').replace(/\r\n/g, '')
  else
    console.error "id:#{store['store_id']} #{store['store_name']}: catsTreeHtml is empty."
    catsTreeHtml = ''

makeUriWithStoreInfo = (uri, store) ->
  uri + "###{store['store_name']}###{store['store_id']}###{store['see_price']}"

parseStoreFromUri = (uri) ->
  uriParts = uri.split '##'
  store =
    'store_name': uriParts[1]
    'store_id': uriParts[2]
    'see_price': uriParts[3]

extractItemsFromContent = ($, store) ->
  items = []
  $('dl.item').each (index, element) ->
    $item = $(element)
    items.push
      goodsName: $item.find('a.item-name').text()
      defaultImage: $item.find('img').attr('src')
      price: parsePrice $item.find('.c-price').text().trim(), store['see_price']
      goodHttp: $item.find('a.item-name').attr('href')
  filterItems items

parsePrice = (price, seePrice) ->
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

filterItems = (unfilteredItems) ->
  items = item for item in unfilteredItems when not ~item.goodsName.indexOf('邮费') and
    not ~item.goodsName.indexOf('运费') and
    not ~item.goodsName.indexOf('淘宝网 - 淘！我喜欢') and
    not ~item.goodsName.indexOf('专拍') and
    not ~item.goodsName.indexOf('数据包') and
    not ~item.goodsName.indexOf('邮费') and
    not ~item.goodsName.indexOf('手机套') and
    not ~item.goodsName.indexOf('手机壳') and
    not ~item.goodsName.indexOf('定金') and
    not ~item.goodsName.indexOf('订金') and
    not ~item.goodsName.indexOf('下架') and
    not ~item.defaultImage.indexOf('http://img.taobao.com/newshop/nopicture.gif') and
    not ~item.defaultImage.indexOf('http://img01.taobaocdn.com/bao/uploaded/_180x180.jpg') and
    not ~item.defaultImage.indexOf('http://img01.taobaocdn.com/bao/uploaded/_240x240.jpg') and
    not ~item.defaultImage.indexOf('http://img01.taobaocdn.com/bao/uploaded/_160x160.jpg') and
    not (item.price <= 0)

if process.env.NODE_ENV is 'test'
  exports.crawlAllPagesOfAllCates = crawlAllPagesOfAllCates
  exports.setCrawlAllPagesOfAllCates = (f) -> crawlAllPagesOfAllCates = f
  exports.saveItemsFromPageAndQueueNext = saveItemsFromPageAndQueueNext
  exports.setSaveItemsFromPageAndQueueNext = (f) -> saveItemsFromPageAndQueueNext = f

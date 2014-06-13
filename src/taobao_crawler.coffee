async = require 'async'
env = require('jsdom').env
jquery = require('jquery')
crawler = require('crawler').Crawler
database = require('./database')

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

exports.crawlStore = (store, done) ->
  async.waterfall [
    (callback) ->
      c.queue [
        'uri': makeUriWithStoreInfo "#{store['shop_http']}/search.htm?search=y&orderType=newOn_desc", store
        'forceUTF8': true
        'callback': callback
      ]
    (result, callback) ->
      env result.body, callback
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
        window.close()
        callback null, uris
      else
        window.close()
        callback new Error('NoCategoryContent'), null
    (uris, callback) ->
      count = uris.length
      carwlDone = () ->
        count -= 1
        if count is 0 then callback null, null
      if uris.length > 0
        crawlPage uri, carwlDone for uri in uris
      else
        callback null, null
  ], (err, result) ->
    if err then console.error err
    done()

crawlPage = (pageUri, done) ->
  async.waterfall [
    (callback) ->
      c.queue [
        'uri': pageUri
        'jQuery': false
        'forceUTF8': true
        'callback': callback
      ]
    (result, callback) ->
      env result.body, (errors, window) ->
        $ = jquery window
        store = parseStoreFromUri result.uri
        items = extractItemsFromContent $, store
        db.saveItems store['store_id'], store['store_name'], items, result.uri
        window.close()
        callback null, null
  ], (err, result) ->
    if err then console.error err
    done()

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
      defaultImage: $item.find('img').attr('data-ks-lazyload')
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

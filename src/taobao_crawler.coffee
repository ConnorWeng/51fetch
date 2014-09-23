http = require 'http'
async = require 'async'
env = require('jsdom').env
jquery = require('jquery')
crawler = require('crawler').Crawler
database = require './database'
config = require './config'
{getTaobaoItem, getItemCats} = require './taobao_api'

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

exports.crawlItemViaApi = (itemUri, done) ->
  numIid = getNumIidFromUri itemUri
  getTaobaoItem numIid, 'title,desc,pic_url,sku,item_weight,property_alias,price,item_img.url,cid,nick,props_name,prop_img,delist_time', (err, item) ->
    if err
      console.error err
      done()
    else
      skus = parseSkus item.skus
      attrs = parseAttrs item.props_name
      getHierarchalCats item.cid, (err, cats) ->
        updateItemDetailInDatabase
          itemUri: itemUri
          desc: removeSingleQuotes item.desc
          skus: skus
          attrs: attrs
          cats: cats
        , done

exports.crawlStore = (store, done) ->
  async.waterfall [
    queueStoreUri(store)
    makeJsDom
    updateCateContentAndFetchAllCateUris(store)
    crawlAllPagesOfAllCates
  ], (err, result) ->
    if err then console.error err
    done()

updateItemDetailInDatabase = ({desc, skus, itemUri, attrs, cats}, callback) ->
  goodsId = ''
  price = ''
  storeId = ''
  store = {}
  good = {}
  async.waterfall [
    (callback) ->
      db.getGood itemUri, callback
    (result, callback) ->
      good = result
      goodsId = good.goods_id
      price = good.price
      storeId = good.store_id
      db.updateGoods desc, itemUri, callback
    (result, callback) ->
      db.getStores "store_id = #{storeId}", (err, stores) ->
        store = stores[0]
        callback err, stores
    (result, callback) ->
      db.updateCats goodsId, storeId, cats, callback
    (result, callback) ->
      db.deleteSpecs goodsId, callback
    (result, callback) ->
      db.updateSpecs skus, goodsId, price, callback
    (result, callback) ->
      if result?
        insertId = if result.length > 0 then result[0].insertId else result.insertId
        db.updateDefaultSpec goodsId, insertId, callback
      else
        callback null, null
    (result, callback) ->
      db.deleteItemAttr goodsId, callback
    (result, callback) ->
      outerId = makeOuterId store, good.goods_name, parsePrice(price, store.see_price, good.goods_name)
      outerIdAttr =
        attrId: '1'
        attrName: '商家编码'
        attrValue: outerId
      attrs.push outerIdAttr
      db.saveItemAttr goodsId, attrs, callback
    (result, callback) ->
      http.get "#{config.remote_service_address}&goodid=#{goodsId}", (res) ->
        if res.statusCode is 200 then callback null else callback new Error('remote update default image service error')
  ], (err, result) ->
    if err then console.error err
    callback null

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
    catsTreeHtml = removeSingleQuotes extractCatsTreeHtml $, store
    if catsTreeHtml isnt ''
      db.updateStoreCateContent store['store_id'], store['store_name'], catsTreeHtml
      uris = []
      $('a.cat-name').each (index, element) ->
        uri = $(element).attr('href')
        if uris.indexOf(uri) is -1 and ~uri.indexOf('category-') and ~uri.indexOf('#bd')
          uris.push makeUriWithStoreInfo(uri, store)
      if uris.length is 0
        if $('a.by-new').length isnt 0
          uris.push makeUriWithStoreInfo($('a.by-new').attr('href'), store)
        else if $('#J_Cats a:eq(3)').length isnt 0
          uris.push makeUriWithStoreInfo($('#J_Cats a:eq(3)').attr('href'), store)
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

extractCatsTreeHtml = ($, store) ->
  catsTreeHtml = $('ul.cats-tree').parent().html()
  if catsTreeHtml?
    catsTreeHtml = catsTreeHtml.trim().replace(/\"http.+category-(\d+).+\"/g, '"showCat.php?cid=$1&shop_id=' + store['store_id'] + '"').replace(/\r\n/g, '')
  else if (catsTreeHtml = $('ul#J_Cats').parent().html()) and catsTreeHtml?
    catsTreeHtml
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
  if $('dl.item').length > 0
    $('dl.item').each (index, element) ->
      $item = $(element)
      items.push
        goodsName: $item.find('a.item-name').text()
        defaultImage: extractDefaultImage $item
        price: parsePrice $item.find('.c-price').text().trim(), store['see_price']
        goodHttp: $item.find('a.item-name').attr('href')
  else if $('div.item').length > 0
    $('div.item').each (index, element) ->
      $item = $(element)
      items.push
        goodsName: $item.find('.desc a').text().trim()
        defaultImage: extractDefaultImage $item
        price: parsePrice $item.find('.price strong').text().trim(), store['see_price']
        goodHttp: $item.find('.desc a').attr('href')
  filterItems items

extractDefaultImage = ($item) ->
  defaultImage = $item.find('img').attr('src')
  if defaultImage is 'http://a.tbcdn.cn/s.gif' then defaultImage = $item.find('img').attr('data-ks-lazyload')
  defaultImage

parsePrice = (price, seePrice, goodsName) ->
  rawPrice = parseFloat price
  finalPrice = rawPrice
  if not seePrice? then finalPrice = rawPrice.toFixed(2)
  if seePrice.indexOf('减半') isnt -1
    finalPrice = (rawPrice / 2).toFixed(2)
  else if seePrice.indexOf('减') is 0
    finalPrice = (rawPrice - parseFloat(seePrice.substr(1))).toFixed(2)
  else if seePrice is '实价'
    finalPrice = rawPrice.toFixed(2)
  else if seePrice.indexOf('*') is 0
    finalPrice = (rawPrice * parseFloat(seePrice.substr(1))).toFixed(2)
  else if seePrice.indexOf('打') is 0
    finalPrice = (rawPrice * (parseFloat(seePrice.substr(1)) / 10)).toFixed(2)
  else if seePrice.indexOf('折') is seePrice.length - 1
    finalPrice = (rawPrice * (parseFloat(seePrice) / 10)).toFixed(2)
  else if seePrice is 'P'
    finalPrice = parseFloat /P(\d+(\.\d+)?)/.exec(goodsName)?[1]
  if isNaN(finalPrice) isnt true
    finalPrice
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

getNumIidFromUri = (uri) ->
  matches = /item\.htm\?.*id=(\d+)/.exec uri
  if matches?
    matches[1]
  else
    throw new Error('there is no numIid in uri')

parseSkus = (itemSkus) ->
  skuArray = itemSkus?.sku || []
  skus = []
  for sku in skuArray
    propertiesNameArray = sku.properties_name.split ';'
    properties = []
    for propertiesName in propertiesNameArray
      [pid, vid, name, value] = propertiesName.split ':'
      properties.push value
    skus.push properties
  skus

parseAttrs = (propsName) ->
  attrs = []
  propsArray = propsName.split ';'
  for props in propsArray
    [attrId, trival, attrName, attrValue] = props.split ':'
    attrs.push
      attrId: attrId
      attrName: attrName
      attrValue: attrValue
  attrs

getHierarchalCats = (cid, callback) ->
  cats = []
  next = (err, itemcats) ->
    cats.push itemcats[0]
    if itemcats[0].parent_cid is 0
      callback null, cats
    else
      getItemCats itemcats[0].parent_cid, 'name, cid, parent_cid', next
  getItemCats cid, 'name, cid, parent_cid', next

removeSingleQuotes = (content) ->
  content.replace /'/g, ''

makeOuterId = (store, title, price) ->
  seller = store.shop_mall + store.address
  huohao = getHuoHao title
  "#{seller}_P#{price}_#{huohao}#"

getHuoHao = (title) ->
  regex = /[A-Z]?\d+/g
  matches = regex.exec title
  while matches? and matches[0].length is 4 and matches[0].substr(0, 3) is '201'
    matches = regex.exec title
  matches?[0] || ''

if process.env.NODE_ENV is 'test'
  exports.parsePrice = parsePrice
  exports.crawlAllPagesOfAllCates = crawlAllPagesOfAllCates
  exports.setCrawlAllPagesOfAllCates = (f) -> crawlAllPagesOfAllCates = f
  exports.saveItemsFromPageAndQueueNext = saveItemsFromPageAndQueueNext
  exports.setSaveItemsFromPageAndQueueNext = (f) -> saveItemsFromPageAndQueueNext = f
  exports.getNumIidFromUri = getNumIidFromUri
  exports.parseSkus = parseSkus
  exports.parseAttrs = parseAttrs
  exports.removeSingleQuotes = removeSingleQuotes
  exports.getHuoHao = getHuoHao
  exports.makeOuterId = makeOuterId

if process.env.NODE_ENV is 'e2e'
  exports.getHierarchalCats = getHierarchalCats

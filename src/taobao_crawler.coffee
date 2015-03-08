http = require 'http'
async = require 'async'
{log, error} = require 'util'
env = require('jsdom').env
jquery = require('jquery')
crawler = require('crawler').Crawler
database = require './database'
config = require './config'
{getTaobaoItem, getItemCats} = require './taobao_api'

TEMPLATES = [
  BY_NEW: 'a.by-new'
  CAT_NAME: 'a.cat-name'
  CATS_TREE: 'ul.cats-tree'
  REPLACE: (html, store) ->
    html.replace(/\"http.+category-(\d+).+\"/g, '"showCat.php?cid=$1&shop_id=' + store['store_id'] + '"').replace(/\r\n/g, '')
  ITEM: '.shop-hesper-bd dl.item'
  ITEM_NAME: 'a.item-name'
  PRICE: '.c-price'
  CAT_SELECTED: '.hesper-cats ol li:last'
,
  BY_NEW: '#J_Cats a:eq(2)'
  CAT_NAME: 'NON_EXISTS_YET'
  CATS_TREE: 'ul#J_Cats'
  REPLACE: (html, store) ->
    html
  ITEM: '.shop-hesper-bd div.item'
  ITEM_NAME: '.desc a'
  PRICE: '.price strong'
]

c = new crawler
  'headers':
    'Cookie': config.cookie
  'method': 'POST'
  'forceUTF8': true
  'rateLimits': 3000
  'jQuery': false
db = new database()

exports.setDatabase = (newDb) ->
  db = newDb

exports.setCrawler = (newCrawler) ->
  c = newCrawler

exports.getCrawler = ->
  c

exports.getAllStores = (condition, callback) ->
  db.getStores condition, callback

exports.crawlItemViaApi = (itemUri, done) ->
  numIid = getNumIidFromUri itemUri
  getTaobaoItem numIid, 'title,desc,pic_url,sku,item_weight,property_alias,price,item_img.url,cid,nick,props_name,prop_img,delist_time', (err, item) ->
    if err
      error err
      done()
    else
      skus = parseSkus item.skus
      attrs = parseAttrs item.props_name
      getHierarchalCats item.cid, (err, cats) ->
        if err or cats.length is 0
          error "getHierarchalCats Error: cid #{item.cid} #{err}"
          done()
        else
          updateItemDetailInDatabase
            itemUri: itemUri
            desc: removeSingleQuotes item.desc
            skus: skus
            attrs: attrs
            cats: cats
            realPic: isRealPic item.title, item.props_name
            itemImgs: item.item_imgs.item_img
          , done

exports.crawlStore = (store, done) ->
  async.waterfall [
    queueStoreUri(store)
    makeJsDom
    updateCateContentAndFetchAllCateUris(store)
    clearCids(store)
    crawlAllPagesOfAllCates
    deleteDelistItems(store)
  ], (err, result) ->
    if err then error err
    done()

updateItemDetailInDatabase = ({desc, skus, itemUri, attrs, cats, realPic, itemImgs}, callback) ->
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
      db.updateGoods desc, itemUri, realPic, skus, callback
    (result, callback) ->
      db.updateItemImgs goodsId, itemImgs, callback
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
      outerId = makeOuterId store, good.goods_name, price, attrs
      outerIdAttr =
        attrId: '1'
        valueId: '1'
        attrName: '商家编码'
        attrValue: outerId
      attrs.push outerIdAttr
      db.saveItemAttr goodsId, attrs, callback
  ], (err, result) ->
    if err then error err
    callback null

queueStoreUri = (store) ->
  (callback) ->
    c.queue [
      'uri': makeUriWithStoreInfo "#{store['shop_http']}/search.htm?search=y&orderType=newOn_desc", store
      'forceUTF8': true
      'callback': callback
    ]

makeJsDom = (result, callback) ->
  if result.body is ''
    store = parseStoreFromUri result.uri
    callback new Error("id:#{store['store_id']} #{store['store_name']} doesn't exist"), null
  else
    env result.body, callback

totalItemsCount = 0
updateCateContentAndFetchAllCateUris = (store) ->
  (window, callback) ->
    $ = jquery window
    catsTreeHtml = removeSingleQuotes extractCatsTreeHtml $, store
    if catsTreeHtml isnt ''
      totalItemsCount = parseInt($('.search-result span').text())
      db.updateStoreCateContent store['store_id'], store['store_name'], catsTreeHtml
      imWw = extractImWw $, store['store_id'], store['store_name']
      if imWw then db.updateImWw store['store_id'], store['store_name'], imWw
      uris = extractUris $, store
      window.close()
      callback null, uris
    else
      totalItemsCount = 0
      window.close()
      callback new Error("NoCategoryContent: #{store['store_id']} #{store['store_name']} catsTreeHtml is empty"), null

extractUris = ($, store) ->
  uris = []
  for template in TEMPLATES
    if $(template.BY_NEW).length > 0
      uris.push makeUriWithStoreInfo($(template.BY_NEW).attr('href'), store)
    $(template.CAT_NAME).each (index, element) ->
      uri = $(element).attr('href')
      if uris.indexOf(uri) is -1 and ~uri.indexOf('category-') and (~uri.indexOf('#bd') or ~uri.indexOf('categoryp'))
        uris.push makeUriWithStoreInfo(uri, store)
    if $(template.BY_NEW).length > 0 then break
  uris

extractImWw = ($, storeId, storeName) ->
  imWw = $('.J_WangWang').attr('data-nick')
  if imWw
    decodeURI imWw
  else
    error "id:#{storeId} #{storeName} cannot find im_ww."
    ''

clearCids = (store) ->
  (uris, callback) ->
    db.clearCids store['store_id'], (err, result) ->
      if err
        callback err, null
      else
        callback null, uris

remains = 0
changeRemains = (action, callback, err = null) ->
  if action is '+'
    remains++
  else if action is '-'
    remains--
    if remains is 0 then callback err, null

crawlAllPagesOfAllCates = (uris, callback) ->
  for uri in uris
    store = parseStoreFromUri uri
    changeRemains '+', callback
    c.queue [
      'uri': makeUriWithStoreInfo uri, store
      'forceUTF8': true
      'callback': saveItemsFromPageAndQueueNext callback
    ]

deleteDelistItems = (store) ->
  (result, callback) ->
    db.deleteDelistItems store['store_id'], totalItemsCount, callback

saveItemsFromPageAndQueueNext = (callback) ->
  (err, result) ->
    debug result.body
    if result.body is ''
      changeRemains '-', callback
      error "Error: #{result.uri} return empty content"
    else
      env result.body, (errors, window) ->
        $ = jquery window
        store = parseStoreFromUri result.uri
        if $('.item-not-found').length > 0
          changeRemains '-', callback
          log "id:#{store['store_id']} #{store['store_name']} has one empty page: #{result.uri}"
        else
          nextUri = nextPageUri $
          if nextUri?
            changeRemains '+', callback
            c.queue [
              'uri': makeUriWithStoreInfo nextUri, store
              'forceUTF8': true
              'callback': saveItemsFromPageAndQueueNext callback
            ]
          items = extractItemsFromContent $, store
          bannedError = new Error('been banned by taobao') if isBanned $
          db.saveItems store['store_id'], store['store_name'], items, result.uri, $(TEMPLATES[0].CAT_SELECTED).text().trim(), ->
            changeRemains '-', callback, bannedError
        window.close()

nextPageUri = ($) ->
  $('div.pagination a.next').attr('href')

extractCatsTreeHtml = ($, store) ->
  catsTreeHtml = ''
  for template in TEMPLATES
    if $(template.CATS_TREE).length > 0
      html = $(template.CATS_TREE).parent().html().trim()
      catsTreeHtml = template.REPLACE html, store
      break
  if catsTreeHtml is ''
    error "id:#{store['store_id']} #{store['store_name']}: catsTreeHtml is empty."
  catsTreeHtml

makeUriWithStoreInfo = (uri, store) ->
  uri + "###{store['store_name']}###{store['store_id']}###{store['see_price']}"

parseStoreFromUri = (uri) ->
  uriParts = uri.split '##'
  store =
    'store_name': uriParts[1]
    'store_id': uriParts[2]
    'see_price': uriParts[3]

exports.extractItemsFromContent = extractItemsFromContent = ($, store) ->
  items = []
  for template in TEMPLATES
    if $(template.ITEM).length > 0
      $(template.ITEM).each (index, element) ->
        $item = $(element)
        items.push
          goodsName: $item.find(template.ITEM_NAME).text().trim()
          defaultImage: extractDefaultImage $item
          price: parsePrice $item.find(template.PRICE).text().trim(), store['see_price'], $item.find(template.ITEM_NAME).text().trim()
          goodHttp: $item.find(template.ITEM_NAME).attr('href')
      break
  filterItems items

isBanned = ($) ->
  $('.search-result').length is 0

extractDefaultImage = ($item) ->
  defaultImage = $item.find('img').attr('src')
  if defaultImage is 'http://a.tbcdn.cn/s.gif' then defaultImage = $item.find('img').attr('data-ks-lazyload')
  if ~defaultImage.indexOf('40x40')
    console.log $item.html()
    process.exit();
  defaultImage

parsePrice = (price, seePrice, goodsName) ->
  rawPrice = parseFloat price
  finalPrice = rawPrice
  if not seePrice? then finalPrice = formatPrice rawPrice
  if seePrice.indexOf('减半') isnt -1
    finalPrice = formatPrice(rawPrice / 2)
  else if seePrice is 'P' or seePrice is '减P' or seePrice is '减p'
    if /[Pp](\d+(\.\d+)?)/.test goodsName
      finalPrice = parseFloat /[Pp](\d+(\.\d+)?)/.exec(goodsName)?[1]
    else if /[Ff](\d+(\.\d+)?)/.test goodsName
      finalPrice = parseFloat /[Ff](\d+(\.\d+)?)/.exec(goodsName)?[1]
  else if seePrice.indexOf('减') is 0
    finalPrice = formatPrice(rawPrice - parseFloat(seePrice.substr(1)))
  else if seePrice is '实价'
    finalPrice = formatPrice rawPrice
  else if seePrice.indexOf('*') is 0
    finalPrice = formatPrice(rawPrice * parseFloat(seePrice.substr(1)))
  else if seePrice.indexOf('打') is 0
    finalPrice = formatPrice(rawPrice * (parseFloat(seePrice.substr(1)) / 10))
  else if seePrice.indexOf('折') is seePrice.length - 1
    finalPrice = formatPrice(rawPrice * (parseFloat(seePrice) / 10))
  if isNaN(finalPrice) isnt true
    finalPrice
  else
    error "不支持该see_price: #{price} #{seePrice} #{goodsName}"
    rawPrice

formatPrice = (price) ->
  newPrice = parseFloat(price).toFixed 2
  if ~newPrice.indexOf('.') and newPrice.split('.')[1] is '00'
    newPrice.split('.')[0]
  else
    newPrice

filterItems = (unfilteredItems) ->
  items = item for item in unfilteredItems when item.goodsName? and
    item.goodsName isnt '' and
    item.defaultImage? and
    not ~item.goodsName.indexOf('邮费') and
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
      properties.push
        pid: pid
        vid: vid
        name: name
        value: value
    skus.push properties
  skus

parseAttrs = (propsName) ->
  attrs = []
  propsArray = propsName.split ';'
  for props in propsArray
    [attrId, valueId, attrName, attrValue] = props.split ':'
    found = false
    for attr in attrs
      if attr.attrId is attrId
        attr.valueId = attr.valueId + ',' + valueId
        attr.attrValue = attr.attrValue + ',' + attrValue
        found = true
    if not found
      attrs.push
        attrId: attrId
        valueId: valueId
        attrName: attrName
        attrValue: attrValue
  attrs

getHierarchalCats = (cid, callback) ->
  cats = []
  next = (err, itemcats) ->
    if err or itemcats.length is 0
      callback err, cats
    else
      cats.push itemcats[0]
      if itemcats[0].parent_cid is 0
        callback null, cats
      else
        getItemCats itemcats[0].parent_cid, 'name, cid, parent_cid', next
  getItemCats cid, 'name, cid, parent_cid', next

removeSingleQuotes = (content) ->
  content.replace /'/g, ''

makeOuterId = (store, title, price, attrs) ->
  seller = store.shop_mall + store.address
  huohao = (getHuoHao title) || (getHuoHaoFromAttrs attrs)
  "#{seller}_P#{price}_#{huohao}#"

getHuoHao = (title) ->
  regex = /[A-Z]?\d+/g
  matches = regex.exec title
  while matches? and matches[0].length is 4 and matches[0].substr(0, 3) is '201'
    matches = regex.exec title
  matches?[0] || ''

getHuoHaoFromAttrs = (attrs) ->
  for attr in attrs
    if attr.attrName is '货号'
      return attr.attrValue
  return ''

isRealPic = (title, propsName) ->
  if ~title.indexOf('实拍') or ~propsName.indexOf('157305307')
    1
  else
    0

debug = (content) ->
  if process.env.NODE_ENV is 'debug'
    console.log '=============================================================='
    console.log content

if process.env.NODE_ENV is 'test'
  exports.setSaveItemsFromPageAndQueueNext = (f) -> saveItemsFromPageAndQueueNext = f
  exports.setCrawlAllPagesOfAllCates = (f) -> crawlAllPagesOfAllCates = f
  exports.setClearCids = (f) -> clearCids = f
  exports.setDeleteDelistItems = (f) -> deleteDelistItems = f
  exports.setMakeUriWithStoreInfo = (f) -> makeUriWithStoreInfo = f
  exports.setChangeRemains = (f) -> changeRemains = f
  exports.parsePrice = parsePrice
  exports.formatPrice = formatPrice
  exports.crawlAllPagesOfAllCates = crawlAllPagesOfAllCates
  exports.saveItemsFromPageAndQueueNext = saveItemsFromPageAndQueueNext
  exports.getNumIidFromUri = getNumIidFromUri
  exports.parseSkus = parseSkus
  exports.parseAttrs = parseAttrs
  exports.removeSingleQuotes = removeSingleQuotes
  exports.getHuoHao = getHuoHao
  exports.makeOuterId = makeOuterId
  exports.extractCatsTreeHtml = extractCatsTreeHtml
  exports.extractUris = extractUris
  exports.extractImWw = extractImWw
  exports.makeUriWithStoreInfo = makeUriWithStoreInfo
  exports.filterItems = filterItems
  exports.isRealPic = isRealPic
  exports.changeRemains = changeRemains

if process.env.NODE_ENV is 'e2e'
  exports.getHierarchalCats = getHierarchalCats
  exports.crawler = c

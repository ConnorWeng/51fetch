{writeFileSync, readFileSync, mkdirSync, existsSync, readdirSync, appendFileSync, unlinkSync} = require 'fs'
{log} = require '../src/util'
jquery = require 'jquery'
{fetch, makeJsDom, setRateLimits} = require '../src/crawler'
args = process.argv.slice 2

IMPORT_SQL_FILE = '../temp/ecm_store_vvic.sql'
IMPORT_FLOOR_SQL_FILE = '../temp/ecm_store_vvic_floor.sql'
SYNC_SQL_FILE = '../temp/ecm_store_vvic_sync.sql'
MARKET_MAP = {19: '国大', 12: '大西豪', 10: '大时代', 13: '女人街', 14: '国投', 15: '富丽', 18: '跨客城', 11: '宝华', 24: '鞋城', 37: '圣迦', 17: '柏美', 34: '三晟', 20: '新潮都', 16: '非凡', 23: '佰润', 25: '新金马', 42: '十三行', 35: '南城', 36: '金纱', 26: '老金马', 28: '万佳', 41: '益民', 27: '新百佳', 29: '西苑鞋汇', 43: '景叶', 39: '欣欣网批', 45: '西街福壹', 44: '狮岭', 38: '周边'}

setRateLimits 0

savePage = (page) ->
  pageFile = "../temp/#{page}.txt"
  if existsSync pageFile then return
  fetch "http://www.vvic.com/shops/#{page}", 'GET'
    .then (result) ->
      writeFileSync pageFile, result.body
      log "#{page} fetched"

saveShop = (page, shop) ->
  shopFile = "../temp/#{page}/#{shop}.txt"
  if existsSync shopFile then return
  fetch "http://www.vvic.com/shop/#{shop}", 'GET'
    .then (result) ->
      writeFileSync shopFile, result.body
      log "shop #{shop} fetched"

parsePage = (page) ->
  body = readFileSync("../temp/#{page}.txt", 'utf8')
  if not existsSync "../temp/#{page}" then mkdirSync "../temp/#{page}"
  makeJsDom body
    .then (window) ->
      $ = jquery window
      $('.items').each (i, item) ->
        saveShop page, $(item).attr('href').substr(6)
      window.close()

saveItem = (page, shop, item, shopFiles) ->
  dir = "../temp/#{page}/#{shop}"
  if not existsSync dir then mkdirSync dir
  itemFile = "../temp/#{page}/#{shop}/#{item}.txt"
  if existsSync itemFile
    _saveItems shopFiles, page
  else
    fetch "http://www.vvic.com/item/#{item}", 'GET'
      .then (result) ->
        writeFileSync itemFile, result.body
        log "page: #{page}, shop: #{shop}, item: #{item} fetched"
        _saveItems shopFiles, page

_saveItems = (shopFiles, page) ->
  if shopFiles.length > 0
    shopFileName = shopFiles.shift()
    if not ~shopFileName.indexOf('.txt')
      _saveItems shopFiles, page
    else
      shopFile = "../temp/#{page}/#{shopFileName}"
      shopFileContent = readFileSync shopFile, 'utf8'
      makeJsDom shopFileContent
        .then (window) ->
          $ = jquery window
          item = $('.title:eq(0) a').attr('href')
          if item
            item = item.substr 6
            shop = $('.btn-shop-care').attr('data-sid')
            window.close()
            saveItem page, shop, item, shopFiles
          else
            window.close()
            _saveItems shopFiles, page
  else
    log "page #{page} completed"

saveItems = (page) ->
  dir = "../temp/#{page}"
  shopFiles = readdirSync dir
  _saveItems shopFiles, page

_parseShops = (shopFiles, page) ->
  if shopFiles.length > 0
    shopFileName = shopFiles.shift()
    if not ~shopFileName.indexOf('.txt')
      _parseShops shopFiles, page
    else
      shopFile = "../temp/#{page}/#{shopFileName}"
      shopFileContent = readFileSync shopFile, 'utf8'
      shop = shopFileName.replace /\.txt/, ''
      makeJsDom shopFileContent
        .then (window) ->
          $ = jquery window
          shopInfo = getShopInfo $, page
          window.close()
          log shopInfo
          appendFileSync IMPORT_SQL_FILE, "insert into ecm_store_vvic(store_name, see_price, business_scope, shop_mall, floor, dangkou_address, shop_http, im_ww, im_wx, im_qq, tel, service_daifa, service_tuixian, serv_realpic, mk_name, address, vvic_http) values ('#{shopInfo.storeName}', '#{shopInfo.seePrice}', '#{shopInfo.scope}', '#{shopInfo.market}', '#{shopInfo.floor}', '#{shopInfo.dangkou}', '#{shopInfo.taobaoLink}', '#{shopInfo.ww}', '#{shopInfo.wx}', '#{shopInfo.qq}', '#{shopInfo.tel}', '#{shopInfo.daifa}', '#{shopInfo.tuixian}', '#{shopInfo.realpic}', '#{shopInfo.market}-#{shopInfo.floor}F', '#{shopInfo.address}', 'http://www.vvic.com/shop/#{shop}');\n"
          _parseShops shopFiles, page
  else
    log "page #{page} completed"

parseShops = (page) ->
  dir = "../temp/#{page}"
  shopFiles = readdirSync dir
  _parseShops shopFiles, page

getShopInfo = ($, page) ->
  storeName = $('.stall-head-name').text().replace(/'/g, "\\'")
  taobaoLink = $('a[vda="action|shopInfo|tblink"]').attr('href')
  taobaoLink = taobaoLink.substr 0, taobaoLink.length - 1
  wwRegex = /touid=(.+)$/
  wwHref = $('a[vda="action|shopInfo|ww"]').attr('href')
  matches = wwHref.match wwRegex
  ww = decodeURIComponent matches[1]
  tel = ''
  $('.tel-list p').each (i, p) ->
    tel += '/' + $(p).text()
  if tel.substr(0, 1) is '/' then tel = tel.substr(1)
  daifa = tuixian = realpic = 0
  if $('div[data-tip="sp"]').length > 0 then realpic = 1
  if $('div[data-tip="tx"]').length > 0 then tuixian = 1
  if $('div[data-tip="df"]').length > 0 then daifa = 1
  address = wx = qq = market = dangkou = floor = scope = ''
  $('ul.mt10 li').each (i, li) ->
    label = $(li).find('.attr').text()
    text = $(li).find('.text').text()
    if label is '主营：' then scope = text.trim().replace(/\n/g, '').replace(/\s+/g, ' ')
    if label is '微信：' then wx = text
    if label is 'QQ：' then qq = text
    if label is '地址：'
      address = text
      address = address.substr(0, address.length - 2).replace(/\n/g, '').replace(/\s/g, ';').replace('', '')
      addressParts = address.split ';'
      market = MARKET_MAP[page]
      floor = parseInt addressParts[1] + ''
      dangkou = addressParts[2]
      address = address.replace(/;/g, ' ')

  seePrice = ''
  item = $('.title:eq(0) a').attr('href')
  shop = $('.stall-head-name a').attr('href')
  if item and shop
    item = item.substr 6
    shop = shop.substr 6
    seePrice = getSeePrice page, shop, item

  return {
    storeName: storeName
    seePrice: seePrice
    scope: scope
    address: address
    market: market
    floor: floor
    dangkou: dangkou
    taobaoLink: taobaoLink
    ww: ww
    tel: tel
    wx: wx
    qq: qq
    daifa: daifa
    tuixian: tuixian
    realpic: realpic
  }

getSeePrice = (page, shop, item) ->
  itemFile = "../temp/#{page}/#{shop}/#{item}.txt"
  if not existsSync itemFile then return ''
  itemFileContent = readFileSync itemFile, 'utf8'
  taobaoPriceRegex = /\<span class\="d-sale"\>(.+)\<\/span\>/
  taobaoPriceMatches = itemFileContent.match(taobaoPriceRegex)
  if not taobaoPriceMatches then return ''
  taobaoPrice = parseFloat taobaoPriceMatches[1]
  priceRegex = /\<strong class\="d-sale"\>(.+)\<\/strong\>/
  priceMatches = itemFileContent.match(priceRegex)
  if not priceMatches then return ''
  price = parseFloat priceMatches[1]
  if taobaoPrice / price is 2 then return '减半'
  delta = parseInt(taobaoPrice - price)
  "减#{delta}"

parseFloor = () ->
  body = readFileSync("../temp/#{page}.txt", 'utf8')
  if not existsSync "../temp/#{page}" then mkdirSync "../temp/#{page}"
  makeJsDom body
    .then (window) ->
      $ = jquery window
      $('.items').each (i, item) ->
        shop = $(item).attr('href').substr(6)
        shopName = $(item).attr('data-title')
        market = $(item).attr('data-market')
        floor = $(item).attr('data-floor') + '楼'
        dangkou = $(item).attr('data-position')
        address = "#{market} #{floor} #{dangkou}"
        floor = $(item).closest('.stall-table').find('dt:eq(0) h2').text().trim()
        floorParts = floor.split '楼'
        if floorParts.length > 1 && floorParts[1] isnt '' then floor = "#{floorParts[1]}#{floorParts[0]}" else floor = floorParts[0]
        if floor isnt '推荐档口'
          appendFileSync IMPORT_FLOOR_SQL_FILE, "update ecm_store_vvic set floor = '#{floor}' where address = '#{address}' and store_name = '#{shopName}';\n"
        log "#{address} updated"
      window.close()

pages = [19,12,10,13,14,15,18,11,24,37,17,34,20,16,23,25,42,35,36,26,28,41,27,29,43,39,45,44,38];

if args[0] is 'save'
  savePage page for page in pages

if args[0] is 'parse'
  parsePage page for page in pages

if args[0] is 'items'
  saveItems page for page in pages

if args[0] is 'shops'
  if existsSync IMPORT_SQL_FILE then unlinkSync IMPORT_SQL_FILE
  parseShops page for page in pages

if args[0] is 'floor'
  if existsSync IMPORT_FLOOR_SQL_FILE then unlinkSync IMPORT_FLOOR_SQL_FILE
  parseFloor page for page in pages

if args[0] is 'sync'
  if existsSync SYNC_SQL_FILE then unlinkSync SYNC_SQL_FILE
  appendFileSync SYNC_SQL_FILE, "update ecm_store_vvic v set v.ecm_store_id = (select store_id from ecm_store where shop_http = v.shop_http limit 1);\n"
  appendFileSync SYNC_SQL_FILE, "update ecm_store s inner join ecm_store_vvic v on s.im_ww = v.im_ww set s.shop_http = v.shop_http where s.state = 1 and s.shop_http not like 'https://shop%';\n"

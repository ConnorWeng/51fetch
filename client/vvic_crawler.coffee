{writeFileSync, readFileSync, mkdirSync, existsSync, readdirSync} = require 'fs'
{log} = require 'util'
jquery = require 'jquery'
{fetch, makeJsDom} = require '../src/crawler'
args = process.argv.slice 2

savePage = (page) ->
  pageFile = "../temp/#{page}.txt"
  if existsSync pageFile then return
  fetch "http://www.vvic.com/shops/#{page}", 'GET'
    .then (body) ->
      writeFileSync pageFile, body
      log "#{page} fetched"

saveShop = (page, shop) ->
  shopFile = "../temp/#{page}/#{shop}.txt"
  if existsSync shopFile then return
  fetch "http://www.vvic.com/shop/#{shop}", 'GET'
    .then (body) ->
      writeFileSync shopFile, body
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
      .then (body) ->
        writeFileSync itemFile, body
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

saveItems = (page) ->
  dir = "../temp/#{page}"
  shopFiles = readdirSync dir
  _saveItems shopFiles, page

parseShops = (page) ->
  dir = "../temp/#{page}"
  shopFiles = readdirSync dir
  for shopFileName in shopFiles
    if not ~shopFileName.indexOf('.txt') then continue
    shopFile = "../temp/#{page}/#{shopFileName}"
    shopFileContent = readFileSync shopFile, 'utf8'
    makeJsDom shopFileContent
      .then (window) ->
        $ = jquery window
        shopInfo = getShopInfo $, page
        window.close()
        log shopInfo

getShopInfo = ($, page) ->
  storeName = $('.stall-head-name').text()
  taobaoLink = $('a[vda="action|shopInfo|tblink"]').attr('href')
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
      address = address.substr(0, address.length - 2).replace(/\n/g, '').replace(/\s/g, ';')
      addressParts = address.split ';'
      market = addressParts[0]
      floor = parseInt addressParts[1] + ''
      dangkou = addressParts[2]

  seePrice = ''
  item = $('.title:eq(0) a').attr('href')
  shop = $('.stall-head-name span').attr('href')
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
  taobaoPriceRegex = /\<span class\="sale"\>(.+)\<\/span\>/
  taobaoPriceMatches = itemFileContent.match(taobaoPriceRegex)
  if not taobaoPriceMatches then return ''
  taobaoPrice = parseFloat taobaoPriceMatches[1]
  priceRegex = /\<strong class\="sale"\>(.+)\<\/strong\>/
  priceMatches = itemFileContent.match(priceRegex)
  if not priceMatches then return ''
  price = parseFloat priceMatches[1]
  if taobaoPrice / price is 2 then return '减半'
  delta = parseInt(taobaoPrice - price)
  "减#{delta}"

pages = [19,12,10,13,14,15,18,11,24,37,17,34,20,16,23,25,42,35,36,26,28,41,27,29,43,39,45,44,38];

if args[0] is 'save'
  savePage page for page in pages

if args[0] is 'parse'
  parsePage page for page in pages

if args[0] is 'shops'
  parseShops page for page in pages

if args[0] is 'items'
  saveItems page for page in pages

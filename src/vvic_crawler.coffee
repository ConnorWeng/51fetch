Q = require 'q'
jquery = require('jquery')
{log, error, inspect, debug, trace} = require './util'
{fetch, makeJsDom, setRateLimits} = require './crawler'
database = require './database'

db = new database()

saveItems = Q.nbind db.saveItems, db
deleteDelistItems = Q.nbind db.deleteDelistItems, db

exports.crawlStore = (store, fullCrawl, done) ->
  items = []
  crawlNextPage "#{store['vvic_http']}?&currentPage=1", items, store
    .then ->
      crawlExtraItemInfo items, 0
    .then ->
      saveItems store['store_id'], store['store_name'], items, '', '所有宝贝', 1
    .then ->
      deleteDelistItems store['store_id'], store['total_items_count']
    .then ->
      done()
    .catch (err) ->
      error err
      done()

crawlNextPage = (url, items, store) ->
  fetch url, 'GET'
    .then (res) ->
      body = res.body
      makeJsDom body
    .then (window) ->
      $ = jquery window
      setTotalCount store, $
      pushItems items, $
      nextUrl = nextPage $, url
      if nextUrl
        window.close()
        log "store #{store['store_id']} crawled one page, ready for the next page"
        crawlNextPage nextUrl, items, store
      else
        window.close()
    .catch (err) ->
      error url
      error err
      throw err

crawlExtraItemInfo = (items, index) ->
  fetch items[index].vvicHttp, 'GET'
    .then (res) ->
      body = res.body
      makeJsDom body
    .then (window) ->
      $ = jquery window
      items[index].goodHttp = goodHttp $
      items[index].taobaoPrice = taobaoPrice $
      items[index].huohao = huohao $
      log items[index]
      window.close()
      if index + 1 < items.length
        crawlExtraItemInfo items, index + 1
    .catch (err) ->
      error items[index].vvicHttp
      error err
      throw err

setTotalCount = (store, $) ->
  count = parseInt $('.nc-count .num').text()
  store['total_items_count'] = count

pushItems = (items, $) ->
  $('#content_all .goods-list .item').each (index, element) ->
    $e = $(element)
    if $e.find('span.dktj').length is 0
      items.push
        goodsName: goodsName $e
        defaultImage: defaultImage $e
        price: price $e
        vvicHttp: vvicHttp $e
        taobaoPrice: ''
        goodHttp: ''

nextPage = ($, currentUrl) ->
  currentPage = parseInt /window.CURRENTPAGE = '(\d+)'/.exec($('body').html())?[1]
  pageCount = parseInt /window.PAGECOUNT = '(\d+)'/.exec($('body').html())?[1]
  if currentPage < pageCount
    currentUrl.replace /currentPage=\d+/, "currentPage=#{currentPage + 1}"
  else
    ''

goodsName = ($) ->
  $.find('.title').text().trim()

defaultImage = ($) ->
  "http:" + $.find('.pic img').attr('data-original').replace(/230x230/, '240x240')

price = ($) ->
  $.find('.fl.price').text().trim().substr(1)

taobaoPrice = ($) ->
  $('.v-price .sale').eq(1).text()

vvicHttp = ($) ->
  "http://www.vvic.com#{$.find('.title a').attr('href')}"

goodHttp = ($) ->
  $('.product-intro .name a').attr('href').replace('https', 'http')

huohao = ($) ->
  $('.value.ff-arial').eq(0).text().trim().replace('#', '')

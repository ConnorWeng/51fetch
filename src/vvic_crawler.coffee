Q = require 'q'
jquery = require('jquery')
{log, error, inspect, debug, trace} = require './util'
{fetch, makeJsDom, setRateLimits} = require './crawler'
database = require './database'

db = new database()

saveItems = Q.nbind db.saveItems, db

exports.crawlStore = (store, fullCrawl, done) ->
  items = []
  crawlNextPage "#{store['vvic_http']}?&currentPage=1", items
    .then ->
      crawlExtraItemInfo items, 0
    .then ->
      saveItems store['store_id'], store['store_name'], items, '', '所有宝贝', 1
    .then ->
      done()
    .catch (err) ->
      error err
      done()

crawlNextPage = (url, items) ->
  fetch url, 'GET'
    .then (res) ->
      body = res.body
      makeJsDom body
    .then (window) ->
      $ = jquery window
      pushItems items, $
      nextUrl = nextPage $, url
      if nextUrl
        window.close()
        log 'crawled one page, ready for the next page'
        crawlNextPage nextUrl, items
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
      log items[index]
      window.close()
      if index + 1 < items.length
        crawlExtraItemInfo items, index + 1
    .catch (err) ->
      error items[index].vvicHttp
      error err
      throw err

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

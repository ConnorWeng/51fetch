{Crawler} = require 'crawler'
{env} = require 'jsdom'
jquery = require 'jquery'
Q = require 'q'
Database = require '../src/database'

db = new Database

c = new Crawler
  'method': 'POST'
  'forceUTF8': true
  'jQuery': false

fetch = (url) ->
  defered = Q.defer()
  c.queue [
    'uri': url
    'callback': (err, result) ->
      if err
        defered.reject err
      else
        defered.resolve result.body
  ]
  defered.promise

makeJsDom = (html) ->
  defered = Q.defer()
  env html, (err, window) ->
    if err
      defered.reject err
    else
      defered.resolve window
  defered.promise

fetch 'http://rate.taobao.com/user-rate-UOmNYMCIYvGcG.htm?spm=a1z10.1.0.0.FnV5d5'
  .then (html) ->
    # 这里返回如果是一个新promise, 后续调用then就会根据该新promise状态,
    # 调用fulfilledHandler或者rejectedHandler
    # 如果返回一个value, 就会生成一个新地fulfilled的promise, 其filled的value便是返回的value
    # 所以后续调用then马上就会调用fulfilledHandler并且把value传过去
    makeJsDom html
  .then (window) ->
    $ = jquery window
    rateStr = ($) ->
      (index) ->
        $tr = $("#J_show_list > ul > li:eq(#{index}) tbody > tr:eq(1)")
        "#{$tr.find('.rateok').text().trim()},#{$tr.find('.ratenormal').text().trim()},#{$tr.find('.ratebad').text().trim()}"
    saleRateStr = rateStr $
    rate =
      username: $('.info-block .title > a').html()
      renzheng: $('ul.quality img').attr('title')
      shopurl: $('.info-block .title > a').attr('href')
      zhuying: $('.info-block > ul > li:eq(0) > a').text().trim()
      shopdate: $('#J_showShopStartDate').val()
      addr: $('.info-block > ul > li:eq(1)').text().substr(7).trim()
      zhongping: saleRateStr(3).split(',')[1]
      chaping: saleRateStr(3).split(',')[2]
      buyerrate: $('.sep > li:eq(1)').text().substr(7).trim()
      salerrate: $('.sep > li:eq(0)').text().substr(7).trim()
      saleweekly: saleRateStr(0)
      salemonthly: saleRateStr(1)
      salehalfyear: saleRateStr(2)
      saleyearago: saleRateStr(3)
      description: $('.J_RateInfoTrigger:eq(0) em.count').text()
      service: $('.J_RateInfoTrigger:eq(1) em.count').text()
      delivery: $('.J_RateInfoTrigger:eq(2) em.count').text()
      userid: $('#monthuserid').val()
    window.close()
    fetch "http://rate.taobao.com/member_rate.htm?a=1&_ksTS=1420530330794_158&callback=shop_rate_list&content=1&result=&from=rate&user_id=#{rate.userid}&identity=1&rater=0&direction=0"
  .then (str) ->
    jsonStr = str.trim()
    startIndex = jsonStr.indexOf('shop_rate_list(') + 15
    endIndex = jsonStr.lastIndexOf(')')
    jsonStr = jsonStr.substring startIndex, endIndex
    comments = JSON.parse jsonStr
    promiseQuery = Q.nbind db.query, db
    promiseQuery 'select * from ecm_store limit 1'
  .then undefined, (err) ->
    console.error err

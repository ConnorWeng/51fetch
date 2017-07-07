{Crawler} = require 'crawler'
chai = require 'chai'
chai.should()

c = new Crawler
  'method': 'POST'
  'forceUTF8': true

describe 'generic crawler', ->
  it.skip 'should get html from url', (done) ->
    rateStr = ($) ->
      (index) ->
        $tr = $("#J_show_list > ul > li:eq(#{index}) tbody > tr:eq(1)")
        "#{$tr.find('.rateok').text().trim()},#{$tr.find('.ratenormal').text().trim()},#{$tr.find('.ratebad').text().trim()}"
    c.queue [
      'uri': 'http://rate.taobao.com/user-rate-UOmNYMCIYvGcG.htm?spm=a1z10.1.0.0.FnV5d5'
      'callback': (err, result, $) ->
        $('.info-block .title > a').html().should.equal '清秀8可人' # username
        # regdate
        $('ul.quality img').attr('title').should.equal '支付宝个人认证' # renzheng
        $('.info-block .title > a').attr('href').should.equal 'http://store.taobao.com/shop/view_shop-044b6e67d363aa3bc67047248ab475d7.htm' # shopurl
        $('.info-block > ul > li:eq(0) > a').text().trim().should.equal '服饰鞋包' # zhuying
        $('#J_showShopStartDate').val().should.equal '2012-04-05' # shopdate
        $('.info-block > ul > li:eq(1)').text().substr(7).trim().should.equal '深圳' # addr
        saleRateStr = rateStr $
        saleRateStr(3).split(',')[1].should.equal '3' # zhongping
        saleRateStr(3).split(',')[2].should.equal '0' # chaping
        $('.sep > li:eq(1)').text().substr(7).trim().should.equal '111' # buyerrate
        # buyweekly
        # buymonthly
        # buyhalfyear
        # buyyearago
        # buyaverage
        $('.sep > li:eq(0)').text().substr(7).trim().should.equal '224' # salerrate
        saleRateStr(0).should.equal '1,0,0' # saleweekly
        saleRateStr(1).should.equal '6,0,0' # salemonthly
        saleRateStr(2).should.equal '47,1,0' # salehalfyear
        saleRateStr(3).should.equal '177,3,0' # saleyearago
        $('.J_RateInfoTrigger:eq(0) em.count').text().should.equal '4.2' # description
        $('.J_RateInfoTrigger:eq(1) em.count').text().should.equal '4.3' # service
        $('.J_RateInfoTrigger:eq(2) em.count').text().should.equal '4.3' # delivery
        $('#monthuserid').val().should.equal 'UOmNYMCIYvGcG' # userid
        done()
    ]
  it.skip 'should get rate', (done) ->
    c.queue [
      'uri': 'http://rate.taobao.com/member_rate.htm?a=1&_ksTS=1420530330794_158&callback=shop_rate_list&content=1&result=&from=rate&user_id=UMCc0vGvWOmIy&identity=1&rater=0&direction=0'
      'forceUTF8': true
      'jQuery': false
      'callback': (err, result) ->
        jsonStr = result.body.trim()
        startIndex = jsonStr.indexOf('shop_rate_list(') + 15
        endIndex = jsonStr.lastIndexOf(')')
        jsonStr = jsonStr.substring startIndex, endIndex
        console.log JSON.parse jsonStr
        done()
    ]

assert = require('chai').assert
jsdom = require 'jsdom'
taobao_crawler = require './taobao_crawler.js'
taobao = new taobao_crawler()

describe 'taobao_crawler', () ->
  beforeEach () ->
    taobao = new taobao_crawler()

  describe '#fetchAllStores()', () ->
    it 'should call fetchStore() for every store', (done) ->
      stores = [{
        store_id: 'fake_store_id_1'
        store_name: 'fake_store_1'
        shop_http: 'http://fake_store_1.com'
      }, {
        store_id: 'fake_store_id_2'
        store_name: 'fake_store_2'
        shop_http: 'http://fake_store_2.com'
      }]
      fetchedStores = []
      taobao.db.getStores = (condition, callback) ->
        callback null, stores
      taobao.fetchStore = (store) ->
        fetchedStores.push store
        if fetchedStores.length == stores.length
          assert.deepEqual fetchedStores, stores
          done()
      taobao.fetchAllStores()

  describe '#fetchStore()', () ->
    it 'should queue shopUrl', () ->
      store =
        store_id: 'fake_store_id'
        store_name: 'fake_store'
        shop_http: 'http://fake_store.com'
        see_price: 'fake_see_price'
      taobao.crawler.queue = (uri) ->
        if typeof uri is 'string'
          assert.equal uri, "http://fake_store.com/search.htm?search=y&orderType=newOn_desc##fake_store##fake_store_id##fake_see_price"
      taobao.fetchStore store

  describe '#extractItemsFromContent()', () ->
    it 'should return filtered items', (done) ->
      jsdom.env html_contains_two_items, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) ->
        store =
          see_price: '减20'
        items = taobao.extractItemsFromContent window.$, store
        assert.deepEqual items, [{
          goodsName: 'apple 最新OS系统 U盘安装'
          defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i4/T1q3ONFuJdXXXXXXXX_!!0-item_pic.jpg_240x240.jpg'
          price: '45.00'
          goodHttp: 'http://item.taobao.com/item.htm?id=37498952035'
        }, {
          goodsName: 'zara 男士休闲皮衣 专柜正品'
          defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i1/T1.cFWFuRaXXb0JV6a_240x240.jpg'
          price: '279.00'
          goodHttp: 'http://item.taobao.com/item.htm?id=37178066336'
        }]
        done()

  describe '#queueNextPage()', () ->
    it 'should queue next page uri', (done) ->
      store =
        store_id: 'fake_store_id'
        store_name: 'fake_store'
        see_price: 'fake_see_price'
      taobao.crawler.queue = (uri) ->
        assert.equal uri, "http://22242.taobao.com/search.htm?mid=w-932662238-0&search=y&spm=a1z10.1.w4010-932671178.4.iklfDd&orderType=newOn_desc&pageNo=2#anchor##fake_store##fake_store_id##fake_see_price"
        done()
      jsdom.env html_contains_next_page, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) ->
        taobao.queueNextPage window.$, store

  describe '#parsePrice()', () ->
    it 'should return 50', () ->
      assert.equal taobao.parsePrice('100.00', '减半'), '50.00'
    it 'should return 80', () ->
      assert.equal taobao.parsePrice('100.00', '减20'), '80.00'
    it 'should return 100', () ->
      assert.equal taobao.parsePrice('100.00', '实价'), '100.00'
    it 'should return 70', () ->
      assert.equal taobao.parsePrice('100.00', '*0.7'), '70.00'

  describe '#filterItems()', () ->
    it 'should return items without unused items', () ->
      unfilteredItems = [{
        goodsName: '邮费补拍专用'
      }, {
        goodsName: '运费加价专用'
      }, {
        goodsName: '淘宝网 - 淘！我喜欢'
      }, {
        goodsName: '订金专拍'
      }, {
        goodsName: '正常宝贝'
      }]
      items = taobao.filterItems unfilteredItems
      assert.deepEqual items, [{goodsName: '正常宝贝'}]


html_contains_two_items = """
<dl class="item " data-id="37498952035">
  <dt class="photo">
    <a href="http://item.taobao.com/item.htm?id=37498952035" target="_blank">
      <img alt="apple 最新OS系统 U盘安装"  data-ks-lazyload="http://img01.taobaocdn.com/bao/uploaded/i4/T1q3ONFuJdXXXXXXXX_!!0-item_pic.jpg_240x240.jpg" src="http://a.tbcdn.cn/s.gif"  >
    </a>
  </dt>
  <dd class="detail">
    <a class="item-name" href="http://item.taobao.com/item.htm?id=37498952035" target="_blank">apple 最新OS系统 U盘安装</a>
    <div class="attribute">
      <div class="cprice-area"><span class="symbol">&yen;</span><span class="c-price">65.00 </span></div>
      <div class="sale-area">已售：<span class="sale-num">4</span>件</div>
    </div>
  </dd>
  <dd class="rates">
    <div class="title">
      <h4>
        评论(<a href="http://item.taobao.com/item.htm?id=37498952035&on_comment=1" target="_blank"><span>2</span></a>)
      </h4>
    </div>
    <p class="rate J_TRate"></p>
  </dd>
</dl>

<dl class="item " data-id="37178066336">
  <dt class="photo">
    <a href="http://item.taobao.com/item.htm?id=37178066336" target="_blank">
      <img alt="zara 男士休闲皮衣 专柜正品"  data-ks-lazyload="http://img01.taobaocdn.com/bao/uploaded/i1/T1.cFWFuRaXXb0JV6a_240x240.jpg" src="http://a.tbcdn.cn/s.gif"  >
    </a>
  </dt>
  <dd class="detail">
    <a class="item-name" href="http://item.taobao.com/item.htm?id=37178066336" target="_blank">zara 男士休闲皮衣 专柜正品</a>
    <div class="attribute">
      <div class="cprice-area"><span class="symbol">&yen;</span><span class="c-price">299.00 </span></div>
      <div class="sale-area">已售：<span class="sale-num">0</span>件</div>
    </div>
  </dd>
  <dd class="rates">
    <div class="title">
      <h4>
        评论(<a href="http://item.taobao.com/item.htm?id=37178066336&on_comment=1" target="_blank"><span>0</span></a>)
      </h4>
    </div>
    <p class="rate J_TRate"></p>
  </dd>
</dl>
"""

html_contains_next_page = """
<div class="pagination">
  <a class="disable">上一页</a>
  <a class="page-cur">1</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.1.w4010-932671178.4.iklfDd&amp;orderType=newOn_desc&pageNo=2#anchor">2</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.1.w4010-932671178.4.iklfDd&amp;orderType=newOn_desc&pageNo=3#anchor">3</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.1.w4010-932671178.4.iklfDd&amp;orderType=newOn_desc&pageNo=4#anchor">4</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.1.w4010-932671178.4.iklfDd&amp;orderType=newOn_desc&pageNo=5#anchor">5</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.1.w4010-932671178.4.iklfDd&amp;orderType=newOn_desc&pageNo=6#anchor">6</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.1.w4010-932671178.4.iklfDd&amp;orderType=newOn_desc&pageNo=7#anchor">7</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.1.w4010-932671178.4.iklfDd&amp;orderType=newOn_desc&pageNo=8#anchor">8</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.1.w4010-932671178.4.iklfDd&amp;orderType=newOn_desc&pageNo=9#anchor">9</a>
  <span class="break">...</span>
  <a class="J_SearchAsync next" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.1.w4010-932671178.4.iklfDd&amp;orderType=newOn_desc&pageNo=2#anchor">下一页</a>
  <form action="http://22242.taobao.com/search.htm" method="get">
    <input type="hidden" name="mid" value="w-932662238-0">
    <input type="hidden" name="search" value="y">
    <input type="hidden" name="spm" value="a1z10.1.w4010-932671178.4.iklfDd">
    <input type="hidden" name="orderType" value="newOn_desc">
    到第 <input type="text" value="1" size="3" name="pageNo"> 页
    <button type="submit">确定</button>
  </form>
  <!--END OF  pagination-->
</div>
"""

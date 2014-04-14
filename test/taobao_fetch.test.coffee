taobao_fetch = require './taobao_fetch.js'
taobao = new taobao_fetch()
assert = require('chai').assert

describe 'taobao_fetch', () ->
  beforeEach () ->
    taobao = new taobao_fetch()

  describe '#updateStoreCategories()', () ->
    it 'should call back with all categories urls', (done) ->
      taobao.db =
        updateStoreCateContent: (storeId, storeName, cateContent) ->
          assert.equal storeId, 'any store id'
          assert.equal storeName, 'any store name'
          assert.include cateContent, 'cats-tree'
      store =
        store_id: 'any store id'
        store_name: 'any store name'
        shop_http: 'http://kustar.taobao.com'
      taobao.updateStoreCategories store, (err, urls) ->
        assert.deepEqual urls, ['http://kustar.taobao.com/category-481678449.htm?search=y&catName=%B3%E4%D6%B5','http://kustar.taobao.com/category-481710447.htm?search=y&parentCatId=481678449&parentCatName=%B3%E4%D6%B5&catName=QQ%B1%D2','http://kustar.taobao.com/category-858007766.htm?search=y&parentCatId=481678449&parentCatName=%B3%E4%D6%B5&catName=%D6%D0%B9%FA%D2%C6%B6%AF','http://kustar.taobao.com/category-858009951.htm?search=y&catName=%D4%AD%B5%A5%CD%E2%C3%B3','http://kustar.taobao.com/category-869527593.htm?search=y&catName=OS+%CF%B5%CD%B3']
        done()

  describe '#fetchStore()', () ->
    it 'should fetch all categories of the store', () ->
      urls = []
      taobao.fetchUrl = (url, store) ->
        urls.push url
      taobao.stores = [{
        store_id: 'anyId'
        store_name: 'anyStore'
        shop_http: 'http://taobao.com/shop'}]
      taobao.pool =
        acquire: (callback) ->
          callback null, 1
      taobao.updateStoreCategories = (store, callback) ->
        callback null, ['http://taobao.com/shop/category-1.html', 'http://taobao.com/shop/category-2.html']
      taobao.fetchStore()
      assert.deepEqual urls, ['http://taobao.com/shop/category-1.html', 'http://taobao.com/shop/category-2.html']

  describe '#requestHtmlContent()', () ->
    it 'should return html content correctly', (done) ->
      taobao.requestHtmlContent 'http://shop109132076.taobao.com/search.htm?spm=a1z10.3.0.0.dgCTRH&search=y&orderType=newOn_desc', (err, result) ->
        if err
          throw err
        else
          assert.include result, '共搜索到'
        done()
    it.skip 'should not be banned after request 100 times', (done) ->
      this.timeout 180000
      requestTaobao = () ->
        taobao.requestHtmlContent 'http://shop109132076.taobao.com/search.htm?spm=a1z10.3.0.0.dgCTRH&search=y&orderType=newOn_desc', (err, result) ->
          if err
            throw err
          else
            assert.include result, '共搜索到'
          next()
      count = 100
      queue = []
      while count > 0
        count -= 1
        queue.push requestTaobao
      next = () ->
        task = queue.shift()
        if task then task() else done()
      next()

  describe '#extractItemsFromContent()', () ->
    it 'should return a list of items', (done) ->
      this.timeout 0
      taobao.extractItemsFromContent html_contains_two_items, (err, items) ->
        if err
          throw err
        else
          assert.deepEqual items, [{
            goodsName: 'apple 最新OS系统 U盘安装'
            defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i4/T1q3ONFuJdXXXXXXXX_!!0-item_pic.jpg_240x240.jpg'
            price: '65.00'
            goodHttp: 'http://item.taobao.com/item.htm?id=37498952035'
          }, {
            goodsName: 'zara 男士休闲皮衣 专柜正品'
            defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i1/T1.cFWFuRaXXb0JV6a_240x240.jpg'
            price: '299.00'
            goodHttp: 'http://item.taobao.com/item.htm?id=37178066336'
          }]
        done()

  describe '#nextPage()', () ->
    it 'should return url when has next page', (done) ->
      taobao.nextPage html_contains_next_page, (err, url) ->
        assert.isNotNull url
        done()
    it 'should return null when no next page', (done) ->
      taobao.nextPage html_contains_no_next_page, (err, url) ->
        assert.isNull url
        done()

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

html_contains_no_next_page = """
<div class="pagination">
  <a class="J_SearchAsync prev" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.3.w4002-932662238.107.HSEgVj&amp;orderType=newOn_desc&pageNo=12#anchor">上一页</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.3.w4002-932662238.107.HSEgVj&amp;orderType=newOn_desc&pageNo=1#anchor">1</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.3.w4002-932662238.107.HSEgVj&amp;orderType=newOn_desc&pageNo=2#anchor">2</a>
  <span class="break">...</span>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.3.w4002-932662238.107.HSEgVj&amp;orderType=newOn_desc&pageNo=7#anchor">7</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.3.w4002-932662238.107.HSEgVj&amp;orderType=newOn_desc&pageNo=8#anchor">8</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.3.w4002-932662238.107.HSEgVj&amp;orderType=newOn_desc&pageNo=9#anchor">9</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.3.w4002-932662238.107.HSEgVj&amp;orderType=newOn_desc&pageNo=10#anchor">10</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.3.w4002-932662238.107.HSEgVj&amp;orderType=newOn_desc&pageNo=11#anchor">11</a>
  <a class="J_SearchAsync" href="http://22242.taobao.com/search.htm?mid=w-932662238-0&amp;search=y&amp;spm=a1z10.3.w4002-932662238.107.HSEgVj&amp;orderType=newOn_desc&pageNo=12#anchor">12</a>
  <a class="page-cur">13</a>
  <a class="disable">下一页</a>
  <form action="http://22242.taobao.com/search.htm" method="get">
    <input type="hidden" name="mid" value="w-932662238-0">
    <input type="hidden" name="search" value="y">
    <input type="hidden" name="spm" value="a1z10.3.w4002-932662238.107.HSEgVj">
    <input type="hidden" name="orderType" value="newOn_desc">
    到第 <input type="text" value="13" size="3" name="pageNo"> 页
    <button type="submit">确定</button>
  </form>
  <!--END OF  pagination-->
</div>
"""

taobao = require './taobao_fetch.js'
assert = require('chai').assert

describe 'taobao_fetch', () ->
    describe.skip '#requestHtmlContent()', () ->
        it 'should return html content correctly', (done) ->
            taobao.requestHtmlContent 'http://www.baidu.com', (err, result) ->
                if err
                    throw err
                else
                    assert.isTrue result.indexOf('百度一下，你就知道') isnt -1
                    done()
    describe '#extractItemsFromContent()', (content) ->
        it 'should return a list of items', () ->
            items = taobao.extractItemsFromContent """
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

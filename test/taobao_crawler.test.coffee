assert = require('chai').assert
sinon = require 'sinon'
crawler = require('crawler').Crawler
database = require './database'
taobao_crawler = require './taobao_crawler'
memwatch = require 'memwatch'

databaseStub = sinon.createStubInstance database
taobao_crawler.setDatabase databaseStub

newCrawler = new crawler
sinon.stub newCrawler, 'queue', (options) ->
  options[0]['callback'] null, {
    body: CATS_TREE_HTML
    uri: 'http://shop65626141.taobao.com##Aok自治区##1##减半'
  }
taobao_crawler.setCrawler newCrawler

memwatch.on 'leak', (info) ->
  console.log info

describe 'taobao_crawler', () ->
  describe '#crawlStore', () ->
    it 'should crawl category content and items on the first page of each categories', (done) ->
      store =
        store_id: '1'
        store_name: 'Aok自治区'
        shop_http: 'http://shop65626141.taobao.com'
        see_price: '减半'
      taobao_crawler.crawlStore store, () ->
        assert.isTrue databaseStub.updateStoreCateContent.calledWith('1', 'Aok自治区')
        assert.isTrue databaseStub.saveItems.calledWith('1', 'Aok自治区')
        done()


CATS_TREE_HTML = '''
<ul class="J_TCatsTree cats-tree J_TWidget">
  <li class="cat fst-cat float">
    <h4 class="cat-hd fst-cat-hd">
      <i class="cat-icon fst-cat-icon acrd-trigger active-trigger"></i>
      <a href="http://shop65626141.taobao.com/category.htm?search=y" class="cat-name fst-cat-name" title="查看所有宝贝">查看所有宝贝</a>
    </h4>
    <ul class="fst-cat-bd">
      <a href="http://shop65626141.taobao.com/search.htm?search=y&orderType=hotsell_desc" class="cat-name" title="按销量">按销量</a>
      <a href="http://shop65626141.taobao.com/search.htm?search=y&orderType=newOn_desc" class="cat-name" title="按新品">按新品</a>
      <a href="http://shop65626141.taobao.com/search.htm?search=y&orderType=price_asc" class="cat-name" title="按价格">按价格</a>
      <a href="http://shop65626141.taobao.com/search.htm?search=y&orderType=hotkeep_desc" class="cat-name" title="按收藏">按收藏</a>
    </ul>
  </li>

  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="858663529">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-858663529.htm?search=y&catName=30%D4%AA--45%D4%AA%CC%D8%BC%DB%C7%F8%A3%A8%C2%ED%C4%EA%B4%BA%CF%C4%BF%EE%A3%A9#bd"
         >30元--45元特价区（马年春夏款）</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="858663530">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-858663530.htm?search=y&catName=5%D4%AA--25%D4%AA%CC%D8%BC%DB%C7%F8%A3%A8%C2%ED%C4%EA%B4%BA%CF%C4%BF%EE%A3%A9#bd"
         >5元--25元特价区（马年春夏款）</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757163049">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757163049.htm?search=y&catName=%BA%AB%B0%E6%D0%DD%CF%D0%CA%B1%D7%B0#bd"
         >韩版休闲时装</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159783">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159783.htm?search=y&catName=%C3%F1%D7%E5%B7%E7#bd"
         >民族风</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159784">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159784.htm?search=y&categoryp=50000671&scid=757159784#bd"
         >T恤</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159785">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159785.htm?search=y&categoryp=50010850&scid=757159785#bd"
         >连衣裙</a>
    </h4>
  </li>
  <li class="cat fst-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159786">
      <!-- 有子类目的一级类目 ,且展开 class="cat-icon acrd-trigger"， 其中acrd-trigger 是手风琴效果的triggerCls-->
      <i class="cat-icon fst-cat-icon acrd-trigger "></i><a
                                                            class="cat-name fst-cat-name"
                                                            href="http://shop65626141.taobao.com/category-757159786.htm?search=y&categoryp=1622&scid=757159786#bd"
                                                            >裤子</a>

    </h4>
    <ul  style="display: none;"  class="fst-cat-bd">
      <li class="cat snd-cat  ">
        <h4 class="cat-hd snd-cat-hd" data-cat-id="757159787">
          <i class="cat-icon snd-cat-icon"></i><a class="cat-name snd-cat-name"
                                                  href="http://shop65626141.taobao.com/category-757159787.htm?search=y&categoryp=162201&scid=757159787#bd"
                                                  >休闲裤</a>
        </h4>
      </li>
      <li class="cat snd-cat  ">
        <h4 class="cat-hd snd-cat-hd" data-cat-id="757159788">
          <i class="cat-icon snd-cat-icon"></i><a class="cat-name snd-cat-name"
                                                  href="http://shop65626141.taobao.com/category-757159788.htm?search=y&categoryp=50007068&scid=757159788#bd"
                                                  >打底裤</a>
        </h4>
      </li>
    </ul>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159789">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159789.htm?search=y&categoryp=162116&scid=757159789#bd"
         >蕾丝衫/雪纺衫</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159790">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159790.htm?search=y&categoryp=1623&scid=757159790#bd"
         >半身裙</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159791">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159791.htm?search=y&categoryp=162205&scid=757159791#bd"
         >牛仔裤</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159792">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159792.htm?search=y&categoryp=50008898&scid=757159792#bd"
         >卫衣/绒衫</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159793">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159793.htm?search=y&categoryp=162104&scid=757159793#bd"
         >衬衫</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159794">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159794.htm?search=y&categoryp=162103&scid=757159794#bd"
         >毛衣</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159795">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159795.htm?search=y&categoryp=121412004&scid=757159795#bd"
         >小背心/小吊带</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159796">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159796.htm?search=y&categoryp=50013194&scid=757159796#bd"
         >毛呢外套</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159797">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159797.htm?search=y&categoryp=50000697&scid=757159797#bd"
         >毛针织衫</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159798">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159798.htm?search=y&categoryp=50008899&scid=757159798#bd"
         >羽绒服</a>
    </h4>
  </li>
  <li class="cat fst-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159799">
      <!-- 有子类目的一级类目 ,且展开 class="cat-icon acrd-trigger"， 其中acrd-trigger 是手风琴效果的triggerCls-->
      <i class="cat-icon fst-cat-icon acrd-trigger "></i><a
                                                            class="cat-name fst-cat-name"
                                                            href="http://shop65626141.taobao.com/category-757159799.htm?search=y&categoryp=1624&scid=757159799#bd"
                                                            >职业套装/学生校服/工作制服</a>

    </h4>
    <ul  style="display: none;"  class="fst-cat-bd">
      <li class="cat snd-cat  ">
        <h4 class="cat-hd snd-cat-hd" data-cat-id="757159800">
          <i class="cat-icon snd-cat-icon"></i><a class="cat-name snd-cat-name"
                                                  href="http://shop65626141.taobao.com/category-757159800.htm?search=y&categoryp=162404&scid=757159800#bd"
                                                  >休闲套装</a>
        </h4>
      </li>
    </ul>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159901">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159901.htm?search=y&categoryp=50011277&scid=757159901#bd"
         >短外套</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159902">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159902.htm?search=y&categoryp=50008901&scid=757159902#bd"
         >风衣</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159903">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159903.htm?search=y&categoryp=50009032&scid=757159903#bd"
         >腰带/皮带/腰链</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159904">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159904.htm?search=y&categoryp=50008904&scid=757159904#bd"
         >皮衣</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159905">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159905.htm?search=y&categoryp=50008900&scid=757159905#bd"
         >棉衣/棉服</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159906">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159906.htm?search=y&categoryp=50010410&scid=757159906#bd"
         >手套</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159907">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159907.htm?search=y&categoryp=50007003&scid=757159907#bd"
         >围巾/丝巾/披肩</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159908">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="http://shop65626141.taobao.com/category-757159908.htm?search=y&categoryp=50009037&scid=757159908#bd"
         >耳套</a>
    </h4>
  </li>
</ul>

<dl class="item " data-id="22714980919">
  <dt class="photo">
    <a href="http://item.taobao.com/item.htm?id=22714980919" target="_blank">
      <img alt="厂家直销 绣花撞色大码打底衫插肩袖修身百搭短袖T恤 6352# 实拍"  data-ks-lazyload="http://img01.taobaocdn.com/bao/uploaded/i4/10627019728583498/T14U72XjhjXXXXXXXX_!!0-item_pic.jpg_240x240.jpg" src="http://a.tbcdn.cn/s.gif"  >
    </a>
  </dt>
  <dd class="detail">
    <a class="item-name" href="http://item.taobao.com/item.htm?id=22714980919" target="_blank">厂家直销 绣花撞色大码打底衫插肩袖修身百搭短袖T恤 6352# 实拍</a>
    <div class="attribute">
      <div class="cprice-area"><span class="symbol">&yen;</span><span class="c-price">60.00 </span></div>
      <div class="sale-area">已售：<span class="sale-num">7</span>件</div>
    </div>
  </dd>
  <dd class="rates">
    <div class="title">
      <h4>
        评论(<a href="http://item.taobao.com/item.htm?id=22714980919&on_comment=1" target="_blank"><span>0</span></a>)
      </h4>
    </div>
    <p class="rate J_TRate"></p>
  </dd>
</dl>
'''

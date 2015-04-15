http = require 'http'
assert = require('chai').assert
sinon = require 'sinon'
crawler = require('crawler').Crawler
env = require('jsdom').env
jquery = require 'jquery'
database = require '../src/database'
taobao_crawler = require '../src/taobao_crawler'
memwatch = require 'memwatch'

newCrawler = null
databaseStub = null
originMakeUriWithStoreInfo = taobao_crawler.makeUriWithStoreInfo

memwatch.on 'leak', (info) ->
  console.log info

http.createServer((req, res) ->
  res.end 'ok'
).listen 9744

describe 'taobao_crawler', () ->
  beforeEach () ->
    newCrawler = new crawler
    taobao_crawler.setCrawler newCrawler
    databaseStub = sinon.createStubInstance database
    taobao_crawler.setDatabase databaseStub
    taobao_crawler.setMakeUriWithStoreInfo originMakeUriWithStoreInfo

  describe '#crawlStore', () ->
    stubCrawler = (htmlContent) ->
      sinon.stub newCrawler, 'queue', (options) ->
        options[0]['callback'] null, {
          body: htmlContent
          uri: 'http://shop_url##store_name##store_id##see_price'
        }
      taobao_crawler.setCrawler newCrawler
    store =
        store_id: 'store_id'
        store_name: 'store_name'
        shop_http: 'http://shop_url'
        see_price: 'see_price'
    mockDbOperationWithStoreArgs = (s) ->
      (result, callback) ->
        assert.equal s, store
        callback null, result
    taobao_crawler.setClearCids mockDbOperationWithStoreArgs
    taobao_crawler.setDeleteDelistItems mockDbOperationWithStoreArgs
    it 'should crawl category content and all category uris', (done) ->
      stubCrawler CATS_TREE_HTML_TEMPLATE_A
      taobao_crawler.setCrawlAllPagesOfAllCates (uris, callback) ->
        assert.include uris, 'http://shop65626141.taobao.com/category-757159791.htm?search=y&categoryp=162205&scid=757159791&viewType=grid##store_name##store_id##see_price'
        callback null, null
      taobao_crawler.crawlStore store, ->
        assert.isTrue databaseStub.updateStoreCateContent.calledWith('store_id', 'store_name')
        assert.isTrue databaseStub.updateImWw.calledWith('store_id', 'store_name')
        done()
    it 'should crawl items from newOn_desc when cats tree is empty', (done) ->
      stubCrawler CATS_TREE_WITHOUT_CATS_HTML
      taobao_crawler.setCrawlAllPagesOfAllCates (uris, callback) ->
        assert.deepEqual uris, ['http://384007168.taobao.com/search.htm?search=y&orderType=newOn_desc&viewType=grid##store_name##store_id##see_price']
        callback null, null
      taobao_crawler.crawlStore store, ->
        done()

  describe '#crawlAllPagesOfAllCates', ->
    it.skip 'should callback when all uris are handled', (done) ->
      sinon.stub newCrawler, 'queue', (options) ->
        process.nextTick ->
          options[0]['callback'](null, {uri:'http://shop109065161.taobao.com/search.htm?mid=w-6309713619-0&search=y&spm=a1z10.1.0.0.PLAAVw&orderType=hotsell_desc&pageNo=2#anchor##any_store_name##any_store_id##any_see_price', body:'<div>123</div>'})
      taobao_crawler.setCrawler newCrawler
      databaseStub.saveItems = (a, b, c, d, e, callback) ->
        process.nextTick ->
          callback null, null
      taobao_crawler.crawlAllPagesOfAllCates ['http://localhost:9744/', 'http://localhost:9744/'], ->
        done()

  describe '#saveItemsFromPageAndQueueNext', ->
    it.skip 'should queue next page uri', (done) ->
      sinon.stub newCrawler, 'queue', (options) ->
        assert.equal options[0]['uri'], 'http://shop109065161.taobao.com/search.htm?mid=w-6309713619-0&search=y&spm=a1z10.1.0.0.PLAAVw&orderType=hotsell_desc&pageNo=2#anchor##any_store_name##any_store_id##any_see_price'
        done()
      taobao_crawler.setCrawler newCrawler
      taobao_crawler.saveItemsFromPageAndQueueNext(->
      )(null,
        uri: 'any_uri##any_store_name##any_store_id##any_see_price'
        body: PAGINATION_HTML)
    it 'should do not call db function when item not found', (done) ->
      oldChangeRemains = taobao_crawler.changeRemains
      changeRemains = (action, callback) ->
        callback()
      taobao_crawler.setChangeRemains changeRemains
      taobao_crawler.saveItemsFromPageAndQueueNext(->
        assert.isTrue databaseStub.saveItems.neverCalledWith()
        taobao_crawler.setChangeRemains oldChangeRemains
        done()
      )(null,
        uri: 'any_uri##any_store_name##any_store_id##any_see_price'
        body: '<p class="item-not-found"></p>')

  describe '#extractUris', ->
    beforeEach ->
      taobao_crawler.setMakeUriWithStoreInfo (uri, store) ->
        uri
    expectUrisInclude = (html, expectedArray..., done) ->
      env html, (errors, window) ->
        $ = jquery window
        uris = taobao_crawler.extractUris $, null
        assert.include uris, expected for expected in expectedArray
        done()
    it 'should return uris from template A', (done) ->
      expectUrisInclude CATS_TREE_HTML_TEMPLATE_A, '//shop65626141.taobao.com/category-858663529.htm?search=y&catName=30%D4%AA--45%D4%AA%CC%D8%BC%DB%C7%F8%A3%A8%C2%ED%C4%EA%B4%BA%CF%C4%BF%EE%A3%A9&viewType=grid', '//shop65626141.taobao.com/category-757163049.htm?search=y&catName=%BA%AB%B0%E6%D0%DD%CF%D0%CA%B1%D7%B0&viewType=grid', done
    it 'should return uris from template B', (done) ->
      expectUrisInclude CATS_TREE_HTML_TEMPLATE_B, '//shop68788405.taobao.com/search.htm?orderType=newOn_desc&viewType=grid', done

  describe '#extractImWw', ->
    it 'should return im_ww from uri', (done) ->
      env '<span class="J_WangWang wangwang"  data-nick="kasanio" data-tnick="kasanio" data-encode="true" data-display="inline"></span>', (errors, window) ->
        $ = jquery window
        assert.equal taobao_crawler.extractImWw($), 'kasanio'
        done()

  describe '#extractCatsTreeHtml', ->
    expectCatsTreeHtmlInclude = (html, expected, done) ->
      env html, (errors, window) ->
        $ = jquery window
        html = taobao_crawler.extractCatsTreeHtml $,
          store_id: 'store_id'
        assert.include html, expected
        done()
    it 'should return cats tree html from template A', (done) ->
      expectCatsTreeHtmlInclude CATS_TREE_HTML_TEMPLATE_A, '蕾丝衫/雪纺衫', done
    it 'should return cats tree html from template B', (done) ->
      expectCatsTreeHtmlInclude CATS_TREE_HTML_TEMPLATE_B, '按新品', done
    it 'should replace cat urls with local urls 1', (done) ->
      expectCatsTreeHtmlInclude CATS_TREE_HTML_TEMPLATE_A, 'showCat.php?cid=858663529', done
    it 'should replace cat urls with local urls 2', (done) ->
      expectCatsTreeHtmlInclude CATS_TREE_HTML_TEMPLATE_A, 'showCat.php?cid=757163049', done

  describe '#extractItemsFromContent', ->
    expectItemsFromHtml = (html, seePrice, expected, done) ->
      env html, (errors, window) ->
        $ = jquery window
        items = taobao_crawler.extractItemsFromContent $, {see_price: seePrice}
        assert.deepEqual items, expected
        done()
    it 'should return items array from html template A', (done) ->
      expectItemsFromHtml ITEMS_HTML_TEMPLATE_A, '减10', [
        goodsName: '865# 2014秋冬 新品拼皮百搭显瘦女呢料短裤（送腰带）'
        defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i2/T1Xy3SFXliXXXXXXXX_!!0-item_pic.jpg_240x240.jpg'
        price: '30'
        goodHttp: 'http://item.taobao.com/item.htm?id=40890292076'
      ,
        goodsName: '867# 2014秋冬新品韩版显瘦蕾丝花边拼接短裤百搭呢料短裤热裤'
        defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i2/TB1ap8wGXXXXXbXXVXXXXXXXXXX_!!0-item_pic.jpg_240x240.jpg'
        price: '30'
        goodHttp: 'http://item.taobao.com/item.htm?id=40889940937'
      ], done
    it 'should return items array from html template B', (done) ->
      expectItemsFromHtml ITEMS_HTML_TEMPLATE_B, '减半', [
        goodsName: '#6801#现货4码3色小清新必备学院派彩色时尚拼色长袖卫衣'
        defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i4/T1HXpZFk4iXXXXXXXX_!!0-item_pic.jpg_160x160.jpg'
        price: '18'
        goodHttp: 'http://item.taobao.com/item.htm?id=41324376021&'
      ,
        goodsName: '实拍#8821#棒球服女 韩版潮情侣装棒球衫开衫卫衣女学生外套班服'
        defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i2/TB1xHOkGXXXXXX0XFXXXXXXXXXX_!!0-item_pic.jpg_160x160.jpg'
        price: '34'
        goodHttp: 'http://item.taobao.com/item.htm?id=41083856074&'
      ], done

  describe '#parsePrice', ->
    it 'should return half when see_price is 减半', ->
      assert.equal taobao_crawler.parsePrice('50.4', '减半'), 25.20
    it 'should return raw price when see_price is 三折', ->
      assert.equal taobao_crawler.parsePrice('50.5', '三折'), 50.50
    it 'should return raw price when see_price is 打三折', ->
      assert.equal taobao_crawler.parsePrice('50.5', '打三折'), 50.50
    it 'should return price * 0.2 when see_price is 2折', ->
      assert.equal taobao_crawler.parsePrice('50.4', '2折'), 10.08
    it 'should return price * 0.2 when see_price is 打2折', ->
      assert.equal taobao_crawler.parsePrice('50.4', '打2折'), 10.08
    it 'should return price in goods name when see_price is P', ->
      assert.equal taobao_crawler.parsePrice('111', 'P', '我是一个任意宝贝 P22'), 22
      assert.equal taobao_crawler.parsePrice('111', 'P', '我是一个任意宝贝 P33.3xxx'), 33.3
      assert.equal taobao_crawler.parsePrice('111', 'P', '我是一个任意宝贝 p22'), 22
      assert.equal taobao_crawler.parsePrice('111', 'P', '我是一个任意宝贝 F33'), 33
      assert.equal taobao_crawler.parsePrice('111', 'P', '我是一个任意宝贝 f33'), 33
      assert.equal taobao_crawler.parsePrice('111', 'P', '我是一个任意宝贝318/F06/P175'), 175
    it 'should return price in goods name when see_price is 减P', ->
      assert.equal taobao_crawler.parsePrice('111', '减P', '我是一个任意宝贝318/F06/P175'), 175
      assert.equal taobao_crawler.parsePrice('111', '减p', '我是一个任意宝贝 F33'), 33

  describe '#formatPrice', ->
    it 'should return formatted price', ->
      assert.equal taobao_crawler.formatPrice(12.00), '12'

  describe '#getNumIidFromUri', ->
    it 'should return 41033455520', ->
      assert.equal taobao_crawler.getNumIidFromUri('http://item.taobao.com/item.htm?spm=a1z10.1.w4004-5944377767.2.iS5MoU&id=41033455520'), '41033455520'
      assert.equal taobao_crawler.getNumIidFromUri('http://item.taobao.com/item.htm?id=41033455520&spm=a1z10.1.w4004-5944377767.2.iS5MoU'), '41033455520'

  describe '#parseSkus', ->
    it 'should return skus array', ->
      assert.deepEqual taobao_crawler.parseSkus(
        sku: [
          {properties_name: '1627207:3232484:颜色分类:天蓝色;20509:28314:尺码:S'},
          {properties_name: '1627207:3232484:颜色分类:天蓝色;20509:28317:尺码:XL'},
          {properties_name: '1627207:3232481:颜色分类:巧克力色;20509:28316:尺码:L'},
        ]
      ), [
        [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
        ,
          pid: '20509'
          vid: '28314'
          name: '尺码'
          value: 'S'
        ], [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
        ,
          pid: '20509'
          vid: '28317'
          name: '尺码'
          value: 'XL'
        ], [
          pid: '1627207'
          vid: '3232481'
          name: '颜色分类'
          value: '巧克力色'
        ,
          pid: '20509'
          vid: '28316'
          name: '尺码'
          value: 'L'
        ]
      ]
    it 'should return skus array with alias', ->
      assert.deepEqual taobao_crawler.parseSkus(
        sku: [
          {properties_name: '1627207:3232484:颜色分类:天蓝色;20509:28314:尺码:S'},
        ]
      , '20509:28314:S(XS)'), [
        [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
        ,
          pid: '20509'
          vid: '28314'
          name: '尺码'
          value: 'S(XS)'
        ]
      ]

  describe '#parseAttrs', ->
    it 'should return attributes array', ->
      assert.deepEqual taobao_crawler.parseAttrs('20418023:157305307:主图来源:自主实拍图;13021751:3381429:货号:858#;20608:6384766:风格:通勤'), [{
        attrId: '20418023'
        valueId: '157305307'
        attrName: '主图来源'
        attrValue: '自主实拍图'
      },{
        attrId: '13021751'
        valueId: '3381429'
        attrName: '货号'
        attrValue: '858#'
      }, {
        attrId: '20608'
        valueId: '6384766'
        attrName: '风格'
        attrValue: '通勤'
      }]
    it 'should return attributes array with alias', ->
      assert.deepEqual taobao_crawler.parseAttrs('20418023:157305307:主图来源:自主实拍图;13021751:3381429:货号:858#;20608:6384766:风格:通勤', '20608:6384766:不是通勤'), [{
        attrId: '20418023'
        valueId: '157305307'
        attrName: '主图来源'
        attrValue: '自主实拍图'
      },{
        attrId: '13021751'
        valueId: '3381429'
        attrName: '货号'
        attrValue: '858#'
      }, {
        attrId: '20608'
        valueId: '6384766'
        attrName: '风格'
        attrValue: '不是通勤'
      }]

  describe '#removeSingleQuotes', ->
    it 'should remove all single quotes in given string', ->
      assert.equal taobao_crawler.removeSingleQuotes("abcdefg'hi jklmn'opq rst'uvwxyz"), "abcdefghi jklmnopq rstuvwxyz"

  describe '#makeOuterId', ->
    it 'should return outer id', ->
      assert.equal taobao_crawler.makeOuterId(
        'shop_mall': 'mall'
        'address': 'address'
      , '705', 15), 'malladdress_P15_705#'

  describe '#getHuoHao', ->
    it 'should return huo hao', ->
      assert.equal taobao_crawler.getHuoHao('705#title'), 705
      assert.equal taobao_crawler.getHuoHao('title705'), 705
      assert.equal taobao_crawler.getHuoHao('2014title705'), 705
      assert.equal taobao_crawler.getHuoHao('title'), ''

  describe '#filterItems', ->
    it 'should return filtered items', ->
      assert.deepEqual taobao_crawler.filterItems([
        goodsName: undefined
        defaultImage: undefined
        price: undefined
        goodHttp: undefined
      ,
        goodsName: 'goods name'
        defaultImage: 'default image'
        price: '40.00'
        goodHttp: 'uri'
      ,
        goodsName: ''
        defaultImage: 'default image'
        price: '40.00'
        goodHttp: 'uri'
      ]), [
        goodsName: 'goods name'
        defaultImage: 'default image'
        price: '40.00'
        goodHttp: 'uri'
      ]

  describe '#isRealPic', ->
    it 'should return 1 if title contains "实拍"', ->
      assert.equal taobao_crawler.isRealPic('宝贝标题含有实拍', ''), 1
    it 'should return 1 if props name contains "157305307"', ->
      assert.equal taobao_crawler.isRealPic('', '1:2:3;1:157305307:3'), 1
    it 'should return 0 if cannot find "实拍" in title or "157305307" in props name', ->
      assert.equal taobao_crawler.isRealPic('', ''), 0

  describe '#getPropertyAlias', ->
    it 'should return alias', ->
      assert.equal taobao_crawler.getPropertyAlias('1627207:3232483:粉色;1627207:3232484:绿色', '3232483', '白色'), '粉色'
      assert.equal taobao_crawler.getPropertyAlias('1627207:3232483:粉色;1627207:3232484:绿色', '3232484', '白色'), '绿色'
    it 'should return origin value', ->
      assert.equal taobao_crawler.getPropertyAlias('1627207:3232483:粉色;1627207:3232484:绿色', '3232485', '白色'), '白色'

CATS_TREE_HTML_TEMPLATE_A = '''
<span class="J_WangWang wangwang"  data-nick="kasanio" data-tnick="kasanio" data-encode="true" data-display="inline"></span>
<div>
<ul class="J_TCatsTree cats-tree J_TWidget">
  <li class="cat fst-cat float">
    <h4 class="cat-hd fst-cat-hd">
      <i class="cat-icon fst-cat-icon acrd-trigger active-trigger"></i>
      <a href="//shop65626141.taobao.com/category.htm?search=y" class="cat-name fst-cat-name" title="查看所有宝贝">查看所有宝贝</a>
    </h4>
    <ul class="fst-cat-bd">
      <a href="//shop65626141.taobao.com/search.htm?search=y&orderType=hotsell_desc" class="cat-name" title="按销量">按销量</a>
      <a href="//shop65626141.taobao.com/search.htm?search=y&orderType=newOn_desc" class="cat-name" title="按新品">按新品</a>
      <a href="//shop65626141.taobao.com/search.htm?search=y&orderType=price_asc" class="cat-name" title="按价格">按价格</a>
      <a href="//shop65626141.taobao.com/search.htm?search=y&orderType=hotkeep_desc" class="cat-name" title="按收藏">按收藏</a>
    </ul>
  </li>

  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="858663529">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-858663529.htm?search=y&catName=30%D4%AA--45%D4%AA%CC%D8%BC%DB%C7%F8%A3%A8%C2%ED%C4%EA%B4%BA%CF%C4%BF%EE%A3%A9#bd"
         >30元--45元特价区（马年春夏款）</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="858663530">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-858663530.htm?search=y&catName=5%D4%AA--25%D4%AA%CC%D8%BC%DB%C7%F8%A3%A8%C2%ED%C4%EA%B4%BA%CF%C4%BF%EE%A3%A9#bd"
         >5元--25元特价区（马年春夏款）</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757163049">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757163049.htm?search=y&catName=%BA%AB%B0%E6%D0%DD%CF%D0%CA%B1%D7%B0#bd"
         >韩版休闲时装</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159783">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159783.htm?search=y&catName=%C3%F1%D7%E5%B7%E7#bd"
         >民族风</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159784">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159784.htm?search=y&categoryp=50000671&scid=757159784#bd"
         >T恤</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159785">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159785.htm?search=y&categoryp=50010850&scid=757159785#bd"
         >连衣裙</a>
    </h4>
  </li>
  <li class="cat fst-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159786">
      <!-- 有子类目的一级类目 ,且展开 class="cat-icon acrd-trigger"， 其中acrd-trigger 是手风琴效果的triggerCls-->
      <i class="cat-icon fst-cat-icon acrd-trigger "></i><a
                                                            class="cat-name fst-cat-name"
                                                            href="//shop65626141.taobao.com/category-757159786.htm?search=y&categoryp=1622&scid=757159786#bd"
                                                            >裤子</a>

    </h4>
    <ul  style="display: none;"  class="fst-cat-bd">
      <li class="cat snd-cat  ">
        <h4 class="cat-hd snd-cat-hd" data-cat-id="757159787">
          <i class="cat-icon snd-cat-icon"></i><a class="cat-name snd-cat-name"
                                                  href="//shop65626141.taobao.com/category-757159787.htm?search=y&categoryp=162201&scid=757159787#bd"
                                                  >休闲裤</a>
        </h4>
      </li>
      <li class="cat snd-cat  ">
        <h4 class="cat-hd snd-cat-hd" data-cat-id="757159788">
          <i class="cat-icon snd-cat-icon"></i><a class="cat-name snd-cat-name"
                                                  href="//shop65626141.taobao.com/category-757159788.htm?search=y&categoryp=50007068&scid=757159788#bd"
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
         href="//shop65626141.taobao.com/category-757159789.htm?search=y&categoryp=162116&scid=757159789#bd"
         >蕾丝衫/雪纺衫</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159790">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159790.htm?search=y&categoryp=1623&scid=757159790#bd"
         >半身裙</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159791">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159791.htm?search=y&categoryp=162205&scid=757159791#bd"
         >牛仔裤</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159792">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159792.htm?search=y&categoryp=50008898&scid=757159792#bd"
         >卫衣/绒衫</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159793">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159793.htm?search=y&categoryp=162104&scid=757159793#bd"
         >衬衫</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159794">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159794.htm?search=y&categoryp=162103&scid=757159794#bd"
         >毛衣</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159795">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159795.htm?search=y&categoryp=121412004&scid=757159795#bd"
         >小背心/小吊带</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159796">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159796.htm?search=y&categoryp=50013194&scid=757159796#bd"
         >毛呢外套</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159797">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159797.htm?search=y&categoryp=50000697&scid=757159797#bd"
         >毛针织衫</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159798">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159798.htm?search=y&categoryp=50008899&scid=757159798#bd"
         >羽绒服</a>
    </h4>
  </li>
  <li class="cat fst-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159799">
      <!-- 有子类目的一级类目 ,且展开 class="cat-icon acrd-trigger"， 其中acrd-trigger 是手风琴效果的triggerCls-->
      <i class="cat-icon fst-cat-icon acrd-trigger "></i><a
                                                            class="cat-name fst-cat-name"
                                                            href="//shop65626141.taobao.com/category-757159799.htm?search=y&categoryp=1624&scid=757159799#bd"
                                                            >职业套装/学生校服/工作制服</a>

    </h4>
    <ul  style="display: none;"  class="fst-cat-bd">
      <li class="cat snd-cat  ">
        <h4 class="cat-hd snd-cat-hd" data-cat-id="757159800">
          <i class="cat-icon snd-cat-icon"></i><a class="cat-name snd-cat-name"
                                                  href="//shop65626141.taobao.com/category-757159800.htm?search=y&categoryp=162404&scid=757159800#bd"
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
         href="//shop65626141.taobao.com/category-757159901.htm?search=y&categoryp=50011277&scid=757159901#bd"
         >短外套</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159902">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159902.htm?search=y&categoryp=50008901&scid=757159902#bd"
         >风衣</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159903">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159903.htm?search=y&categoryp=50009032&scid=757159903#bd"
         >腰带/皮带/腰链</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159904">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159904.htm?search=y&categoryp=50008904&scid=757159904#bd"
         >皮衣</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159905">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159905.htm?search=y&categoryp=50008900&scid=757159905#bd"
         >棉衣/棉服</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159906">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159906.htm?search=y&categoryp=50010410&scid=757159906#bd"
         >手套</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159907">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159907.htm?search=y&categoryp=50007003&scid=757159907#bd"
         >围巾/丝巾/披肩</a>
    </h4>
  </li>
  <li class="cat fst-cat no-sub-cat ">
    <h4 class="cat-hd fst-cat-hd" data-cat-id="757159908">
      <!-- 一级叶子类目 ,class="cat-icon"-->
      <i class="cat-icon fst-cat-icon"></i>
      <a class="cat-name fst-cat-name"
         href="//shop65626141.taobao.com/category-757159908.htm?search=y&categoryp=50009037&scid=757159908#bd"
         >耳套</a>
    </h4>
  </li>
</ul>

<dl class="item " data-id="22714980919">
  <dt class="photo">
    <a href="//item.taobao.com/item.htm?id=22714980919" target="_blank">
      <img alt="厂家直销 绣花撞色大码打底衫插肩袖修身百搭短袖T恤 6352# 实拍"  data-ks-lazyload="//img01.taobaocdn.com/bao/uploaded/i4/10627019728583498/T14U72XjhjXXXXXXXX_!!0-item_pic.jpg_240x240.jpg" src="//a.tbcdn.cn/s.gif"  >
    </a>
  </dt>
  <dd class="detail">
    <a class="item-name" href="//item.taobao.com/item.htm?id=22714980919" target="_blank">厂家直销 绣花撞色大码打底衫插肩袖修身百搭短袖T恤 6352# 实拍</a>
    <div class="attribute">
      <div class="cprice-area"><span class="symbol">&yen;</span><span class="c-price">60.00 </span></div>
      <div class="sale-area">已售：<span class="sale-num">7</span>件</div>
    </div>
  </dd>
  <dd class="rates">
    <div class="title">
      <h4>
        评论(<a href="//item.taobao.com/item.htm?id=22714980919&on_comment=1" target="_blank"><span>0</span></a>)
      </h4>
    </div>
    <p class="rate J_TRate"></p>
  </dd>
</dl>
</div>
'''

CATS_TREE_HTML_TEMPLATE_B = '''
<div class="bd">
  <ul id="J_Cats" class="cats J_TWidget" data-widget-type="Accordion" data-widget-config="{'triggerCls': 'cat-hd', 'panelCls': 'cat-bd','multiple': 'true', 'activeTriggerCls': 'collapse'}">
    <li class="cat J_CatHeader">
    <h4><i></i><a rel="shopCategoryList" href='//shop68788405.taobao.com/search.htm'>查看所有宝贝>></a></h4>
    <a rel="shopCategoryList" href="//shop68788405.taobao.com/search.htm?orderType=hotsell_desc" rel="nofollow" >按销量</a>
    <a rel="shopCategoryList" href="//shop68788405.taobao.com/search.htm?orderType=newOn_desc" rel="nofollow" >按新品</a>
    <a rel="shopCategoryList" href="//shop68788405.taobao.com/search.htm?orderType=price" rel="nofollow" >按价格</a>
    <a rel="shopCategoryList" href="//shop68788405.taobao.com/search.htm?orderType=hotkeep_desc" rel="nofollow" >按收藏</a>
  </li>
  </ul>
</div>
'''

DESC = '''
<p><img align="absmiddle" src="http://img01.taobaocdn.com/imgextra/i1/681970627/T2AVsbXxtXXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img04.taobaocdn.com/imgextra/i4/681970627/T2vcEXXspaXXXXXXXX_!!681970627.jpg">这条是真心爱啊 &nbsp; &nbsp;拿来自己穿的</p><div>&nbsp;</div><div>不过想想还是跟大家分享一下吧 &nbsp;</div><div>&nbsp;</div><div>裤型很有范 &nbsp; &nbsp; 小哈伦的 &nbsp; &nbsp;民族风 &nbsp; &nbsp; 慵懒调调</div><div>&nbsp;</div><div>单个色感觉很棒 &nbsp; &nbsp;都是我的菜</div><div>&nbsp;</div><div>&nbsp; &nbsp; &nbsp; 提醒各位买家注意看一下我标的实测尺寸 &nbsp; &nbsp;&nbsp;</div><div>&nbsp;</div><div>&nbsp; &nbsp;很值得入手的秋冬潮搭裤子 &nbsp; &nbsp; &nbsp;很喜欢~</div><div>&nbsp;</div><div>裤子不长 &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;请亲们参考阿蒙标出的实测尺寸</div><div>&nbsp;</div><div>&nbsp;</div><div>【尺寸】</div><div>S: 腰围56-70 &nbsp; &nbsp;臀围90 &nbsp; &nbsp; 前裆25 &nbsp; &nbsp; 大腿围50 &nbsp; &nbsp; 小腿围32 &nbsp; &nbsp; 裤脚26 &nbsp; &nbsp; &nbsp;裤长86</div><div>&nbsp;</div><div>M: 腰围60-74 &nbsp; &nbsp;臀围95 &nbsp; &nbsp; 前裆26 &nbsp; &nbsp; 大腿围52 &nbsp; &nbsp; 小腿围34 &nbsp; &nbsp; 裤脚27<span style="white-space: pre;"></span>&nbsp; &nbsp;裤长87</div><div>&nbsp;</div><div>L: 腰围64-78 &nbsp; &nbsp;臀围100 &nbsp; &nbsp;前裆27 &nbsp; &nbsp; 大腿围54 &nbsp; &nbsp; 小腿围36 &nbsp; &nbsp; 裤脚28 &nbsp; &nbsp; &nbsp;裤长88</div><div>&nbsp;</div><div>XL 腰围68-82 &nbsp; &nbsp;臀围105 &nbsp; &nbsp;前裆28 &nbsp; &nbsp; 大腿围56 &nbsp; &nbsp; 小腿围37 &nbsp; &nbsp; 裤脚29 &nbsp; &nbsp; &nbsp;裤长89</div><div>&nbsp;</div><p>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;（所有尺寸平铺手测量 &nbsp; 允许2CM内误差）<img align="absmiddle" src="http://img02.taobaocdn.com/imgextra/i2/681970627/T2_sMcXtJXXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img02.taobaocdn.com/imgextra/i2/681970627/T286ZdXppXXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img02.taobaocdn.com/imgextra/i2/681970627/T2.ln.XuBaXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img01.taobaocdn.com/imgextra/i1/681970627/T2ZDZXXvxXXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img03.taobaocdn.com/imgextra/i3/681970627/T2ri7bXvVXXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img03.taobaocdn.com/imgextra/i3/681970627/T2iJEdXqtXXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img03.taobaocdn.com/imgextra/i3/681970627/T28QsdXpdXXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img01.taobaocdn.com/imgextra/i1/681970627/T22CIcXrRXXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img02.taobaocdn.com/imgextra/i2/681970627/T2EGgXXtpaXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img01.taobaocdn.com/imgextra/i1/681970627/T2ZDZXXvxXXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img03.taobaocdn.com/imgextra/i3/681970627/T2wzEaXxhXXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img01.taobaocdn.com/imgextra/i1/681970627/T2OyEXXrXaXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img02.taobaocdn.com/imgextra/i2/681970627/T2dlUbXvhXXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img01.taobaocdn.com/imgextra/i1/681970627/T2usIaXyXXXXXXXXXX_!!681970627.jpg"><img align="absmiddle" src="http://img03.taobaocdn.com/imgextra/i3/681970627/T2CWUdXqlXXXXXXXXX_!!681970627.jpg"></p>
'''

PAGINATION_HTML = '''
<div class="pagination">
  <a class="disable">上一页</a>
  <a class="page-cur">1</a>
  <a class="J_SearchAsync" href="//shop109065161.taobao.com/search.htm?mid=w-6309713619-0&amp;search=y&amp;spm=a1z10.1.0.0.PLAAVw&amp;orderType=hotsell_desc&amp;pageNo=2#anchor">2</a>
  <a class="J_SearchAsync next" href="//shop109065161.taobao.com/search.htm?mid=w-6309713619-0&amp;search=y&amp;spm=a1z10.1.0.0.PLAAVw&amp;orderType=hotsell_desc&amp;pageNo=2#anchor">下一页</a>
  <form action="//shop109065161.taobao.com/search.htm" method="get">
    <input type="hidden" name="mid" value="w-6309713619-0">
    <input type="hidden" name="search" value="y">
    <input type="hidden" name="spm" value="a1z10.1.0.0.PLAAVw">
    <input type="hidden" name="orderType" value="hotsell_desc">
    到第 <input type="text" value="1" size="3" name="pageNo"> 页
    <button type="submit">确定</button>
  </form>
  <!--END OF  pagination-->
</div>
'''

CATS_TREE_WITHOUT_CATS_HTML = '''
<ul class="J_TAllCatsTree cats-tree">
  <li class="cat fst-cat">
    <h4 class="cat-hd fst-cat-hd has-children">
      <i class="cat-icon fst-cat-icon"></i>
      <a href="//384007168.taobao.com/search.htm?search=y" class="cat-name fst-cat-name">所有宝贝</a>
    </h4>

    <div class="snd-pop">
      <div class="snd-pop-inner">
        <ul class="fst-cat-bd">
          <li class="cat snd-cat">
            <h4 class="cat-hd snd-cat-hd">
              <i class="cat-icon snd-cat-icon"></i>
              <a href="//384007168.taobao.com/search.htm?search=y&orderType=hotsell_desc"
                 class="by-label by-sale snd-cat-name" rel="nofollow" >按销量</a>
            </h4>
            <h4 class="cat-hd snd-cat-hd">
              <i class="cat-icon snd-cat-icon"></i>
              <a href="//384007168.taobao.com/search.htm?search=y&orderType=newOn_desc"
                 class="by-label by-new snd-cat-name" rel="nofollow" >按新品</a>
            </h4>
            <h4 class="cat-hd snd-cat-hd">
              <i class="cat-icon snd-cat-icon"></i>
              <a href="//384007168.taobao.com/search.htm?search=y&orderType=price_asc"
                 class="by-label by-price snd-cat-name" rel="nofollow" >按价格</a>
            </h4>
          </li>
        </ul>
      </div>
    </div>
  </li>
</ul>
'''

ITEMS_HTML_TEMPLATE_A = '''
<div class="shop-hesper-bd grid">
<dl class="item " data-id="40890292076">
  <dt class="photo">
    <a href="//item.taobao.com/item.htm?id=40890292076" target="_blank">
      <img alt="865# 2014秋冬 新品拼皮百搭显瘦女呢料短裤（送腰带）"  src="//img01.taobaocdn.com/bao/uploaded/i2/T1Xy3SFXliXXXXXXXX_!!0-item_pic.jpg_240x240.jpg"  >
    </a>
  </dt>
  <dd class="detail">
    <a class="item-name" href="//item.taobao.com/item.htm?id=40890292076" target="_blank">865# 2014秋冬 新品拼皮百搭显瘦女呢料短裤（送腰带）</a>
    <div class="attribute">
      <div class="cprice-area"><span class="symbol">&yen;</span><span class="c-price">40.00 </span></div>
      <div class="sale-area">已售：<span class="sale-num">0</span>件</div>
    </div>
  </dd>
  <dd class="rates">
    <div class="title">
      <h4>
        评论(<a href="//item.taobao.com/item.htm?id=40890292076&on_comment=1" target="_blank"><span>0</span></a>)
      </h4>
    </div>
    <p class="rate J_TRate"></p>
  </dd>
</dl>

<dl class="item " data-id="40889940937">
  <dt class="photo">
    <a href="//item.taobao.com/item.htm?id=40889940937" target="_blank">
      <img alt="867# 2014秋冬新品韩版显瘦蕾丝花边拼接短裤百搭呢料短裤热裤"  src="//img01.taobaocdn.com/bao/uploaded/i2/TB1ap8wGXXXXXbXXVXXXXXXXXXX_!!0-item_pic.jpg_240x240.jpg"  >
    </a>
  </dt>
  <dd class="detail">
    <a class="item-name" href="//item.taobao.com/item.htm?id=40889940937" target="_blank">867# 2014秋冬新品韩版显瘦蕾丝花边拼接短裤百搭呢料短裤热裤</a>
    <div class="attribute">
      <div class="cprice-area"><span class="symbol">&yen;</span><span class="c-price">40.00 </span></div>
      <div class="sale-area">已售：<span class="sale-num">0</span>件</div>
    </div>
  </dd>
  <dd class="rates">
    <div class="title">
      <h4>
        评论(<a href="//item.taobao.com/item.htm?id=40889940937&on_comment=1" target="_blank"><span>0</span></a>)
      </h4>
    </div>
    <p class="rate J_TRate"></p>
  </dd>
</dl>
</div>
'''

ITEMS_HTML_TEMPLATE_B = '''
<div class="shop-hesper-bd grid">
<div class="item">
  <div class="pic">
    <a href="//item.taobao.com/item.htm?id=41324376021&" target="_blank">
      <img src="//a.tbcdn.cn/s.gif" data-ks-lazyload="//img01.taobaocdn.com/bao/uploaded/i4/T1HXpZFk4iXXXXXXXX_!!0-item_pic.jpg_160x160.jpg" />
    </a>
  </div>
  <div class="desc">
    <a target="_blank" href="//item.taobao.com/item.htm?id=41324376021&" class="permalink" style="">
      #6801#现货4码3色小清新必备学院派彩色时尚拼色长袖卫衣
    </a>
  </div>
  <div class="price">
    <span>
      一口价                            </span>
    <strong>36.00 元</strong>
  </div>
  <div class="sales-amount">
  最近30天售出<em>0</em>件
  </div>
</div>
<div class="item">
  <div class="pic">
    <a href="//item.taobao.com/item.htm?id=41083856074&" target="_blank">
      <img src="//a.tbcdn.cn/s.gif" data-ks-lazyload="//img01.taobaocdn.com/bao/uploaded/i2/TB1xHOkGXXXXXX0XFXXXXXXXXXX_!!0-item_pic.jpg_160x160.jpg" />
    </a>
  </div>
  <div class="desc">
    <a target="_blank" href="//item.taobao.com/item.htm?id=41083856074&" class="permalink" style="">
      实拍#8821#棒球服女 韩版潮情侣装棒球衫开衫卫衣女学生外套班服
    </a>
  </div>
  <div class="price">
    <span>
      一口价                            </span>
    <strong>68.00 元</strong>
  </div>
  <div class="sales-amount">
  最近30天售出<em>0</em>件
  </div>
</div>
</div>
'''

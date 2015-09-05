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
      taobao_crawler.setCrawlAllPagesOfByNew (uris, callback) ->
        callback null, uris
      taobao_crawler.setCrawlAllPagesOfAllCates (uris, callback) ->
        assert.include uris.catesUris, 'http://shop65626141.taobao.com/category-757159791.htm?search=y&categoryp=162205&scid=757159791&viewType=grid##store_name##store_id##see_price'
        callback null, uris
      taobao_crawler.crawlStore store, true, ->
        assert.isTrue databaseStub.updateStoreCateContent.calledWith('store_id', 'store_name')
        assert.isTrue databaseStub.updateImWw.calledWith('store_id', 'store_name')
        done()
    it 'should crawl items from newOn_desc when cats tree is empty', (done) ->
      stubCrawler CATS_TREE_WITHOUT_CATS_HTML
      taobao_crawler.setCrawlAllPagesOfByNew (uris, callback) ->
        assert.deepEqual uris.byNewUris, ['http://384007168.taobao.com/search.htm?search=y&orderType=newOn_desc&viewType=grid##store_name##store_id##see_price']
        callback null, uris
      taobao_crawler.setCrawlAllPagesOfAllCates (uris, callback) ->
        callback null, uris
      taobao_crawler.crawlStore store, true, ->
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
        uris = taobao_crawler.extractUris $, null, true
        uris.catesUris.push uris.byNewUris[0]
        assert.include uris.catesUris, expected for expected in expectedArray
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
          {properties_name: '1627207:3232484:颜色分类:天蓝色;20509:28314:尺码:S', price: '12.00'},
          {properties_name: '1627207:3232484:颜色分类:天蓝色;20509:28317:尺码:XL', price: '22.00'},
          {properties_name: '1627207:3232481:颜色分类:巧克力色;20509:28316:尺码:L', price: '11.00'},
        ]
      , null, '实价', ''
      ), [
        [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
          price: '12'
        ,
          pid: '20509'
          vid: '28314'
          name: '尺码'
          value: 'S'
          price: '12'
        ], [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
          price: '22'
        ,
          pid: '20509'
          vid: '28317'
          name: '尺码'
          value: 'XL'
          price: '22'
        ], [
          pid: '1627207'
          vid: '3232481'
          name: '颜色分类'
          value: '巧克力色'
          price: '11'
        ,
          pid: '20509'
          vid: '28316'
          name: '尺码'
          value: 'L'
          price: '11'
        ]
      ]
    it 'should return skus array with alias', ->
      assert.deepEqual taobao_crawler.parseSkus(
        sku: [
          {properties_name: '1627207:3232484:颜色分类:天蓝色;20509:28314:尺码:S', price: '10.00'},
        ]
      , '20509:28314:S(XS)', '实价', ''), [
        [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
          price: '10'
        ,
          pid: '20509'
          vid: '28314'
          name: '尺码'
          value: 'S(XS)'
          price: '10'
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
      assert.equal taobao_crawler.getHuoHao('title9title705'), 705

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

  describe '#crawlItemsInStore', ->
    it 'should call crawlItemViaApi with goods one by one', (done) ->
      databaseStub.getUnfetchedGoodsInStore = (storeId, callback) ->
        callback null, [{
          goods_id: '1'
          goods_name: 'goods1'
        }, {
          goods_id: '2'
          goods_name: 'goods2'
        }, {
          goods_id: '3'
          goods_name: 'goods3'
        }]
      crawlItemViaApiStub = sinon.stub taobao_crawler, 'crawlItemViaApi', (good, session, callback) ->
        callback()
      taobao_crawler.crawlItemsInStore 0, null, ->
        assert.equal crawlItemViaApiStub.callCount, 3
        assert.isTrue crawlItemViaApiStub.calledWith
          goods_id: '1'
          goods_name: 'goods1'
        assert.isTrue crawlItemViaApiStub.calledWith
          goods_id: '2'
          goods_name: 'goods2'
        assert.isTrue crawlItemViaApiStub.calledWith
          goods_id: '3'
          goods_name: 'goods3'
        done()

  describe '#crawlDesc', ->
    it 'should return html', () ->
      f = taobao_crawler.fetch
      taobao_crawler.setFetch (url) ->
        then: (cb) ->
          cb DESC_RESPONSE
          catch: ->
      taobao_crawler.crawlDesc 'http://some_url'
        .then (desc) ->
          assert.equal desc, '<p><img align="absmiddle" style="width: 750.0px;float: none;margin: 0.0px;" src="https://img.alicdn.com/imgextra/i3/1706550192/TB29m7NeXXXXXb3XXXXXXXXXXXX-1706550192.jpg"></p>'
        .finally ->
          taobao_crawler.setFetch f
    it 'should report error', () ->
      f = taobao_crawler.fetch
      taobao_crawler.setFetch (url) ->
        then: (cb) ->
          cb ''
          catch: ->
      taobao_crawler.crawlDesc 'http://some_url'
        .then (desc) ->
          undefined
        .catch (reason) ->
          assert.include reason.message, 'desc response text does not contain valid content'
        .finally ->
          taobao_crawler.setFetch f

  describe '#extractDescUrl', ->
    it 'should return desc url', ->
      assert.equal taobao_crawler.extractDescUrl(DESC_URL_HTML), 'https://desc.alicdn.com/i6/440/690/44469144076/TB19Th7HFXXXXXHXXXX8qtpFXXX.desc%7Cvar%5Edesc%3Bsign%5E6228467ccd3990ad0fa0cee6a646bfe3%3Blang%5Egbk%3Bt%5E1432183676'

  describe '#extractSkus', ->
    it 'should return skus', (done) ->
      env SKUS_HTML,(error, window) ->
        $ = jquery window
        assert.deepEqual taobao_crawler.extractSkus($, '234.00'),
          sku: [
            price: '234.00'
            properties: '1627207:6594326;20509:28314'
            properties_name: '1627207:6594326:颜色分类:图片色;20509:28314:尺码:S'
            quantity: 999
          ,
            price: '234.00'
            properties: '1627207:6594326;20509:28315'
            properties_name: '1627207:6594326:颜色分类:图片色;20509:28315:尺码:M'
            quantity: 999
          ,
            price: '234.00'
            properties: '1627207:6594326;20509:28316'
            properties_name: '1627207:6594326:颜色分类:图片色;20509:28316:尺码:L'
            quantity: 999
          ,
            price: '234.00'
            properties: '1627207:6594326;20509:28317'
            properties_name: '1627207:6594326:颜色分类:图片色;20509:28317:尺码:XL'
            quantity: 999
          ]
        window.close()
        done()

  describe '#extractItemImgs', ->
    it 'should return item imgs', (done) ->
      env ITEM_IMGS_HTML, (error, window) ->
        $ = jquery window
        assert.deepEqual taobao_crawler.extractItemImgs($),
          item_img: [
            url: 'http://gd1.alicdn.com/bao/uploaded/i1/TB1pj7lHpXXXXc7aXXXXXXXXXXX_!!0-item_pic.jpg'
          ,
            url: 'http://gd4.alicdn.com/imgextra/i4/660463857/TB2q_dSdpXXXXbAXpXXXXXXXXXX_!!660463857.jpg'
          ,
            url: 'http://gd1.alicdn.com/imgextra/i1/660463857/TB2JaRRdpXXXXbfXpXXXXXXXXXX_!!660463857.jpg'
          ,
            url: 'http://gd3.alicdn.com/imgextra/i3/660463857/TB2HxpVdpXXXXXRXpXXXXXXXXXX_!!660463857.jpg'
          ,
            url: 'http://gd4.alicdn.com/imgextra/i4/660463857/TB2IeqedpXXXXXtXXXXXXXXXXXX_!!660463857.jpg'
          ]
        window.close()
        done()

  describe '#extractCid', ->
    it 'should return cid', ->
      assert.equal taobao_crawler.extractCid(CID_HTML), 50010850

  describe '#extractNick', ->
    it 'should return nick', ->
      assert.equal taobao_crawler.extractNick(CID_HTML), '天使彩虹城'

  describe '#extractPropsName', ->
    it 'should return props name', (done) ->
      taobao_crawler.setGetItemProps (cid, fields, parentPid, callback) ->
        callback null, PROPS_ARRAY
      env PROPS_HTML, (error, window) ->
        $ = jquery window
        taobao_crawler.extractPropsName $
          .then (propsName) ->
            assert.deepEqual propsName, '20608:6384766:风格:通勤;0:0:通勤:复古;10142888:3386071:组合形式:单件;122216349:3516807:裙长:中长裙;122276315:3226839:款式:挂脖式;122216348:29446:袖长:无袖;20663:20213:领型:其他;20677:29954:腰型:中腰;31611:103422:衣门襟:套头;18551851:14320260:裙型:一步裙;20603:130164:图案:花色;122216588:129555:流行元素/工艺:印花;20551:20213:面料:其他;13328588:492838732:成分含量:81%(含)-90%(含);122216347:647672577:年份季节:2015年夏季;1627207:28321:颜色分类:图片色;20509:649458002:尺码:S M L XL'
            # assert.deepEqual propsName, '20608:6384766:风格:通勤;18073285:43747:通勤:复古;10142888:3386071:组合形式:单件;122216349:44597:裙长:中长裙;122276315:3226839:款式:挂脖式;122216348:29446:袖长:无袖;20663:20213:领型:其他;20677:29954:腰型:中腰;31611:103422:衣门襟:套头;18551851:14320260:裙型:一步裙;20603:130164:图案:花色;122216588:129555:流行元素/工艺:印花;20551:20213:面料:其他;13328588:492838732:成分含量:81%(含)-90%(含);122216347:647672577:年份季节:2015年夏季;1627207:6594326:颜色分类:图片色;20509:28314:尺码:S;20509:28315:尺码:M;20509:28316:尺码:L;20509:28317:尺码:XL'
            done()
        window.close()

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
<body>
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
</body>
'''

DESC_RESPONSE = '''
var desc='<p><img align="absmiddle" style="width: 750.0px;float: none;margin: 0.0px;" src="https://img.alicdn.com/imgextra/i3/1706550192/TB29m7NeXXXXXb3XXXXXXXXXXXX-1706550192.jpg"></p>';
'''

DESC_URL_HTML = '''
 g_config.dynamicScript = function(f,c){var e=document,d=e.createElement("script");d.src=f;if(c){for(var b in c){d[b]=c[b];}};e.getElementsByTagName("head")[0].appendChild(d)};
     g_config.dynamicScript("https:" === location.protocol ? "//desc.alicdn.com/i6/440/690/44469144076/TB19Th7HFXXXXXHXXXX8qtpFXXX.desc%7Cvar%5Edesc%3Bsign%5E6228467ccd3990ad0fa0cee6a646bfe3%3Blang%5Egbk%3Bt%5E1432183676" :"//dsc.taobaocdn.com/i6/440/690/44469144076/TB19Th7HFXXXXXHXXXX8qtpFXXX.desc%7Cvar%5Edesc%3Bsign%5E6228467ccd3990ad0fa0cee6a646bfe3%3Blang%5Egbk%3Bt%5E1432183676")
'''

SKUS_HTML = '''
<div id="J_isku" data-spm="20140002" class="tb-key tb-key-sku" shortcut-key="i" shortcut-label="挑选宝贝" shortcut-effect="focus" data-spm-max-idx="10">
<div class="tb-skin">
 <dl class="J_Prop J_TMySizeProp tb-size tb-prop tb-clearfix      J_Prop_measurement  ">
<dt class="tb-property-type">尺码</dt>
<dd>
<ul data-property="尺码" class="J_TSaleProp tb-clearfix">
<li data-value="20509:28314" class="tb-selected"><a href="#" data-spm-anchor-id="2013.1.20140002.1"><span>S</span></a><i>已选中</i></li>
<li data-value="20509:28315" class=""><a href="#" data-spm-anchor-id="2013.1.20140002.2"><span>M</span></a><i>已选中</i></li>
<li data-value="20509:28316" class=""><a href="#" data-spm-anchor-id="2013.1.20140002.3"><span>L</span></a><i>已选中</i></li>
<li data-value="20509:28317" class=""><a href="#" data-spm-anchor-id="2013.1.20140002.4"><span>XL</span></a><i>已选中</i></li>
</ul></dd></dl>
<span id="J_TMySize" class="size-btn" data-template-id="" data-value-type="1" data-value="50010850" data-value-rt="16">› 尺码助手</span>
 <dl class="J_Prop tb-prop tb-clearfix   J_Prop_Color     ">
<dt class="tb-property-type">颜色分类</dt>
<dd>
<ul data-property="颜色分类" class="J_TSaleProp tb-clearfix tb-img">
<li data-value="1627207:6594326" class="tb-txt tb-selected">
<a href="#" data-spm-anchor-id="2013.1.20140002.5">
<span>图片色</span>
</a>
<i>已选中</i>
</li>
</ul></dd></dl>
<dl class="tb-amount tb-clearfix">
<dt class="tb-property-type">数量</dt>
<dd>
<span class="tb-stock" id="J_Stock">
 <a href="#" hidefocus="" class="tb-reduce J_Reduce tb-iconfont tb-disable-reduce" data-spm-anchor-id="2013.1.20140002.6">ƛ</a><input id="J_IptAmount" type="text" class="tb-text" value="1" maxlength="8" title="请输入购买量"><a href="#" hidefocus="" class="tb-increase J_Increase tb-iconfont" data-spm-anchor-id="2013.1.20140002.7">ƚ</a>件
 </span>
<em>(库存<span id="J_SpanStock" class="tb-count">999</span>件)</em>
</dd>
</dl>
<dl id="J_DlChoice" class="tb-choice tb-clearfix">
<dt>请选择：</dt>
<dd>
<em>"尺码"</em><em>"颜色分类"</em></dd>
</dl>
<div class="tb-sure" id="J_SureSKU"><p class="tb-choice">请勾选您要的商品信息</p>
<p class="tb-sure-continue"><a href="#" id="J_SureContinue" data-spm-anchor-id="2013.1.20140002.8">确定</a></p>
<span class="close J_Close tb-iconfont">ß</span>
</div>
<div class="tb-msg tb-hidden"><p class="tb-stop">发生错误</p></div><div class="tb-msg tb-hidden"><p class="tb-stop">请稍后重试</p></div><div id="J_juValid" class="tb-action tb-clearfix ">
<div class="tb-btn-buy"><a href="#" data-addfastbuy="true" title="点击此按钮，到下一步确认购买信息" class="J_LinkBuy" data-spm-click="gostr=/tbdetail;locaid=d1" shortcut-key="b" shortcut-label="立即购买" shortcut-effect="click" data-spm-anchor-id="2013.1.20140002.9">立即购买</a></div>
<div class="tb-btn-add"><a href="#" title="加入购物车" class="J_LinkAdd" data-spm-click="gostr=/tbdetail;locaid=d2" shortcut-key="a" shortcut-label="加入购物车" shortcut-effect="click" data-spm-anchor-id="2013.1.20140002.10"><i class="tb-iconfont">ŭ</i>加入购物车</a></div>
</div>
</div></div>
'''

ITEM_IMGS_HTML = '''
<ul id="J_UlThumb" class="tb-thumb tb-clearfix" data-spm="20140009">
     <li class="tb-selected" data-index="0">
     <div class="tb-pic tb-s50">
 <a href="#" data-spm-click="gostr=/tbdetail;locaid=d1"><img data-src="//gd1.alicdn.com/bao/uploaded/i1/TB1pj7lHpXXXXc7aXXXXXXXXXXX_!!0-item_pic.jpg_50x50.jpg" src="//gd1.alicdn.com/bao/uploaded/i1/TB1pj7lHpXXXXc7aXXXXXXXXXXX_!!0-item_pic.jpg_50x50.jpg"></a>
 </div>
   </li>
   <li data-index="1" class="">
     <div class="tb-pic tb-s50">
 <a href="#" data-spm-click="gostr=/tbdetail;locaid=d2"><img data-src="//gd4.alicdn.com/imgextra/i4/660463857/TB2q_dSdpXXXXbAXpXXXXXXXXXX_!!660463857.jpg_50x50.jpg" src="//gd4.alicdn.com/imgextra/i4/660463857/TB2q_dSdpXXXXbAXpXXXXXXXXXX_!!660463857.jpg_50x50.jpg"></a>
 </div>
   </li>
   <li data-index="2" class="">
     <div class="tb-pic tb-s50">
 <a href="#" data-spm-click="gostr=/tbdetail;locaid=d3"><img data-src="//gd1.alicdn.com/imgextra/i1/660463857/TB2JaRRdpXXXXbfXpXXXXXXXXXX_!!660463857.jpg_50x50.jpg" src="//gd1.alicdn.com/imgextra/i1/660463857/TB2JaRRdpXXXXbfXpXXXXXXXXXX_!!660463857.jpg_50x50.jpg"></a>
 </div>
   </li>
   <li data-index="3" class="">
     <div class="tb-pic tb-s50">
 <a href="#" data-spm-click="gostr=/tbdetail;locaid=d4"><img data-src="//gd3.alicdn.com/imgextra/i3/660463857/TB2HxpVdpXXXXXRXpXXXXXXXXXX_!!660463857.jpg_50x50.jpg" src="//gd3.alicdn.com/imgextra/i3/660463857/TB2HxpVdpXXXXXRXpXXXXXXXXXX_!!660463857.jpg_50x50.jpg"></a>
 </div>
   </li>
   <li data-index="4" class="">
     <div class="tb-pic tb-s50">
 <a href="#" data-spm-click="gostr=/tbdetail;locaid=d5"><img data-src="//gd4.alicdn.com/imgextra/i4/660463857/TB2IeqedpXXXXXtXXXXXXXXXXXX_!!660463857.jpg_50x50.jpg" src="//gd4.alicdn.com/imgextra/i4/660463857/TB2IeqedpXXXXXtXXXXXXXXXXXX_!!660463857.jpg_50x50.jpg"></a>
 </div>
   </li>
     </ul>
'''

CID_HTML = '''
(function(){
      g_config.DyBase={iurl:"//item.taobao.com",purl:"//paimai.taobao.com",spurl:"//archer.taobao.com",durl:"//design.taobao.com",lgurl:"https://login.taobao.com/member/login.jhtml?redirectURL=http%3A%2F%2Flocal_jboss%2Fitem.htm%3Fspm%3Da1z10.1-c.w4004-10773970730.24.q4onzq%26id%3D520223599219%26mt%3D",
surl:"//upload.taobao.com", shurl:"//shuo.taobao.com", murl:"http://meal.taobao.com" }; g_config.idata={
 item:{
 id:"520223599219",title:"2015\u590F\u65B0\u54C1\u540D\u5A9B\u6027\u611F\u6302\u8116\u9732\u80CC\u5370\u82B1\u4FEE\u8EAB\u663E\u7626\u6C14\u8D28\u6536\u8170\u4E2D\u957F\u8FDE\u8863\u88D9",
 skuComponentFirst: 'true',
  sellerNickGBK:'%CC%EC%CA%B9%B2%CA%BA%E7%B3%C7',
 sellerNick:'天使彩虹城',
 rcid:'16', cid:'50010850', virtQuantity:'2', holdQuantity:'0', edit:true, status:0,xjcc:false,
desc:false,
price:234.00,
 bnow:true, prepay:true, dbst:1434980561000,tka:false,
 chong:false, ju:false, iju: false, cu: false,  fcat:false, auto:"false", jbid:"",stepdata:{},
  jmark:"",   quickAdd: 1,
     initSizeJs:true,
           sizeGroupName:"中国码",
       auctionImages:[
   "//gd1.alicdn.com/bao/uploaded/i1/TB1pj7lHpXXXXc7aXXXXXXXXXXX_!!0-item_pic.jpg"
   ,
     "//gd4.alicdn.com/bao/uploaded/i4/660463857/TB2q_dSdpXXXXbAXpXXXXXXXXXX_!!660463857.jpg"
   ,
     "//gd1.alicdn.com/bao/uploaded/i1/660463857/TB2JaRRdpXXXXbfXpXXXXXXXXXX_!!660463857.jpg"
   ,
     "//gd3.alicdn.com/bao/uploaded/i3/660463857/TB2HxpVdpXXXXXRXpXXXXXXXXXX_!!660463857.jpg"
   ,
     "//gd4.alicdn.com/bao/uploaded/i4/660463857/TB2IeqedpXXXXXtXXXXXXXXXXXX_!!660463857.jpg"
     ],
   pic: "//gd1.alicdn.com/bao/uploaded/i1/TB1pj7lHpXXXXc7aXXXXXXXXXXX_!!0-item_pic.jpg",

     enterprise:false,
   disableAddToCart: false }, seller:{
 id:660463857,
 mode: 0,          tad:1,                    shopAge:4,
  status:0
}, shop:{
 id:"64472728",
 url: "//shop64472728.taobao.com/",
 pid:"",
 sid:"",
 xshop:true }     ,toggle:{
 "addCartJump":10
,"fangXinTaoMod":0
,"domainDegradeMod":0
 }
 } })();
</script>
  <script>if(!g_config.vdata.sys.toggle){g_config.vdata.sys.toggle={
 "thumb": false,
 "v":{"s1212v":"1"},
 "p":1.0,
 "dcP":"true",
 "sl":3000
 }}
'''

PROPS_HTML = '''
<ul class="attributes-list">
   <li title=" 通勤">风格: 通勤</li><li title=" 复古">通勤: 复古</li><li title=" 单件">组合形式: 单件</li><li title=" 中长裙">裙长: 中长裙</li><li title=" 挂脖式">款式: 挂脖式</li><li title=" 无袖">袖长: 无袖</li><li title=" 其他">领型: 其他</li><li title=" 中腰">腰型: 中腰</li><li title=" 套头">衣门襟: 套头</li><li title=" 一步裙">裙型: 一步裙</li><li title=" 花色">图案: 花色</li><li title=" 印花">流行元素/工艺: 印花</li><li title=" 其他">面料: 其他</li><li title=" 81%(含)-90%(含)">成分含量: 81%(含)-90%(含)</li><li title=" 2015年夏季">年份季节: 2015年夏季</li><li title=" 图片色">颜色分类: 图片色</li><li title=" S M L XL">尺码: S M L XL</li>
   </ul>
'''

PROPS_ARRAY = `
[
  {
    is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '廓形',
    parent_vid: 0,
    pid: 148886213,
    prop_values:
     { prop_value:
        [ { name: 'A型', vid: 3833300 },
          { name: 'H型', vid: 4245311 },
          { name: 'O型', vid: 10435992 },
          { name: 'T型', vid: 139170 },
          { name: 'X型', vid: 111004 } ] } },
  { is_enum_prop: false,
    is_key_prop: true,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '货号',
    parent_vid: 0,
    pid: 13021751 },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '风格',
    parent_vid: 0,
    pid: 20608,
    prop_values:
     { prop_value:
        [ { is_parent: true, name: '通勤', vid: 6384766 },
          { is_parent: true, name: '甜美', vid: 3267776 },
          { is_parent: true, name: '街头', vid: 29934 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '组合形式',
    parent_vid: 0,
    pid: 10142888,
    prop_values:
     { prop_value:
        [ { name: '三件套', vid: 44632 },
          { name: '单件', vid: 3386071 },
          { name: '两件套', vid: 31605 },
          { name: '假两件', vid: 130567 },
          { name: '其他', vid: 20213 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '裙长',
    parent_vid: 0,
    pid: 122216349,
    prop_values:
     { prop_value:
        [ { name: '超短裙', vid: 3516807 },
          { name: '短裙', vid: 29967 },
          { name: '中裙', vid: 29962 },
          { name: '中长款', vid: 44597 },
          { name: '长裙', vid: 29963 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '款式',
    parent_vid: 0,
    pid: 122276315,
    prop_values:
     { prop_value:
        [ { name: '背带', vid: 100343 },
          { name: '吊带', vid: 20495 },
          { name: '斜肩', vid: 20858859 },
          { name: '挂脖式', vid: 3226839 },
          { name: '裹胸', vid: 29942 },
          { name: '其他/other', vid: 14863995 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '袖长',
    parent_vid: 0,
    pid: 122216348,
    prop_values:
     { prop_value:
        [ { name: '短袖', vid: 29445 },
          { name: '长袖', vid: 29444 },
          { name: '九分袖', vid: 11162412 },
          { name: '七分袖', vid: 3216779 },
          { name: '五分袖', vid: 14587965 },
          { name: '无袖', vid: 29446 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '领型',
    parent_vid: 0,
    pid: 20663,
    prop_values:
     { prop_value:
        [ { name: '圆领', vid: 29447 },
          { name: 'V领', vid: 29448 },
          { name: '一字领', vid: 29917 },
          { name: 'POLO领', vid: 3276127 },
          { name: '荷叶领', vid: 9977673 },
          { name: '双层领', vid: 3267194 },
          { name: '立领', vid: 29541 },
          { name: '方领', vid: 29538 },
          { name: '高领', vid: 29546 },
          { name: '堆堆领', vid: 7486925 },
          { name: '海军领', vid: 57658638 },
          { name: '连帽', vid: 3267192 },
          { name: '半开领', vid: 30066992 },
          { name: '半高领', vid: 29075742 },
          { name: '围巾领', vid: 28867202 },
          { name: '娃娃领', vid: 27316112 },
          { name: '西装领', vid: 3267189 },
          { name: '其他', vid: 20213 },
          { name: '斜领', vid: 29482962 },
          { name: '可脱卸帽', vid: 3267193 },
          { name: '荡领', vid: 17219419 },
          { name: '毛领', vid: 8251758 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '袖型',
    parent_vid: 0,
    pid: 2917380,
    prop_values:
     { prop_value:
        [ { name: '飞飞袖', vid: 95316670 },
          { name: '公主袖', vid: 11245515 },
          { name: '其他', vid: 20213 },
          { name: '堆堆袖', vid: 145654279 },
          { name: '衬衫袖', vid: 27414723 },
          { name: '插肩袖', vid: 27414630 },
          { name: '蝙蝠袖', vid: 7576170 },
          { name: '花瓣袖', vid: 42625521 },
          { name: '荷叶袖', vid: 27414678 },
          { name: '常规', vid: 3226292 },
          { name: '灯笼袖', vid: 7216758 },
          { name: '包袖', vid: 27414703 },
          { name: '喇叭袖', vid: 19306903 },
          { name: '泡泡袖', vid: 5618747 },
          { name: '牛角袖', vid: 33331631 },
          { name: '连袖', vid: 53607756 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '腰型',
    parent_vid: 0,
    pid: 20677,
    prop_values:
     { prop_value:
        [ { name: '高腰', vid: 29952 },
          { name: '中腰', vid: 29954 },
          { name: '低腰', vid: 29953 },
          { name: '超低腰', vid: 69496479 },
          { name: '松紧腰', vid: 26363889 },
          { name: '宽松腰', vid: 95284510 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '衣门襟',
    parent_vid: 0,
    pid: 31611,
    prop_values:
     { prop_value:
        [ { name: '拉链', vid: 115481 },
          { name: '一粒扣', vid: 112631 },
          { name: '双排扣', vid: 103453 },
          { name: '套头', vid: 103422 },
          { name: '单排两粒扣', vid: 85462454 },
          { name: '三粒扣', vid: 112633 },
          { name: '单排扣', vid: 103454 },
          { name: '其他', vid: 20213 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '裙型',
    parent_vid: 0,
    pid: 18551851,
    prop_values:
     { prop_value:
        [ { name: '蛋糕裙', vid: 130312 },
          { name: '公主裙', vid: 5421384 },
          { name: '灯笼裙', vid: 9834279 },
          { name: '百褶裙', vid: 130313 },
          { name: '铅笔裙', vid: 12652518 },
          { name: '荷叶边裙', vid: 6129887 },
          { name: '其他', vid: 20213 },
          { name: '不规则裙', vid: 3596436 },
          { name: '大摆型', vid: 106225407 },
          { name: 'A字裙', vid: 130318 },
          { name: '一步裙', vid: 14320260 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '图案',
    parent_vid: 0,
    pid: 20603,
    prop_values:
     { prop_value:
        [ { name: '人物', vid: 46649 },
          { name: '纯色', vid: 29454 },
          { name: '花色', vid: 130164 },
          { name: '格子', vid: 29453 },
          { name: '圆点', vid: 113019 },
          { name: '条纹', vid: 29452 },
          { name: '手绘', vid: 29455 },
          { name: '卡通动漫', vid: 14031880 },
          { name: '豹纹', vid: 3255041 },
          { name: '千鸟格', vid: 3222563 },
          { name: '字母', vid: 45576 },
          { name: '动物图案', vid: 129881 },
          { name: '其他', vid: 20213 },
          { name: '碎花', vid: 107622 },
          { name: '风景', vid: 40793 },
          { name: '抽象图案', vid: 22083606 },
          { name: '建筑', vid: 6845848 },
          { name: '斑马纹', vid: 3666157 },
          { name: '大花', vid: 3755923 },
          { name: '动物纹', vid: 8034069 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: true,
    must: false,
    name: '流行元素/工艺',
    parent_vid: 0,
    pid: 122216588,
    prop_values:
     { prop_value:
        [ { name: '蝴蝶结', vid: 115772 },
          { name: '荷叶边', vid: 130316 },
          { name: '铆钉', vid: 115776 },
          { name: '植绒', vid: 3267928 },
          { name: '流苏', vid: 115777 },
          { name: '破洞', vid: 3267932 },
          { name: '镂空', vid: 115771 },
          { name: '抽褶', vid: 41118856 },
          { name: '肩章', vid: 130138 },
          { name: '亮丝', vid: 7573005 },
          { name: '镶钻', vid: 3332415 },
          { name: '露背', vid: 7600710 },
          { name: '油漆喷溅', vid: 141823124 },
          { name: '手工磨破', vid: 148585979 },
          { name: '贴布', vid: 130845 },
          { name: '绣花', vid: 29957 },
          { name: '链条', vid: 4015931 },
          { name: '褶皱', vid: 112602 },
          { name: '木耳', vid: 42536 },
          { name: '勾花镂空', vid: 148585986 },
          { name: '口袋', vid: 3243112 },
          { name: '系带', vid: 28102 },
          { name: '拼接', vid: 9142620 },
          { name: '螺纹', vid: 8611558 },
          { name: '扎花', vid: 17665110 },
          { name: '立体装饰', vid: 32971735 },
          { name: '不对称', vid: 7642045 },
          { name: '绑带', vid: 3705386 },
          { name: '扎染', vid: 5145675 },
          { name: '钉珠', vid: 29958 },
          { name: '波浪', vid: 3424792 },
          { name: '做旧', vid: 112597 },
          { name: '亮片', vid: 29959 },
          { name: '背带', vid: 100343 },
          { name: '纽扣', vid: 3693451 },
          { name: '纱网', vid: 26325697 },
          { name: '拉链', vid: 115481 },
          { name: '乱针修补', vid: 148585996 },
          { name: '锈斑处理', vid: 148585997 },
          { name: '树脂固色', vid: 148585998 },
          { name: '蕾丝', vid: 28386 },
          { name: '燕尾', vid: 6061030 },
          { name: '3D', vid: 3235817 },
          { name: '印花', vid: 129555 } ] } },
  { is_enum_prop: true,
    is_key_prop: true,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '品牌',
    parent_vid: 0,
    pid: 20000,
    prop_values:
     { prop_value:
        [ { name: '001', vid: 22048 },
          { name: '00后', vid: 170118616 },
          { name: '10 Crosby Derek Lam', vid: 135311220 },
          { name: '1004', vid: 3292770 },
          { name: '100F1/百分之一', vid: 33691944 },
          { name: '1010', vid: 96367 },
          { name: '13C', vid: 3932213 },
          { name: '1727', vid: 3372925 },
          { name: '1825', vid: 3388209 },
          { name: '1900', vid: 3282558 }] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '面料',
    parent_vid: 0,
    pid: 20551,
    prop_values:
     { prop_value:
        [ { name: '雪纺', vid: 28385 },
          { name: '欧根纱', vid: 130192 },
          { name: '织锦', vid: 9662813 },
          { name: '羊皮', vid: 28398 },
          { name: '毛呢', vid: 3267650 },
          { name: '牛仔布', vid: 28343 },
          { name: '绸缎', vid: 28354 },
          { name: '针织', vid: 103127 },
          { name: '猪皮', vid: 28399 },
          { name: '双绉', vid: 10572790 },
          { name: '天鹅绒', vid: 3227333 },
          { name: '府绸', vid: 24364835 },
          { name: '开司米', vid: 28356 },
          { name: '法兰绒', vid: 7874412 },
          { name: '轻薄花呢', vid: 138154439 },
          { name: '牛皮', vid: 28397 },
          { name: '蕾丝', vid: 28386 },
          { name: '灯芯绒', vid: 28344 },
          { name: '其他', vid: 20213 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '成分含量',
    parent_vid: 0,
    pid: 13328588,
    prop_values:
     { prop_value:
        [ { name: '31%(含)-50%(含)', vid: 492838729 },
          { name: '30%及以下', vid: 145656296 },
          { name: '96%及以上', vid: 145656297 },
          { name: '81%(含)-90%(含)', vid: 492838732 },
          { name: '51%(含)-70%(含)', vid: 493292416 },
          { name: '91%(含)-95%(含)', vid: 492838735 },
          { name: '71%(含)-80%(含)', vid: 492838731 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '材质',
    parent_vid: 0,
    pid: 20021,
    prop_values:
     { prop_value:
        [ { name: 'PU', vid: 3323086 },
          { name: '棉', vid: 105255 },
          { name: '麻', vid: 3267653 },
          { name: '羊毛', vid: 28352 },
          { name: '羊绒', vid: 28351 },
          { name: '蚕丝', vid: 130682 },
          { name: '莫代尔', vid: 103124 },
          { name: '醋纤', vid: 128710369 },
          { name: '涤纶', vid: 28355 },
          { name: '锦纶', vid: 112997 },
          { name: '丙纶', vid: 80663 },
          { name: '维纶', vid: 16842058 },
          { name: '氯纶', vid: 50941781 },
          { name: 'LYCRA莱卡', vid: 39679567 },
          { name: '羊皮', vid: 28398 },
          { name: '猪皮', vid: 28399 },
          { name: '牛皮', vid: 28397 },
          { name: '貂皮', vid: 112399 },
          { name: '兔毛', vid: 21122 },
          { name: '其他', vid: 20213 },
          { name: '真皮', vid: 44660 },
          { name: '腈纶', vid: 80664 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: false,
    name: '适用年龄',
    parent_vid: 0,
    pid: 20017,
    prop_values:
     { prop_value:
        [ { name: '18-24周岁', vid: 494072158 },
          { name: '25-29周岁', vid: 494072160 },
          { name: '30-34周岁', vid: 494072162 },
          { name: '35-39周岁', vid: 494072164 },
          { name: '40-49周岁', vid: 494072166 },
          { name: '17周岁以下', vid: 136515180 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: false,
    multi: false,
    must: true,
    name: '年份季节',
    parent_vid: 0,
    pid: 122216347,
    prop_values:
     { prop_value:
        [ { name: '2014年冬季', vid: 379886796 },
          { name: '2014年夏季', vid: 379818839 },
          { name: '2014年春季', vid: 379930774 },
          { name: '2014年秋季', vid: 380120406 },
          { name: '2015年冬季', vid: 740132938 },
          { name: '2015年夏季', vid: 647672577 },
          { name: '2015年春季', vid: 379874864 },
          { name: '2015年秋季', vid: 715192583 },
          { name: '2012年春季', vid: 132721270 },
          { name: '2012年夏季', vid: 132721297 },
          { name: '2012年秋季', vid: 132721317 },
          { name: '2012年冬季', vid: 132721335 },
          { name: '2011年春季', vid: 94386424 },
          { name: '2011年夏季', vid: 96618834 },
          { name: '2011年秋季', vid: 96618833 },
          { name: '2011年冬季', vid: 96618832 },
          { name: '2013年夏季', vid: 186026840 },
          { name: '2013年春季', vid: 199870733 },
          { name: '2013年冬季', vid: 209928863 },
          { name: '2013年秋季', vid: 209928864 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: true,
    multi: true,
    must: false,
    name: '颜色分类',
    parent_vid: 0,
    pid: 1627207,
    prop_values:
     { prop_value:
        [ { name: '乳白色', vid: 28321 },
          { name: '军绿色', vid: 3232483 },
          { name: '卡其色', vid: 28331 },
          { name: '咖啡色', vid: 129819 },
          { name: '墨绿色', vid: 80557 },
          { name: '天蓝色', vid: 3232484 },
          { name: '姜黄色', vid: 15409374 },
          { name: '孔雀蓝', vid: 5138330 },
          { name: '宝蓝色', vid: 3707775 },
          { name: '巧克力色', vid: 3232481 },
          { name: '明黄色', vid: 20412615 },
          { name: '杏色', vid: 30155 },
          { name: '柠檬黄', vid: 132476 },
          { name: '栗色', vid: 6071353 },
          { name: '桔红色', vid: 4950473 },
          { name: '桔色', vid: 90554 },
          { name: '浅棕色', vid: 30158 },
          { name: '浅灰色', vid: 28332 },
          { name: '浅紫色', vid: 4104877 },
          { name: '浅绿色', vid: 30156 },
          { name: '浅蓝色', vid: 28337 },
          { name: '浅黄色', vid: 60092 },
          { name: '深卡其布色', vid: 3232482 },
          { name: '深棕色', vid: 6588790 },
          { name: '深灰色', vid: 3232478 },
          { name: '深紫色', vid: 3232479 },
          { name: '深蓝色', vid: 28340 },
          { name: '湖蓝色', vid: 5483105 },
          { name: '灰色', vid: 28334 },
          { name: '玫红色', vid: 3594022 },
          { name: '白色', vid: 28320 },
          { name: '米白色', vid: 4266701 },
          { name: '粉红色', vid: 3232480 },
          { name: '紫红色', vid: 5167321 },
          { name: '紫罗兰', vid: 80882 },
          { name: '紫色', vid: 28329 },
          { name: '红色', vid: 28326 },
          { name: '绿色', vid: 28335 },
          { name: '翠绿色', vid: 8588036 },
          { name: '花色', vid: 130164 },
          { name: '荧光绿', vid: 6535235 },
          { name: '荧光黄', vid: 6134424 },
          { name: '蓝色', vid: 28338 },
          { name: '藏青色', vid: 28866 },
          { name: '藕色', vid: 4464174 },
          { name: '褐色', vid: 132069 },
          { name: '西瓜红', vid: 3743025 },
          { name: '透明', vid: 107121 },
          { name: '酒红色', vid: 28327 },
          { name: '金色', vid: 28328 },
          { name: '银色', vid: 28330 },
          { name: '青色', vid: 3455405 },
          { name: '香槟色', vid: 130166 },
          { name: '驼色', vid: 3224419 },
          { name: '黄色', vid: 28324 },
          { name: '黑色', vid: 28341 } ] } },
  { is_enum_prop: true,
    is_key_prop: false,
    is_sale_prop: true,
    multi: true,
    must: false,
    name: '尺码',
    parent_vid: 0,
    pid: 20509,
    prop_values:
     { prop_value:
        [ { name: '145/80A', vid: 649458002 },
          { name: 'XXS', vid: 28381 },
          { name: '150/80A', vid: 66579689 },
          { name: 'XS', vid: 28313 },
          { name: '155/80A', vid: 3959184 },
          { name: 'S', vid: 28314 },
          { name: '160/84A', vid: 6215318 },
          { name: 'M', vid: 28315 },
          { name: '165/88A', vid: 3267942 },
          { name: 'L', vid: 28316 },
          { name: '170/92A', vid: 3267943 },
          { name: 'UK4', vid: 9573633 },
          { name: 'XL', vid: 28317 },
          { name: '175/96A', vid: 3267944 },
          { name: '2XL', vid: 6145171 },
          { name: 'XXL', vid: 28318 },
          { name: '175/100A', vid: 71744989 },
          { name: '3XL', vid: 115781 },
          { name: 'XXXL', vid: 28319 },
          { name: '4XL', vid: 3727387 },
          { name: '5XL', vid: 7539404 },
          { name: 'uk6', vid: 12624364 },
          { name: '6XL', vid: 28128814 },
          { name: '均码', vid: 28383 },
          { name: 'UK8', vid: 9784259 },
          { name: 'UK10', vid: 7285415 },
          { name: 'UK12', vid: 9876263 },
          { name: 'UK14', vid: 65356191 },
          { name: 'UK16', vid: 4352277 },
          { name: 'uk18', vid: 12680589 },
          { name: 'UK20', vid: 13041257 },
          { name: 'US0', vid: 151093043 },
          { name: 'US2', vid: 6651814 },
          { name: 'US4', vid: 10504551 },
          { name: 'us6', vid: 8226873 },
          { name: 'us8', vid: 12674322 },
          { name: 'us10', vid: 12674541 },
          { name: 'US12', vid: 11768567 },
          { name: 'us14', vid: 12677498 },
          { name: 'Us16', vid: 8201177 } ] } } ]`

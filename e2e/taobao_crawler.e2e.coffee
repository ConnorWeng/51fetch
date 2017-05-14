{inspect} = require 'util'
chai = require 'chai'
{stub} = require 'sinon'
{getHierarchalCats, crawlTaobaoItem, crawlStore, setDatabase, crawlItemsInStore, setGetHierarchalCats, setGetItemProps} = require '../src/taobao_crawler'
database = require '../src/database'
{setRateLimits} = require '../src/crawler'

chai.should()

setRateLimits 5000

db = null

describe 'taobao_crawler', ->
  beforeEach ->
    db = new database()
    stub db, 'getStores', (a, cb) -> cb null, [{
      store_id: 161190
      store_name: '衫公主'
      im_ww: '一片冰心liutong'
      see_price: '减20'
      shop_http: 'https://shop106868309.taobao.com'
    }]
    stub db, 'getUnfetchedGoodsInStore', (a, cb) ->
      cb null, [{
        goods_id: 8906021
        goods_name: '爆款1063实拍2017夏装新款韩版显瘦字母印花T恤女式圆领短袖上衣'
        price: '19.00'
        good_http: 'http://item.taobao.com/item.htm?id=550572854274'
        store_id: 161190
      }, {
        goods_id: 8385081
        goods_name: '6016#实拍2016夏季新款大码女装宽松缕空露肩镶钻蝙蝠袖t恤'
        price: '28.00'
        good_http: 'http://item.taobao.com/item.htm?id=39250094595'
        store_id: 5867
      }]
    stub db, 'updateGoods', (a, b, c, d, e, f, g, h, i, j, cb) -> cb null, {}
    stub db, 'updateItemImgs', (a, b, cb) -> cb null, {}
    stub db, 'updateCats', (a, b, c, cb) -> cb null, {}
    stub db, 'updateSpecs', (a, b, c, d, e, cb) -> cb null, {insertId: 1}
    stub db, 'updateDefaultSpec', (a, b, cb) -> cb null, {}
    stub db, 'saveItemAttr', (a, b, cb) -> cb null, {}
    stub db, 'updateStoreCateContent', ->
    stub db, 'updateImWw', ->
    stub db, 'clearCids', ->
    stub db, 'deleteDelistItems', (a, b, cb) -> cb null, {}
    stub db, 'saveItems', (a, b, c, d, e, f, cb) -> cb null, {}
    setDatabase db

  describe '#crawlStore', ->
    it 'should crawl all items with basic info', (done) ->
      this.timeout 60000
      crawlStore {
        store_id: 10015
        store_name: '相思雨牛仔女装'
        im_ww: '相思雨牛仔女装'
        see_price: '减20'
        shop_http: 'https://shop113550542.taobao.com'
      }, false, ->
        console.log inspect db.deleteDelistItems.args, depth: 5
        console.log inspect db.saveItems.args, depth: 5
        done()

  describe '#crawlItemsInStore', ->
    it 'should crawl all items with detail info', (done) ->
      this.timeout 60000
      setGetHierarchalCats (cid, cb) -> cb null, [{
        cid: 1
        name: '女装'
        parent_id: 0
      }]
      setGetItemProps (a, b, c, cb) -> cb null, "1:1:袖长:中袖;2:2:风格:诡异"
      crawlItemsInStore 161190, null, ->
        console.log inspect db.updateGoods.args, depth: 5
        console.log inspect db.updateSpecs.args, depth: 5
        done()

  describe '#getHierarchalCats', ->
    it.skip 'should return hierarchal cats', (done) ->
      getHierarchalCats 162103, (err, cats) ->
        cats.should.eql [{
          "cid": 162103
          "name": "毛衣"
          "parent_cid": 16
        }, {
          "cid": 16
          "name": "女装/女士精品"
          "parent_cid": 0
        }]
        done()

  describe '#crawlTaobaoItem', ->
    it.skip 'should get item title', (done) ->
      crawlTaobaoItem 520223599219, (error, taobaoItem) ->
        if error then throw error
        taobaoItem.title.should.eql '2015夏新品名媛性感挂脖露背印花修身显瘦气质收腰中长连衣裙'
        taobaoItem.pic_url.should.eql 'http://gd1.alicdn.com/bao/uploaded/i1/TB1pj7lHpXXXXc7aXXXXXXXXXXX_!!0-item_pic.jpg'
        taobaoItem.desc.should.include 'http://img.alicdn.com/imgextra/i4/660463857/TB2Ba8SdpXXXXa3XpXXXXXXXXXX-660463857.jpg'
        taobaoItem.price.should.eql '234.00'
        taobaoItem.skus.should.eql
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
        taobaoItem.item_imgs.should.eql
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
        taobaoItem.cid.should.eql 50010850
        taobaoItem.nick.should.eql '天使彩虹城'
        taobaoItem.props_name.should.include '122216588:129555:流行元素/工艺:印花;20551:20213:面料:其他;13328588:492838732:成分含量:81%(含)-90%(含);'
        done()

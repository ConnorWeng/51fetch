{inspect} = require 'util'
chai = require 'chai'
{stub} = require 'sinon'
{getHierarchalCats, crawlTaobaoItem, crawlStore, setDatabase} = require '../src/taobao_crawler'
database = require '../src/database'

chai.should()

describe 'taobao_crawler', ->
  describe '#crawlStore', ->
    db = new database()
    stub db, 'getStores', ->
    stub db, 'getUnfetchedGoodsInStore', ->
    stub db, 'updateGoods', ->
    stub db, 'updateItemImgs', ->
    stub db, 'updateCats', ->
    stub db, 'updateSpecs', ->
    stub db, 'updateDefaultSpec', ->
    stub db, 'saveItemAttr', ->
    stub db, 'updateStoreCateContent', ->
    stub db, 'updateImWw', ->
    stub db, 'clearCids', ->
    stub db, 'deleteDelistItems', (a, b, cb) -> cb()
    stub db, 'saveItems', (a, b, c, d, e, f, cb) -> cb()
    setDatabase db
    it 'should crawl all items with basic info', (done) ->
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

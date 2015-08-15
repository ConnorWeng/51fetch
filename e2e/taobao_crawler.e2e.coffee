chai = require 'chai'
{getHierarchalCats, crawlTaobaoItem} = require '../src/taobao_crawler'

chai.should()

describe 'taobao_crawler', ->
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
    it 'should get item title', (done) ->
      crawlTaobaoItem 520223599219, (error, taobaoItem) ->
        if error then throw error
        taobaoItem.title.should.eql '2015夏新品名媛性感挂脖露背印花修身显瘦气质收腰中长连衣裙'
        taobaoItem.pic_url.should.eql 'http://gd1.alicdn.com/bao/uploaded/i1/TB1pj7lHpXXXXc7aXXXXXXXXXXX_!!0-item_pic.jpg'
        taobaoItem.desc.should.include 'http://img.alicdn.com/imgextra/i4/660463857/TB2Ba8SdpXXXXa3XpXXXXXXXXXX-660463857.jpg'
        taobaoItem.price.should.eql '234.00'
        done()

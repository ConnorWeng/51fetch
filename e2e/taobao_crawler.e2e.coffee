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
      crawlTaobaoItem 521078609850, (error, taobaoItem) ->
        if error then throw error
        taobaoItem.title.should.eql '实拍806#2015秋装新款女装打底衫韩版雪纺衬衣长袖衬衫女'
        taobaoItem.pic_url.should.eql 'http://gd3.alicdn.com/bao/uploaded/i3/TB1aay4IVXXXXb2XVXXXXXXXXXX_!!0-item_pic.jpg'
        taobaoItem.desc.should.include 'https://img.alicdn.com/imgextra/i3/1706550192/TB29m7NeXXXXXb3XXXXXXXXXXXX-1706550192.jpg'
        done()

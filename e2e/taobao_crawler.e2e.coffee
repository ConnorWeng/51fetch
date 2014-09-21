chai = require 'chai'
{getHierarchalCats} = require '../src/taobao_crawler'

chai.should()

describe 'taobao_crawler', ->
  describe '#getHierarchalCats', ->
    it 'should return hierarchal cats', (done) ->
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

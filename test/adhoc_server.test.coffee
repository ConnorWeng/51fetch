chai = require 'chai'
{matchUrlPattern} = require '../src/adhoc_server'

chai.should()

describe 'realtime_server', ->
  describe '#matchUrlPattern', ->
    it 'should return true when pattern is /store/{storeId} and input is ["","store","1"]', ->
      matchUrlPattern(['', 'store', '1'], '/store/{storeId}').should.equal true
    it 'should return false when pattern is /store/{storeId} and input is ["","stores","1"]', ->
      matchUrlPattern(['', 'stores', '1'], '/store/{storeId}').should.equal false
    it 'should return true when pattern is /item and input is ["", "item"]', ->
      matchUrlPattern(['', 'item'], '/item').should.equal true
    it 'should return true when pattern is /stores/{storeId}?sync and input is ["","stores","1"]', ->
      matchUrlPattern(['', 'stores', '1'], '/stores/{storeId}?sync').should.equal true

assert = require('chai').assert
sinon = require 'sinon'
database = require './database'
taobao_crawler = require './taobao_crawler'
memwatch = require 'memwatch'

databaseStub = sinon.createStubInstance database
taobao_crawler.setDatabase databaseStub

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

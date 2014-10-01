chai = require 'chai'
jquery = require 'jquery'
env = require('jsdom').env
c = require('../src/taobao_crawler').crawler

chai.should()

describe 'fetch single url', ->
  it 'should return expected content', (done) ->
    c.queue [
      'uri': 'http://shop60363617.taobao.com/?search=y&viewType=grid&orderType=_newOn'
      'callback': (err, result) ->
        env result.body, (errors, window) ->
          $ = jquery window
          $('div.item:eq(0) a').attr('href').should.contain('item.htm?id=')
          done()
    ]

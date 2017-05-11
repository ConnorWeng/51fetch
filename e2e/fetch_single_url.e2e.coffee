chai = require 'chai'
jquery = require 'jquery'
env = require('jsdom').env
{fetch} = require '../src/crawler'

chai.should()

describe 'fetch single url', ->
  it 'should return expected content', (done) ->
    fetch 'http://shop60363617.taobao.com//search.htm?search=y&orderType=newOn_desc&viewType=grid'
      .then (result) ->
        env result.body, (errors, window) ->
          $ = jquery window
          $('dl.item:eq(0) a').attr('href').should.contain('item.htm?id=')
          done()
      .catch (err) ->
        done err

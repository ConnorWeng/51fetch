crawler = require('crawler').Crawler
env = require('jsdom').env
jquery = require 'jquery'

c = new crawler
c.queue [
  'uri': 'http://shop62199157.taobao.com/category-909026445.htm?search=y&catName=2014%C4%EA4%D4%C2%D0%C2%BF%EE#bd##我的店铺##10##减20'
  'jQuery': false
  'forceUTF8': true
  'callback': (err, result) ->
    if err
      console.error err
    else
      env result.body, (err, window) ->
        $ = jquery window
        console.log $('dl.item').text()
]

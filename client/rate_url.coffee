{readFileSync} = require 'fs'
Q = require 'q'
jquery = require 'jquery'
{env} = require 'jsdom'
{Crawler} = require 'crawler'

c = new Crawler
  'forceUTF8': true
  'rateLimits': 5000
  'jQuery': false
  'method': 'POST'

fetch = (url) ->
  defered = Q.defer()
  c.queue [
    'uri': url
    'callback': (err, result, $) ->
      if err
        defered.reject err
      else
        defered.resolve result.body
  ]
  defered.promise

makeJsDom = Q.nfbind env

urls = readFileSync('shop_http.txt').toString().split('\n')

echoRateUrl = () ->
  if urls.length > 0
    url = urls.shift() + '/search.htm?search=y&orderType=newOn_desc'
    fetch url
      .then (body) ->
        makeJsDom body
      .then (window) ->
        $ = jquery window
        console.log $('a.rank-icon').attr('href')
        window.close()
        echoRateUrl()
      .then undefined, (error) ->
        echoRateUrl()
  else
    process.exit 0

echoRateUrl()

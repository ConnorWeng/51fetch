{Crawler} = require 'crawler'

c = new Crawler
  'forceUTF8': true
  'rateLimits': 500
  'jQuery': true

crawl = (url, params, callback) ->
  c.queue [
    'uri': url
    'callback': (err, result, $) ->
      if err
        callback err, null
      else
        data = evaluate params, $
        callback null, data
  ]

evaluate = (params, $) ->
  data = {}
  for name, func of params
    data[name] = func($)
  data

exports.crawl = crawl
exports.evaluate = evaluate

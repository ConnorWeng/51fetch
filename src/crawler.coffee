http = require 'http'
{Crawler} = require 'crawler'
{env} = require 'jsdom'
{log, error} = require 'util'
jquery = require 'jquery'
Q = require 'q'
config = require './config'

MAX_RETRY_TIMES = 10

c = new Crawler
  'headers':
    'Cookie': config.cookie
  'forceUTF8': true
  'jQuery': false
  'timeout': 10000

IPProxies = []
IPIndex = 0
lastUpdate = 0

after30m = ->
  now = new Date().getTime()
  if now - lastUpdate > 1800 * 1000
    lastUpdate = now
    true
  else
    false

updateIPProxiesViaApi = ->
  http.get config.ip_proxies_api, (res) ->
    if res.statusCode isnt 200
      error 'fail to get new ip via api'
      res.resume()
      return
    res.setEncoding 'utf8'
    rawJSON = ''
    res.on 'data', (chunk) -> rawJSON += chunk
    res.on 'end', ->
      log "api back"
      try
        json = JSON.parse rawJSON
        if json.RESULT and json.RESULT.length > 0
          IPProxies = ("http://#{proxy.ip}:#{proxy.port}" for proxy in json.RESULT)
          log "success to get new ip via api, count: #{json.RESULT.length}"
        else
          error "fail to get api result, error: #{json.ERRORCODE}"
      catch e
        error "fail to parse json from api, error: #{e.message}"
  .on 'error', (e) -> error "fail to get new ip via api, error: #{e.message}"

getIPProxy = ->
  if after30m() then updateIPProxiesViaApi()
  if IPProxies.length is 0 then return null;
  ip = IPProxies[IPIndex++]
  if IPIndex is IPProxies.length then IPIndex = 0
  ip

exports.setCrawler = (crawler) ->
  c = crawler

exports.setRateLimits = (rateLimits) ->
  c.options.rateLimits = rateLimits

exports.crawl = crawl = (url, params, callback) ->
  c.queue [
    'uri': url
    'callback': (err, result, $) ->
      if err
        callback err, null
      else
        if params is 'raw'
          data = result.body
        else
          data = evaluate params, $
        callback null, data
  ]

exports.evaluate = evaluate = (params, $) ->
  data = {}
  for name, func of params
    data[name] = func($)
  data

exports.fetch = fetch = (url, method = 'POST') ->
  defered = Q.defer()
  retryTimes = 0
  fetchImpl defered, url, method, retryTimes
  defered.promise

fetchImpl = (defered, url, method, retryTimes) ->
  c.queue [
    'uri': url
    'method': method
    'proxy': getIPProxy()
    'callback': (err, result) ->
      if err
        if ++retryTimes > MAX_RETRY_TIMES
          error "fail to fetch after trying #{retryTimes} times"
          defered.reject err
        else
          fetchImpl defered, url, method, retryTimes
      else
        defered.resolve result
  ]

exports.makeJsDom = makeJsDom = Q.nfbind env

firstModel = (map) ->
  for own key of map
    return map[key]

transform = (value, transform) ->
  if typeof transform is 'function'
    transform value
  else
    value

extractValue = ($parent, element, $) ->
  if element.type is 'link'
    value = transform $parent.find(element.selector).attr('href'), element['transform']
  else if element.type is 'text'
    value = transform $parent.find(element.selector).text().trim(), element['transform']
  else if element.type is 'img'
    value = transform $parent.find(element.selector).attr('src'), element['transform']
  else if element.type is 'html'
    value = transform $parent.find(element.selector).html(), element['transform']
  else if element.type is 'custom'
    value = element.get $
  value

exports.startCrawl = (url, map, model) ->
  fetch url
    .then (body) ->
      makeJsDom body
    .then (window) ->
      $ = jquery window
      pageData = {}
      links = []
      for key of model when key isnt 'handler'
        element = model[key]
        if element.type is 'list'
          pageData[key] = []
          $element = $(element.selector)
          if element.itemType is 'element'
            $element.each ->
              item = {}
              for itemKey of element.item
                item[itemKey] = extractValue $(@), element.item[itemKey]
                if item[itemKey]? and element.item[itemKey]['type'] is 'link' and element.item[itemKey]['fetch']? and element.item[itemKey].condition($)
                  links.push
                    url: item[itemKey]
                    model: element.item[itemKey]['fetch']
              pageData[key].push item
        else
          value = extractValue $('body'), element, $
          if value? and element.type is 'link' and element.fetch? and element.condition $
            links.push
              url: value
              model: element.fetch
          pageData[key] = value
      window.close()
      pageData['url'] = url
      model.handler pageData
        .then ->
          for link in links
            exports.startCrawl link.url, map, map[link.model]
    .then undefined, (error) -> console.error error

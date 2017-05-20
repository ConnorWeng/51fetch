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
  'timeout': 8000
  'retries': 0
  'rateLimits': 5000

IPProxies = []
IPIndex = 0
lastUpdate = 0

after1m = ->
  now = new Date().getTime()
  if now - lastUpdate > 60 * 1000
    true
  else
    false

updateIPProxiesViaApi = ->
  lastUpdate = new Date().getTime()
  http.get config.ip_proxies_api, (res) ->
    if res.statusCode isnt 200
      error 'fail to get new ip via api'
      res.resume()
      return
    res.setEncoding 'utf8'
    rawJSON = ''
    res.on 'data', (chunk) -> rawJSON += chunk
    res.on 'end', ->
      try
        json = JSON.parse rawJSON
        if json.ERRORCODE is '0'
          IPProxies = ({url: "http://#{proxy.ip}:#{proxy.port}", available: true} for proxy in json.RESULT)
          setRateLimits 0
          log "success to get new ip via api, count: #{json.RESULT.length}, speed way up the fetch rate"
        else
          error "fail to get api result, error: #{json.ERRORCODE} #{json.RESULT}"
          if json.ERRORCODE is '10032'
            IPProxies = []
            setRateLimits 5000
            log "because of #{json.RESULT} so that slow way down the fetch rate"
      catch e
        error "fail to parse json from api, error: #{e.message}"
  .on 'error', (e) ->
    error "fail to get new ip via api, error: #{e.message}"

isAllUnavailable = ->
  status = (proxy.available for proxy in IPProxies)
  if ~status.indexOf true
    false
  else
    log "all proxies are unavailable"
    true

getIPProxy = ->
  if after1m() and isAllUnavailable() then updateIPProxiesViaApi()
  if IPProxies.length is 0 then return null;
  while IPIndex < IPProxies.length
    proxy = IPProxies[IPIndex++]
    if proxy.available then break
  if IPIndex is IPProxies.length then IPIndex = 0
  proxy.url

exports.setCrawler = (crawler) ->
  c = crawler

exports.setRateLimits = setRateLimits = (rateLimits) ->
  c.options.maxConnections = if rateLimits isnt 0 then 1 else 10
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
        if result.proxy? and result.proxy isnt ''
          for proxy in IPProxies
            if proxy.url is result.proxy
              proxy.available = false
              log "#{result.proxy} becomes unavailable"
              break
        if ++retryTimes > MAX_RETRY_TIMES
          error "fail to fetch after trying #{retryTimes} times, err: #{err}, url: #{url}"
          defered.reject err
        else
          log "fail to fetch, retrying, err: #{err}, url: #{url}"
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

if process.env.NODE_ENV is 'test'
  getIPProxy = -> null

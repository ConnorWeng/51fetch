{Crawler} = require 'crawler'
{env} = require 'jsdom'
jquery = require 'jquery'
Q = require 'q'

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
        if params is 'raw'
          data = result.body
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

http = require 'http'
jsdom = require 'jsdom'
iconv = require 'iconv-lite'

exports.requestHtmlContent = (url, callback) ->
  result = ''
  http.get url, (res) ->
    res.on 'data', (chunk) ->
      result += iconv.decode chunk, 'GBK'
    res.on 'end', () ->
      callback null, result

exports.extractItemsFromContent = (content, callback) ->
  jsdom.env content, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) ->
    $ = window.$
    items = []
    $('dl.item').each () ->
      $item = $(this)
      items.push
        goodsName: $item.find('a.item-name').text()
        defaultImage: $item.find('img').attr('data-ks-lazyload')
        price: $item.find('.c-price').text().trim()
        goodHttp: $item.find('a.item-name').attr('href')
    callback err, items

exports.nextPage = (content, callback) ->
  jsdom.env content, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) ->
    $ = window.$
    $nextLink = $('a.J_SearchAsync.next')
    if $nextLink.length > 0
      callback null, $nextLink.attr('href')
    else
      callback null, null

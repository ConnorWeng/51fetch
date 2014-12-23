{log, error} = require 'util'
querystring = require 'querystring'
http = require 'http'
{crawl} = require '../src/crawler'

unaddedStores = []

crawl 'http://www.591wx.com',
  'stores': ($) ->
    stores = []
    $('#market .clearfix').each ->
      $clearfix = $ @
      shopMall = $clearfix.find('.bt').text().trim()
      $clearfix.find('.nr dd').each ->
        $dd = $ @
        text = $dd.find('p').text().trim()
        stores.push
          'shop_mall': shopMall
          'address': address text
          'store_name': $dd.find('a.et').text()
          'im_ww': ww $dd.find('p a:eq(0)').attr('href')
          'im_qq': qq $dd.find('p a:eq(1)').attr('href')
          'shop_http': $dd.find('a.et').attr('href')
    stores
  , (err, data) ->
    if err
      error err
    else
      unaddedStores = data['stores']
      register()

register = ->
  if unaddedStores.length > 0
    store = unaddedStores.shift()
    addStore store, register
  else
    log 'completed.'

addStore = (store, callback) ->
  data = querystring.stringify
    shop_mall: store.shop_mall
    address: store.address
    store_name: store.store_name
    im_qq: store.im_qq
    im_ww: store.im_ww
    shop_http: store.shop_http
  options =
    hostname: 'nt.51zwd.com'
    port: 80
    path: "/sms_http.php?username=#{store.im_qq}"
    method: 'POST'
    headers:
      'Content-Type': 'application/x-www-form-urlencoded'
      'Content-Length': data.length
  req = http.request options, (res) ->
    log "store_name: #{store.store_name}, status: #{res.statusCode}"
    body = ''
    res.on 'data', (chunk) ->
      body += chunk;
    res.on 'end', () ->
      log body
      callback()
  req.write "#{data}\n"
  req.end()


address = (text) ->
  index = text.indexOf '地址'
  text.substr(index + 3).trim()

extract = (regex) ->
  (url) ->
    matches = url.match regex
    decodeURI matches[1]

qq = extract /uin=(.*?)&/

ww = extract /uid=(.*?)&/

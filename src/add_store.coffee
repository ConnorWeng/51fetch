http = require 'http'
querystring = require 'querystring'
{log} = require 'util'

database = require './database'

db = new database

unaddedStores = []

db.getUnfetchedStores (err, stores) ->
  db.end()
  if err then throw err
  unaddedStores = stores
  register()

register = ->
  if unaddedStores.length > 0
    store = unaddedStores.shift()
    registerImpl store, register
  else
    log 'completed.'

registerImpl = (store, callback) ->
  data = querystring.stringify
    shop_mall: store.shop_mall
    floor: store.floor
    address: store.address
    store_name: store.store_name
    see_price: store.see_price
    im_qq: store.im_qq
    im_ww: store.im_ww
    shop_http: store.shop_http
    has_link: store.has_link
    serv_refund: store.serv_refund
    serv_exchgoods: store.serv_exchgoods
    serv_sendgoods: store.serv_sendgoods
    serv_probexch: store.serv_probexch
    serv_deltpic: store.serv_deltpic
    serv_modpic: store.serv_modpic
    serv_golden: store.serv_golden
  options =
    hostname: 'mall.51zwd.com'
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

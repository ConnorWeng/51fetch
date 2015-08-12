crypto = require 'crypto'
phpjs = require 'phpjs'
http = require 'http'
querystring = require 'querystring'
config = require './config'

exports.getTaobaoItemsOnsale = (fields, session, callback) ->
  apiParams =
    'fields': fields
  execute 'taobao.items.onsale.get', apiParams, session, (err, result) ->
    if result.items_onsale_get_response?.items?.item?
      callback null, result.items_onsale_get_response.items.item
    else
      handleError err, result, callback

exports.getTaobaoItemSeller = (numIid, fields, session, callback) ->
  apiParams =
    'num_iid': numIid
    'fields': fields
  execute 'taobao.item.seller.get', apiParams, session, (err, result) ->
    if result.item_seller_get_response?.item?
      callback null, result.item_seller_get_response.item
    else
      handleError err, result, callback

exports.getTaobaoItem = (numIid, fields, callback) ->
  apiParams =
    'num_iid': numIid
    'fields': fields
  execute 'taobao.item.get', apiParams, null, (err, result) ->
    if result.item_get_response?.item?
      callback null, result.item_get_response.item
    else
      handleError err, result, callback

exports.getItemCats = (cids, fields, callback) ->
  apiParams =
    'cids': "#{cids}"
    'fields': fields
  execute 'taobao.itemcats.get', apiParams, null, (err, result) ->
    if result.itemcats_get_response?.item_cats?.item_cat?
      callback null, result.itemcats_get_response.item_cats.item_cat
    else
      handleError err, result, callback

exports.getSellercatsList = (nick, callback) ->
  apiParams =
    'nick': nick
  execute 'taobao.sellercats.list.get', apiParams, null, (err, result) ->
    if result.sellercats_list_get_response?
      if result.sellercats_list_get_response?.seller_cats?.seller_cat?
        callback null, result.sellercats_list_get_response.seller_cats.seller_cat
      else
        callback null, []
    else
      handleError err, result, callback

execute = (method, apiParams, session, callback) ->
  sysParams =
    'app_key': config.taobao_app_key
    'v': '2.0'
    'format': 'json'
    'sign_method': 'md5'
    'method': method
    'timestamp': phpjs.date 'Y-m-d H:i:s'
    'partner_id': 'top-sdk-php-20140420'
  if session then sysParams['session'] = session
  sign = generateSign phpjs.array_merge sysParams, apiParams
  sysParams['sign'] = sign
  options =
    hostname: 'gw.api.taobao.com'
    path: "/router/rest?#{querystring.stringify sysParams}"
    method: 'POST'
    headers:
      'Content-Type': 'application/x-www-form-urlencoded'
      'Content-Length': querystring.stringify(apiParams).length
  req = http.request options, (res) ->
    res.setEncoding 'utf8'
    data = ''
    res.on 'data', (chunk) ->
      data += chunk;
    res.on 'end', ->
      res = JSON.parse data
      callback null, res
  req.on 'error', (err) ->
    callback err, null
  req.write "#{querystring.stringify apiParams}\n"
  req.end()

handleError = (err, result, callback) ->
  if err
    callback err, null
  else
    if result.error_response?
      errorResponse = result.error_response
      callback new Error("#{errorResponse.code}; #{errorResponse.msg}; #{errorResponse.sub_code}; #{errorResponse.sub_msg}"), null
    else
      callback new Error(result), null

generateSign = (params) ->
  sortedParams = ksort params
  str = config.taobao_secret_key
  for k, v of sortedParams
    if v.indexOf('@') isnt 0
      str += "#{k}#{v}"
  str += config.taobao_secret_key
  md5(str).toUpperCase()

ksort = (obj) ->
  phpjs.ksort obj

md5 = (content) ->
  phpjs.md5 content

if process.env.NODE_ENV is 'test'
  exports.generateSign = generateSign
  exports.md5 = md5
  exports.ksort = ksort
  exports.setConfig = (c) -> config = c

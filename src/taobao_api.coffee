crypto = require 'crypto'
phpjs = require 'phpjs'
http = require 'http'
querystring = require 'querystring'
config = require './config'

exports.getTaobaoItem = (numIid, fields, callback) ->
  apiParams =
    'num_iid': numIid
    'fields': fields
  execute 'taobao.item.get', apiParams, (err, result) ->
    if result.item_get_response?.item?
      callback null, result.item_get_response.item
    else
      handleError err, result, callback

execute = (method, apiParams, callback) ->
  sysParams =
    'app_key': config.taobao_app_key
    'v': '2.0'
    'format': 'json'
    'sign_method': 'md5'
    'method': method
    'timestamp': phpjs.date 'Y-m-d H:i:s'
    'partner_id': 'top-sdk-php-20140420'
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
    data = ''
    res.on 'data', (chunk) ->
      data += chunk;
    res.on 'end', ->
      res = JSON.parse data
      callback null, res
    res.on 'error', (err) ->
      callback err, null
  req.write "#{querystring.stringify apiParams}\n"
  req.end()

handleError = (err, result, callback) ->
  if err
    callback err, null
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

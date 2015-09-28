# qq,tel?,mk_name,shop_mall,floor,address,dangkou_address,store_name,see_price,im_ww,shop_http?,services?
{env} = require 'jsdom'
jquery = require 'jquery'
Q = require 'q'
{fetch} = require '../src/crawler'

makeJsDom = Q.nfbind env

parseStore = ($store) ->
  qq: parseImQQ $store.find('.rebirth-arch-infor-block a.rebirth-arRight').attr('href')
  mk_name: $store.find('.rebirth-arch-infor-block-font:eq(0)').text() + '-' + $store.find('.rebirth-arch-infor-block-font:eq(2)').text()
  shop_mall: $store.find('.rebirth-arch-infor-block-font:eq(0)').text()
  floor: parseInt $store.find('.rebirth-arch-infor-block-font:eq(2)').text()
  address: $store.find('.rebirth-arch-infor-block-font:eq(4)').text()
  dangkou_address: $store.find('.rebirth-arch-infor-block-font:eq(4)').text()
  store_name: $store.find('.rebirth-describing-clothes').text().trim()
  see_price: $store.find('.rebirth-arch-infor-block-font:eq(3)').text()
  im_ww: parseImWW $store.find('.rebirth-arch-infor-block a:eq(1)').attr('href')
  shop_http: $store.find('a.rebirth-product-picture').attr('href')

parseImWW = (url) ->
  if !url then return ''
  parts = url.split '&'
  for part in parts
    if ~part.indexOf 'touid='
      return decodeURI part.substr 6
  ''

parseImQQ = (url) ->
  if !url then return ''
  parts = url.split '&'
  for part in parts
    if ~part.indexOf 'uin='
      return part.substr 4
  ''

generateSql = (stores) ->
  sql = ''
  for store in stores
    sql += "call register_store('#{store['qq']}','#{store['mk_name']}','#{store['shop_mall']}','#{store['address']}','#{store['dangkou_address']}','#{store['store_name']}','#{store['see_price']}','#{store['im_ww']}','#{store['shop_http']}');\n"
  sql

fetch 'http://dg.17zwd.com/market.htm'
  .then (body) ->
    makeJsDom body
  .then (window) ->
    $ = jquery window
    stores = []
    $('.rebirth-ks-waterfall').each () ->
      stores.push parseStore $ @
    console.log generateSql stores
    window.close()

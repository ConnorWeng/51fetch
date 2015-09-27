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

fetch 'http://dg.17zwd.com/market.htm'
  .then (body) ->
    makeJsDom body
  .then (window) ->
    $ = jquery window
    stores = []
    $('.rebirth-ks-waterfall').each () ->
      stores.push parseStore $ @
    console.log stores
    window.close()

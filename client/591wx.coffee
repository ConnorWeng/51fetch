{crawl} = require '../src/crawler'

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
    stores
  , (err, data) ->
    console.log data

address = (text) ->
  index = text.indexOf '地址'
  text.substr(index + 3).trim()

extract = (regex) ->
  (url) ->
    matches = url.match regex
    decodeURI matches[1]

qq = extract /uin=(.+?)&/

ww = extract /uid=(.+?)&/

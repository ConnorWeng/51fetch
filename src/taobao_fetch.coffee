http = require 'http'
jsdom = require 'jsdom'
iconv = require 'iconv-lite'
db = require './database.js'
Pool = require('generic-pool').Pool
URL = require 'url'

class taobao_fetch
  constructor: () ->
    @db = new db()
    @stores = []
    @pool = Pool
      name: 'fetch'
      max: 1
      log: true
      create: (callback) =>
        callback null, 1
      destroy: (client) =>
        @pool.drain () =>
          @pool.destroyAllNow()
        @db.end()

  fetchStore: () ->
    @pool.acquire (err, trival) =>
      store = @stores.shift()
      store.fetchedCategoriesCount = 0
      console.log "id:#{store['store_id']} #{store['store_name']}: #{store['shop_http']}"
      @updateStoreCategories store, (err, urls) =>
        if not err and urls isnt null
          clonedUrls = urls.slice 0
          @fetchUrl url, store, clonedUrls for url in urls
        else
          console.error "error in updateStoreCategories of store url: #{store['shop_http']} " + err
          @pool.release()

  updateStoreCategories: (store, callback) ->
    shopUrl = store['shop_http'] + "/search.htm?search=y&orderType=newOn_desc"
    @requestHtmlContent shopUrl, (err, content) =>
      if err or typeof content isnt 'string' or content is ''
        return callback new Error('content cannot be handled by jsdom'), null
      jsdom.env content, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) =>
        if err
          return callback err, null
        $ = window.$
        catsTreeHtml = @extractCatsTreeHtml $, store
        if catsTreeHtml is '' then return callback new Error('catsTreeHtml is empty'), null
        @db.updateStoreCateContent store['store_id'], store['store_name'], catsTreeHtml
        urls = []
        $('a.cat-name').each () ->
          url = $(this).attr('href')
          if urls.indexOf(url) is -1 and url.indexOf('category-') isnt -1 and url.indexOf('#bd') is -1 then urls.push url
        callback null, urls

  extractCatsTreeHtml: ($, store) ->
    catsTreeHtml = $('ul.cats-tree').parent().html()
    if catsTreeHtml?
      catsTreeHtml = catsTreeHtml.trim().replace(/\"http.+category-(\d+).+\"/g, '"showCat.php?cid=$1&shop_id=' + store['store_id'] + '"').replace(/\r\n/g, '')
    else
      console.error "id:#{store['store_id']} #{store['store_name']}: catsTreeHtml is empty."
      catsTreeHtml = ''

  fetchUrl: (url, store, urls) ->
    @requestHtmlContent url, (err, content) =>
      if not err
        @extractItemsFromContent content, store, (err, items) =>
          if err
            return console.error "error in extractItemsFromContent of #{store['store_name']} " + err
          filteredItems = @filterItems items
          if filteredItems.length > 0
            @db.saveItems store['store_id'], store['store_name'], filteredItems, url
        @nextPage content, (err, pageUrl) =>
          if err
            @release urls, url
            return console.error "error in nextPage of #{store['store_name']} " + err
          if pageUrl isnt null
            urls.push pageUrl
            @fetchUrl pageUrl, store, urls
          @release urls, url
      else
        console.error "error in fetchUrl: #{url} " + err
        @release urls, url

  filterItems: (unfilteredItems) ->
    items = item for item in unfilteredItems when not ~item.goodsName.indexOf('邮费') and
      not ~item.goodsName.indexOf('运费') and
      not ~item.goodsName.indexOf('淘宝网 - 淘！我喜欢') and
      not ~item.goodsName.indexOf('订金专拍')

  release: (urls, url) ->
    urlIndex = urls.indexOf url
    if ~urlIndex then urls.splice urlIndex, 1
    if urls.length is 0 then @pool.release()

  fetchAllStores: () ->
    @db.getStores '1 order by store_id', (err, stores) =>
      if err
        throw err
      else
        console.log "the amount of all stores are #{stores.length}"
        @stores = stores
        @fetchStore() for store in stores

  requestHtmlContent: (url, callback) ->
    urlObject = URL.parse url
    options =
      host: urlObject.host
      path: urlObject.path
      headers:
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36'
        'Cookie': COOKIE
    result = ''
    req = http.get options, (res) ->
      res.on 'data', (chunk) ->
        result += iconv.decode chunk, 'GBK'
      res.on 'end', () ->
        if ~result.indexOf('共搜索到')
          callback null, result
        else
          throw new Error('Mother Fuck! Banned by Taobao!')
    req.on 'error', (e) ->
      callback e, null

  extractItemsFromContent: (content, store, callback) ->
    if typeof content isnt 'string' or content is ''
      return callback new Error('content cannot be handled by jsdom'), null
    jsdom.env content, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) =>
      if err
        callback err, null
      else
        $ = window.$
        items = []
        $('dl.item').each (index, element) =>
          $item = $(element)
          items.push
            goodsName: $item.find('a.item-name').text()
            defaultImage: $item.find('img').attr('data-ks-lazyload')
            price: @parsePrice $item.find('.c-price').text().trim(), store['see_price']
            goodHttp: $item.find('a.item-name').attr('href')
        callback null, items

  parsePrice: (price, seePrice) ->
    rawPrice = parseFloat price
    if not seePrice? then return rawPrice.toFixed(2)
    if seePrice.indexOf('减半') isnt -1
      (rawPrice / 2).toFixed(2)
    else if seePrice.indexOf('减') is 0
      (rawPrice - parseFloat(seePrice.substr(1))).toFixed(2)
    else if seePrice is '实价'
      rawPrice.toFixed(2)
    else if seePrice.indexOf('*') is 0
      (rawPrice * parseFloat(seePrice.substr(1))).toFixed(2)
    else
      console.error "不支持该see_price: #{seePrice}"
      rawPrice

  nextPage: (content, callback) ->
    if typeof content isnt 'string' or content is ''
      return callback new Error('content cannot be handled by jsdom'), null
    jsdom.env content, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) ->
      if err
        callback err, null
      else
        $ = window.$
        $nextLink = $('a.J_SearchAsync.next')
        if $nextLink.length > 0
          callback null, $nextLink.attr('href')
        else
          callback null, null

COOKIE = 'cna=MducCx8MKHsCAXTufkeemcwX; ali_ab=116.238.129.45.1394980786051.1; tlut=UoLVYyKGaVq%2B1g%3D%3D; swfstore=114820; lzstat_uv=23843579213373517628|2938535@2581747@2879138@2738597@2581762@2945730@2948565@2798379@2043323@3045821@878758@3284827@2581759@2735862@3409697; lzstat_ss=372241850_1_1396108612_2938535|2738920215_0_1396728828_2581747|667090094_16_1394497200_2879138|3956490247_1_1394931215_2738597|2840307835_0_1396642495_2581762|2317322567_1_1395703671_2945730|2143037506_1_1395703671_2948565|2117418829_1_1395703671_2798379|1137297924_1_1395703671_2043323|3290071357_1_1395703671_3045821|1031984101_0_1395582947_878758|200499624_1_1396720198_3284827|1726009250_0_1396728828_2581759|1222205510_0_1396225649_2735862|1442303717_0_1396914461_3409697; l=%E6%B3%A1%E6%B2%AB%E2%98%86%E8%93%9D%E8%8C%B6::1396889263160::11; ck1=; v=0; pnm_cku822=043fCJmZk4PGRVHHxtNZngkZ3k%2BaC52PmgTKQ%3D%3D%7CfyJ6Zyd9OGUtYXYma34iZBU%3D%7CfiB4D15%2BZH9geTp%2FJyN8PDJtLBMbCF4lHw%3D%3D%7CeSRiYjNhIHA3d2k2c2I3cGwtdDZxNHJsOHxuNXFsJnU0ZSZmeTwV%7CeCVoaEARTx5fBxBCGh4fBHAkay1oKXQPQB0XS2JsQnw%3D%7CeyR8C0obRRhEAR9BAApVGANAD0wcXhoQRgIcQBgFTx1ZHF0ZClV8Bw%3D%3D%7CeiJmeiV2KHMvangudmM6eXk%2BAA%3D%3D; _tb_token_=hS96Ba65n; x=e%3D1%26p%3D*%26s%3D0%26c%3D0%26f%3D0%26g%3D0%26t%3D0%26__ll%3D-1%26_ato%3D0; whl=-1%260%260%261397489313819; uc1=lltime=1397488178&cookie14=UoLVYumF%2FhgVAA%3D%3D&existShop=true&cookie16=URm48syIJ1yk0MX2J7mAAEhTuw%3D%3D&cookie21=VFC%2FuZ9ajC0X15Rzt0LhxQ%3D%3D&tag=0&cookie15=U%2BGCWk%2F75gdr5Q%3D%3D; uc3=nk2=D8rzHEM5T7g%3D&id2=UUjRIp4kduQT3Q%3D%3D&vt3=F8dATHtraBA7R9fZXf4%3D&lg2=UtASsssmOIJ0bQ%3D%3D; existShop=MTM5NzQ4OTMxNQ%3D%3D; lgc=liuhaicc; tracknick=liuhaicc; cookie2=96d64c9c38951a732fbaf3aea12dd2da; sg=c02; mt=np=&ci=0_1&cyk=0_0; cookie1=Wvi8dGZQ5IAbiQcK4szR8c%2FlExKdNE1SAZODGYKj95k%3D; unb=2000128480; t=22bc108d7a9e3d3688e85700c4ffccd9; _cc_=URm48syIZQ%3D%3D; tg=4; _l_g_=Ug%3D%3D; _nk_=liuhaicc; cookie17=UUjRIp4kduQT3Q%3D%3D'

module.exports = taobao_fetch

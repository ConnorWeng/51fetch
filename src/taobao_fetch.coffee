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
      max: 5
      create: (callback) =>
        callback null, 1

  fetchStore: () ->
    @pool.acquire (err, trival) =>
      store = @stores.shift()
      store.fetchedCategoriesCount = 0
      shopUrl = store['shop_http'] + "/search.htm?search=y&orderType=newOn_desc"
      console.log "id:#{store['store_id']} #{store['store_name']}: #{shopUrl}"
      @fetchCategoriesUrl shopUrl, (err, urls) =>
        if not err and urls isnt null
          @fetchUrl url, store, urls.length for url in urls
        else
          console.error "error in fetchCategoriesUrl of url: #{shopUrl}"

  fetchCategoriesUrl: (shopUrl, callback) =>
    @requestHtmlContent shopUrl, (err, content) =>
      if err or typeof content isnt 'string' or content is ''
        return callback new Error('content cannot be handled by jsdom'), null
      jsdom.env content, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) ->
        $ = window.$
        urls = []
        $('a.cat-name').each () ->
          url = $(this).attr('href')
          if urls.indexOf(url) is -1 and url.indexOf('category-') isnt -1 and url.indexOf('#bd') is -1 then urls.push url
        callback null, urls

  fetchUrl: (url, store, categoriesCount) ->
    @requestHtmlContent url, (err, content) =>
      if not err
        @extractItemsFromContent content, (err, items) =>
          if not err and items.length > 0
            @db.saveItems store['store_id'], store['store_name'], items, url
          else
            console.error "error in extractItemsFromContent of #{store['store_id']}"
        @nextPage content, (err, url) =>
          if not err and url isnt null
            @fetchUrl url, store, categoriesCount
          else
            store.fetchedCategoriesCount += 1
            if store.fetchedCategoriesCount is categoriesCount
              @pool.release()

  fetchAllStores: () ->
    @db.getStores 'store_id > 10 order by store_id limit 10', (err, stores) =>
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
        'Cookie': 'cna=MducCx8MKHsCAXTufkeemcwX; ali_ab=116.238.129.45.1394980786051.1; tlut=UoLVYyKGaVq%2B1g%3D%3D; swfstore=114820; lzstat_uv=23843579213373517628|2938535@2581747@2879138@2738597@2581762@2945730@2948565@2798379@2043323@3045821@878758@3284827@2581759@2735862@3409697; lzstat_ss=372241850_1_1396108612_2938535|2738920215_0_1396728828_2581747|667090094_16_1394497200_2879138|3956490247_1_1394931215_2738597|2840307835_0_1396642495_2581762|2317322567_1_1395703671_2945730|2143037506_1_1395703671_2948565|2117418829_1_1395703671_2798379|1137297924_1_1395703671_2043323|3290071357_1_1395703671_3045821|1031984101_0_1395582947_878758|200499624_1_1396720198_3284827|1726009250_0_1396728828_2581759|1222205510_0_1396225649_2735862|1442303717_0_1396914461_3409697; l=%E6%B3%A1%E6%B2%AB%E2%98%86%E8%93%9D%E8%8C%B6::1396889263160::11; ck1=; v=0; uc3=nk2=D8rzHEM5T7g%3D&id2=UUjRIp4kduQT3Q%3D%3D&vt3=F8dHqR%2Fxpe4YN3R5Cbw%3D&lg2=URm48syIIVrSKA%3D%3D; existShop=MTM5NzM1ODM4Ng%3D%3D; lgc=liuhaicc; tracknick=liuhaicc; sg=c02; cookie2=96d64c9c38951a732fbaf3aea12dd2da; cookie1=Wvi8dGZQ5IAbiQcK4szR8c%2FlExKdNE1SAZODGYKj95k%3D; unb=2000128480; t=22bc108d7a9e3d3688e85700c4ffccd9; _cc_=U%2BGCWk%2F7og%3D%3D; tg=4; _l_g_=Ug%3D%3D; _nk_=liuhaicc; cookie17=UUjRIp4kduQT3Q%3D%3D; mt=ci=0_1&cyk=0_0; pnm_cku822=094fCJmZk4PGRVHHxtNZngkZ3k%2BaC52PmgTKQ%3D%3D%7CfyJ6Zyd9OGIna34hY3ImYhM%3D%7CfiB4D15%2BZH9geTp%2FJyN8PDJtLBMbCF4lHw%3D%3D%7CeSRiYjNhIHA3cGM8e2U%2FfGgrcjB3P35hN3ZlMXVsL3Q0ZC1oeTwV%7CeCVoaEASTBNWFR9LExdSewxdY0w%3D%7CeyR8C0obRRhEAR5JDAZZFAxLBEcXVREbTQkXSxMORBZSF1YSAV53DA%3D%3D%7CeiJmeiV2KHMvangudmM6eXk%2BAA%3D%3D; _tb_token_=hS96Ba65n; uc1=lltime=1397119791&cookie14=UoLVYu5CuFQTag%3D%3D&existShop=true&cookie16=URm48syIJ1yk0MX2J7mAAEhTuw%3D%3D&cookie21=UtASsssmfavW4WY1P7uXzg%3D%3D&tag=0&cookie15=V32FPkk%2Fw0dUvg%3D%3D; x=e%3D1%26p%3D*%26s%3D0%26c%3D0%26f%3D0%26g%3D0%26t%3D0%26__ll%3D-1%26_ato%3D0; whl=-1%260%260%260'
    result = ''
    http.get options, (res) ->
      res.on 'data', (chunk) ->
        result += iconv.decode chunk, 'GBK'
      res.on 'end', () ->
        callback null, result

  extractItemsFromContent: (content, callback) ->
    if typeof content isnt 'string' or content is ''
      return callback new Error('content cannot be handled by jsdom'), null
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

  nextPage: (content, callback) ->
    if typeof content isnt 'string' or content is ''
      return callback new Error('content cannot be handled by jsdom'), null
    jsdom.env content, ['http://libs.baidu.com/jquery/1.7.2/jquery.min.js'], (err, window) ->
      $ = window.$
      $nextLink = $('a.J_SearchAsync.next')
      if $nextLink.length > 0
        callback null, $nextLink.attr('href')
      else
        callback null, null

module.exports = taobao_fetch

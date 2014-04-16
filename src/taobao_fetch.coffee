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
    store = @stores.shift()
    store.fetchedCategoriesCount = 0
    console.log "id:#{store['store_id']} #{store['store_name']}: #{store['shop_http']}"
    @updateStoreCategories store, (err, urls) =>
      if not err and urls isnt null
        @fetchUrl url, store for url in urls
      else
        console.error "error in updateStoreCategories of store url: #{store['shop_http']} " + err

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

  fetchUrl: (url, store) ->
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
            return console.error "error in nextPage of #{store['store_name']} " + err
          if pageUrl isnt null
            @fetchUrl pageUrl, store
      else
        console.error "error in fetchUrl: #{url} " + err

  filterItems: (unfilteredItems) ->
    items = item for item in unfilteredItems when not ~item.goodsName.indexOf('邮费') and
      not ~item.goodsName.indexOf('运费') and
      not ~item.goodsName.indexOf('淘宝网 - 淘！我喜欢') and
      not ~item.goodsName.indexOf('订金专拍')

  fetchAllStores: () ->
    @db.getStores '1 order by store_id', (err, stores) =>
      if err
        throw err
      else
        console.log "the amount of all stores are #{stores.length}"
        @stores = stores
        @fetchStore() for store in stores

  requestHtmlContent: (url, callback) ->
    @pool.acquire (err, trival) =>
      urlObject = URL.parse url
      options =
        host: urlObject.host
        path: urlObject.path
        headers:
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36'
          'Cookie': COOKIE
      result = ''
      req = http.get options, (res) =>
        res.on 'data', (chunk) =>
          result += iconv.decode chunk, 'GBK'
        res.on 'end', () =>
          if ~result.indexOf('共搜索到')
            callback null, result
            @pool.release()
          else
            throw new Error('Mother Fuck! Banned by Taobao!')
      req.on 'error', (e) =>
        callback e, null
        @pool.release()

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

COOKIE = 'cna=S2WXC+fHUhYCAbSc2MWOXx5g; miid=3533271021856440951; ali_ab=180.156.216.197.1393591678240.9; l=donyzjz::1393599356505::11; lzstat_uv=229541500245354180|2185014@3203012@3201199@2945730@2948565@2798379@2043323@3045821@3035619@3296882@2468846@2581762@3328751@3258589@2945527@3241813@3313950@2581747@3284827@2581759@2938535@2938538; swfstore=267015; pnm_cku822=206fCJmZk4PGRVHHxtEb3EtbnA3YSd%2FN2EaIA%3D%3D%7CfyJ6Zyd9OGcmZHUgbXMoaBk%3D%7CfiB4D15%2BZH9geTp%2FJyN8PDJtLAkJFwdOXlldbEU%3D%7CeSRiYjNhIHA3dWIzcGQxfWYheDp9P3htOHhmPHhtLXs5aSBgdCB2DQ%3D%3D%7CeCVoaEATTRBRFB5ICAJMQF0GBx9fFBMEOD0pbT4wHiA%3D%7CeyR8C0gHRQBBBhVCGghWEQ9QAkMcWgITQg4EWR4EQQ5LFFx1Dg%3D%3D%7CeiJmeiV2KHMvangudmM6eXk%2BAA%3D%3D; ck1=; v=0; uc3=nk2=Bd%2Frxju0jn%2BI&id2=WvSbKy6Bv9JM&vt3=F8dATHtpus2qisBF3Tc%3D&lg2=URm48syIIVrSKA%3D%3D; existShop=MTM5NzYzNTAyNQ%3D%3D; lgc=foamtea30; tracknick=foamtea30; sg=07f; cookie2=dd6e7a2f9666fc9ebfa1b08bbcd794bb; cookie1=WvTMI201ZCduk1QIN6WIx6JVHxof9tvFegN7Jh9HkL0%3D; unb=944209017; t=61e67613e903af98c4eedf4211a3ae5c; _cc_=URm48syIZQ%3D%3D; tg=0; _l_g_=Ug%3D%3D; _nk_=foamtea30; cookie17=WvSbKy6Bv9JM; mt=ci=0_1&cyk=0_0; _tb_token_=37b3bb84f7534; x=e%3D1%26p%3D*%26s%3D0%26c%3D0%26f%3D0%26g%3D0%26t%3D0%26__ll%3D-1; uc1="lltime=1397616723&cookie14=UoLVYuvPCQ4r7A%3D%3D&existShop=false&cookie16=VT5L2FSpNgq6fDudInPRgavC%2BQ%3D%3D&cookie21=Vq8l%2BKCLiYXzG52e&tag=0&cookie15=V32FPkk%2Fw0dUvg%3D%3D"; whl=-1%260%260%261397635033272'

module.exports = taobao_fetch

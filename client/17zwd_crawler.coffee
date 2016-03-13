{startCrawl} = require '../src/crawler.coffee'
Q = require 'q'
Database = require '../src/database'
config = require '../src/config'

db = new Database config.database['ecmall51_2']
query = Q.nbind db.query, db

modelMap =
  storesPageModel:
    handler: (storesPage) ->
      console.log storesPage.stores.length
      sql = ''
      for store in storesPage.stores
        storeName = if ~store.name.indexOf('alt') then /alt="(.+)" width/g.exec(store.name)[1] else /clothes">(.+)<\/div>/g.exec(store.name)[1]
        imQQ = /uin=(.*)&amp;site/g.exec(store.im.split('\n')[2])[1]
        imWW = decodeURI(/touid=(.+)&amp;site/g.exec(store.im.split('\n')[5])[1])
        sql += "insert into ecm_store_17zwd(store_name,address,im_ww,im_qq,shop_mall,floor,see_price) values('#{storeName}', '#{store.dangkou}', '#{imWW}', '#{imQQ}', '#{store.shopMall}', '#{store.floor}', '#{store.seePrice}');"
      console.log storesPage.url
      query sql
    stores:
      selector: '.florid-ks-waterfall'
      type: 'list'
      itemType: 'element'
      item:
        name:
          selector: '.florid-product-picture'
          type: 'html'
        shopMall:
          selector: '.florid-arch-infor-block-font:eq(0)'
          type: 'text'
        floor:
          selector: '.florid-arch-infor-block-font:eq(1)'
          type: 'text'
        dangkou:
          selector: '.florid-arch-infor-block-font:eq(2)'
          type: 'text'
        seePrice:
          selector: '.florid-arch-infor-block-font:eq(4)'
          type: 'text'
        im:
          selector: '.florid-arch-infor-block:eq(5)'
          type: 'html'
        detail:
          selector: '.florid-product-picture'
          type: 'link'
          condition: -> true
          transform: (url) ->
            'http://gz.17zwd.com' + url
          fetch: 'detailsPageModel'
  detailsPageModel:
    handler: (detailsPage) ->
      shopHttp = 'http:' + detailsPage.shopHttp
      tel = detailsPage.tel.split(' ')[0]
      imWW = detailsPage.imWW
      storeName = detailsPage.storeName
      console.log "update ecm_store_17zwd set tel='#{tel}', shop_http='#{shopHttp}' where im_ww='#{imWW}' and store_name='#{storeName}'"
      query "update ecm_store_17zwd set tel='#{tel}', shop_http='#{shopHttp}' where im_ww='#{imWW}' and store_name='#{storeName}'"
    shopHttp:
      selector: '.florid-goods-details-taobao-enter a'
      type: 'link'
      condition: -> false
    tel:
      selector: '.figure-server-right:eq(2)'
      type: 'text'
    imWW:
      selector: '.figure-server-right:eq(1) a'
      type: 'text'
    storeName:
      selector: '.figure-parameter-item:eq(0)'
      type: 'text'

startCrawl 'http://gz.17zwd.com/market.htm?page=' + i, modelMap, modelMap.storesPageModel for i in [1..83]

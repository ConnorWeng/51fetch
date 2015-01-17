{startCrawl} = require '../src/crawler.coffee'
Q = require 'q'
Database = require '../src/database'
config = require '../src/config'
args = process.argv.slice 2

db = new Database config.database['nt']
query = Q.nbind db.query, db

getCidFrom = (url) ->
  url.match(/cid=(\d+)&?/)[1]

getPidFrom = (url) ->
  url.match(/pid=(\d+)&?/)?[1] || false

modelMap =
  categoryPageModel:
    handler: (categoryPage) ->
      cid = getCidFrom categoryPage.url
      pid = getPidFrom categoryPage.url
      if pid and pid isnt cid
        sql = "replace into ecm_gcategory(cate_id, store_id, cate_name, parent_id) values (#{pid}, 0, '#{categoryPage.parentCate}', 0); replace into ecm_gcategory(cate_id, store_id, cate_name, parent_id) values (#{cid}, 0, '#{categoryPage.cate}', #{pid});"
      else
        sql = "replace into ecm_gcategory(cate_id, store_id, cate_name, parent_id) values (#{cid}, 0, '#{categoryPage.cate}', 0);"
      for good in categoryPage.goods
        console.log "category: before insert {'#{good.goodsName}', '#{good.defaultImage}', '#{good.goodHttp}', #{pid}, #{cid}}"
        if pid
          sql += "insert into ecm_goods(store_id, goods_name, default_image, good_http, cate_id_1, cate_id_2, price) values ((select store_id from ecm_store where im_qq='#{good.imQq}' limit 1), '#{good.goodsName}', '#{good.defaultImage}', '#{good.goodHttp}', #{pid}, #{cid}, '100');"
        else
          sql += "insert into ecm_goods(store_id, goods_name, default_image, good_http, cate_id_1, price) values ((select store_id from ecm_store where im_qq='#{good.imQq}' limit 1), '#{good.goodsName}', '#{good.defaultImage}', '#{good.goodHttp}', #{cid}, '100');"
      query sql
    next:
      selector: 'div#pages span ~ a:eq(0)'
      type: 'link'
      fetch: 'categoryPageModel'
      condition: ($) ->
        $(modelMap.categoryPageModel.next.selector).text() isnt '下一页'
    cate:
      selector: '.item_table tr:eq(0) td:eq(1) a.on:eq(1)'
      type: 'text'
    parentCate:
      type: 'custom'
      get: ($) ->
        pid = getPidFrom $(modelMap.categoryPageModel.cateUrl.selector).attr('href')
        if pid
          as = $(".menu_sub > b > a").filter (i, a) ->
            $(a).attr('href') is "http://www.591wx.com/item/index?cid=#{pid}"
          $(as[0]).text()
        else
          ''
    cateUrl:
      selector: '.item_table tr:eq(0) td:eq(1) a.on:eq(1)'
      type: 'link'
      condition: () -> false
    goods:
      selector: '.box_goods'
      type: 'list'
      itemType: 'element'
      item:
        goodsName:
          selector: 'p:eq(0) a'
          type: 'text'
        defaultImage:
          selector: '.box_img img'
          type: 'img'
          transform: (url) ->
            'http://www.591wx.com' + url
        goodHttp:
          selector: 'p:eq(0) a'
          type: 'link'
          fetch: 'detailPageModel'
          condition: () -> true
        imQq:
          selector: 'p:eq(2) a:eq(0)'
          type: 'text'
  detailPageModel:
    handler: (detailPage) ->
      console.log "detail: before insert '#{detailPage.spec1}', '#{detailPage.spec2}'"
      sql = "insert into ecm_goods_spec(goods_id, spec_1, spec_2, price, stock) values ((select goods_id from ecm_goods where good_http = '#{detailPage.url}' limit 1), '#{detailPage.spec1}', '#{detailPage.spec2}', 100, 100);update ecm_goods set default_spec = last_insert_id(), spec_qty = 2, spec_name_1 = '适用床尺寸', spec_name_2 = '颜色分类', description = '#{detailPage.description}' where goods_id = (select t.goods_id from (select goods_id from ecm_goods where good_http = '#{detailPage.url}' limit 1) t);"
      query sql
    description:
      selector: '.content'
      type: 'html'
    spec1:
      selector: '.item_tail_l dd:eq(3) span:eq(0)'
      type: 'text'
    spec2:
      selector: '.item_tail_l dd:eq(5) span:eq(0)'
      type: 'text'

# 之后需要修复主图, 去除store_id为空的宝贝纪录
startCrawl args[0], modelMap, modelMap.categoryPageModel

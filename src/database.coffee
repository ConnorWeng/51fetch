mysql = require 'mysql'
{log, error} = require 'util'
{getHuoHao} = require './taobao_crawler'

class db
  constructor: (databaseConfig) ->
    if databaseConfig? then config = databaseConfig else config =
        host: 'rdsqr7ne2m2ifjm.mysql.rds.aliyuncs.com'
        user: 'wangpi51'
        password: '51374b78b104'
        database: 'wangpi51'
        port: 3306
    config.multipleStatements = true
    @updateStoreCateContentCounter = 0
    @updateImWwCounter = 0
    @clearCidsCounter = 0
    @deleteDelistItemsCounter = 0
    @saveItemsCounter = 0
    @pool = mysql.createPool config

  query: (sql, callback) ->
    @pool.query sql, (err, result) =>
      if err?.code is 'PROTOCOL_CONNECTION_LOST'
        @query sql, callback
      else
        callback err, result

  runSql: (sql, callback) ->
    @query sql, (err, result) ->
      callback err, result

  getStores: (condition, callback) ->
    @query "select * from ecm_store where #{condition}", (err, result) ->
      callback err, result

  getUnfetchedStores: (callback) ->
    @query "select * from ecm_store s where not exists (select 1 from ecmall51_2.ecm_store s2 where s2.shop_mall = s.shop_mall and s2.address = s.address and s2.floor = s.floor) and not exists (select 1 from ecmall51_2.ecm_store s2 where s2.im_qq = s.im_qq) order by s.store_id", (err, result) ->
      callback err, result

  getUnfetchedGoods: (callback) ->
    @query "select * from ecm_goods g where g.good_http is not null and not exists (select 1 from ecm_goods_spec s where s.goods_id = g.goods_id)", (err, result) ->
      callback err, result

  getUnfetchedGoodsInStore: (storeId, callback) ->
    @query "select * from ecm_goods g where g.store_id = #{storeId} and g.good_http is not null and not exists (select 1 from ecm_goods_spec s where s.goods_id = g.goods_id)", (err, result) ->
      callback err, result

  getGoodsWithRemoteImage: (callback) ->
    @query "select * from ecm_goods g where g.default_image like '%taobaocdn.com%'", (err, result) ->
      callback err, result

  getGood: (goodHttp, callback) ->
    @query "select * from ecm_goods where good_http = '#{goodHttp}'", (err, result) ->
      if err
        error "error in getGood: #{goodHttp}"
      callback err, result[0]

  updateGoods: (goodsId, title, price, taobaoPrice, desc, goodHttp, realPic, skus, defaultImage, sellerCids, callback) ->
    sql = ''
    if sellerCids
      cids = sellerCids.split ','
      for cid in cids
        if cid then sql += "replace into ecm_category_goods(cate_id, goods_id) values (#{cid}, #{goodsId});"
    specName1 = skus[0]?[0]?.name || ''
    specName2 = skus[0]?[1]?.name || ''
    specPid1 = skus[0]?[0]?.pid || 0
    specPid2 = skus[0]?[1]?.pid || 0
    specQty = skus[0]?.length || 0
    sql += "update ecm_goods set goods_name = #{@pool.escape(title)}, price = #{price}, taobao_price = #{taobaoPrice}, description = '#{desc}', spec_name_1 = '#{specName1}', spec_name_2 = '#{specName2}', spec_pid_1 = #{specPid1}, spec_pid_2 = #{specPid2}, spec_qty = #{specQty}, realpic = #{realPic}, default_image = '#{defaultImage}' where good_http = '#{goodHttp}'"
    @query sql, (err, result) ->
      if err
        error "error in update goods: #{goodHttp}"
      callback err, result

  updateCats: (goodsId, storeId, cats, callback) ->
    sql = ''
    gcategorySql = ''
    goodsSql = ''
    cateSql = ''
    cat = cats.pop()
    gcategorySql = "insert into ecm_gcategory(cate_id, store_id, cate_name, parent_id) values (#{cat.cid}, 0, '#{cat.name}', #{cat.parent_cid}) on duplicate key update store_id = 0, cate_name = '#{cat.name}', parent_id = #{cat.parent_cid};"
    goodsSql = "update ecm_goods set cate_id_1 = #{cat.cid}"
    i = 1
    while cats.length > 0
      cat = cats.pop()
      cateId = cat.cid
      cateName = cat.name
      parentCid = cat.parent_cid
      gcategorySql += "insert into ecm_gcategory(cate_id, store_id, cate_name, parent_id) values (#{cateId}, 0, '#{cateName}', #{parentCid}) on duplicate key update store_id = 0, cate_name = '#{cateName}', parent_id = #{parentCid};"
      goodsSql += ", cate_id_#{++i} = #{cateId}"
      if cats.length is 0
        cateSql = "update ecm_goods set cate_id = #{cat.cid} where goods_id = #{goodsId};"
    goodsSql += " where goods_id = #{goodsId};"
    sql = gcategorySql + goodsSql + cateSql
    @query sql, (err, result) ->
      callback err, result

  updateDefaultSpec: (goodsId, specId, callback) ->
    @query "update ecm_goods set default_spec = #{specId} where goods_id = #{goodsId}", (err, result) ->
      if err
        error "error in update default spec, goodsId:#{goodsId}, specId:#{specId}"
      callback err, result

  updateSpecs: (skus, goodsId, price, taobaoPrice, huohao, callback) ->
    insertSql = ''
    # FIXME: if skus is undefined then quantity should get value from item instead
    quantity = 1000
    for sku in skus
      spec1 = sku[0]?.value
      spec2 = sku[1]?.value || ''
      specVid1 = sku[0]?.vid || 0
      specVid2 = sku[1]?.vid || 0
      quantity = sku[0]?.quantity || 1000
      insertSql += "insert into ecm_goods_spec(goods_id, spec_1, spec_2, spec_vid_1, spec_vid_2, price, stock, sku, taobao_price) values ('#{goodsId}', '#{spec1}', '#{spec2}', #{specVid1}, #{specVid2}, #{sku[0]?.price || price}, #{quantity}, '#{huohao}', #{sku[0]?.taobaoPrice || taobaoPrice});"
    if insertSql is ''
      insertSql = "insert into ecm_goods_spec(goods_id, spec_1, spec_2, spec_vid_1, spec_vid_2, price, stock, sku, taobao_price) values ('#{goodsId}', '', '', 0, 0, #{price}, #{quantity}, '#{huohao}', #{taobaoPrice});"
    @query insertSql, (err, result) ->
      if err
        error "error in updateSpecs, goodsId:#{goodsId}"
      callback err, result

  deleteSpecs: (goodsId, callback) ->
    @query "delete from ecm_goods_spec where goods_id = #{goodsId}", (err, result) ->
      callback err, result

  updateStoreCateContent: (storeId, storeName, cateContent) ->
    @updateStoreCateContentCounter += 1
    @query "update ecm_store set cate_content='#{cateContent}' where store_id = #{storeId}", (err, result) =>
      @updateStoreCateContentCounter -= 1
      if err
        return error "error in updateStoreCateContent: #{storeId} #{storeName} " + err
      log "id:#{storeId} #{storeName} updated cate_content."

  updateImWw: (storeId, storeName, imWw) ->
    @updateImWwCounter += 1
    @query "update ecm_store set im_ww = '#{imWw}' where store_id = #{storeId}", (err, result) =>
      @updateImWwCounter -= 1
      if err
        return error "error in updateImWw: #{storeId} #{storeName} #{imWw} " + err
      log "id:#{storeId} #{storeName} updated im_ww #{imWw}."

  updateItemImgs: (goodsId, itemImgs, callback) ->
    sql = "delete from ecm_goods_image where goods_id = #{goodsId};"
    for img, i in itemImgs
      if i is 0
        sql += "insert into ecm_goods_image(goods_id, image_url, thumbnail, sort_order, file_id) select #{goodsId}, '#{img.url}', '#{img.url}_460x460.jpg', (select ifnull(so,0) from (select max(sort_order) + 1 so from ecm_goods_image where goods_id = #{goodsId}) t), 0 from dual where not exists (select 1 from ecm_goods_image where goods_id = #{goodsId});"
      else
        sql += "insert into ecm_goods_image(goods_id, image_url, thumbnail, sort_order, file_id) select #{goodsId}, '#{img.url}', '#{img.url}_460x460.jpg', (select ifnull(so,0) from (select max(sort_order) + 1 so from ecm_goods_image where goods_id = #{goodsId}) t), 0 from dual where not exists (select 1 from ecm_goods_image where goods_id = #{goodsId} and substr(image_url, -56) = substr('#{img.url}', -56));"
    if sql
      @query sql, (err, result) ->
        callback err, result
    else
      callback null, null

  saveItemAttr: (goodsId, attrs, callback) ->
    sql = ''
    for attr in attrs
      {attrId, valueId, attrName, attrValue} = attr
      sql += "replace into ecm_attribute(attr_id, attr_name, input_mode, def_value) values ('#{attrId}', '#{attrName}', 'select', '其他'); insert into ecm_goods_attr(goods_id, attr_name, attr_value, attr_id, value_id) values ('#{goodsId}', '#{attrName}', '#{attrValue}', '#{attrId}', '#{valueId}');"
    @query sql, (err, result) ->
      callback err, result

  deleteItemAttr: (goodsId, callback) ->
    @query "delete from ecm_goods_attr where goods_id = #{goodsId}", (err, result) ->
      callback err, result

  saveItems: (storeId, storeName, items, url, catName, pageNumber, callback) ->
    @saveItemsCounter += 1
    sql = @makeSaveItemSql storeId, storeName, items, @getCidFromUrl(url), catName, pageNumber
    @query sql, (err, result) =>
      @saveItemsCounter -= 1
      if err
        error "error in saveItems: #{err}"
      else
        log "id:#{storeId} #{storeName} is fetched one page: #{@getCidFromUrl url} counts: #{items.length}."
      callback err, result

  clearCids: (storeId, callback) ->
    @clearCidsCounter += 1
    @query "update ecm_goods set cids = '' where store_id = #{storeId}", (err, result) =>
      @clearCidsCounter -= 1
      callback err, result

  deleteDelistItems: (storeId, totalItemsCount, callback) ->
    @deleteDelistItemsCounter += 1
    @query "select count(1) totalCount from ecm_goods where store_id = #{storeId};select count(1) delistCount from ecm_goods where store_id = #{storeId} and last_update < #{@oneHourAgo()}", (err, results) =>
      totalCount = parseInt(results[0][0]['totalCount'])
      delistCount = parseInt(results[1][0]['delistCount'])
      if delistCount > 0
        @query "call delete_goods(#{@oneHourAgo()}, #{storeId}, #{storeId+1}, @o_count)", (err, result) =>
          if err then error "call delete_goods(#{@oneHourAgo()}, #{storeId}, #{storeId+1}, @o_count)"
          @deleteDelistItemsCounter -= 1
          log "id:#{storeId} totalCount:#{totalCount} delistedCount: #{result[0][0].o_count} totalItemsCount:#{totalItemsCount}"
          callback err, result
      else
        @deleteDelistItemsCounter -= 1
        log "id:#{storeId} totalCount:#{totalCount} delistCount:#{delistCount} totalItemsCount:#{totalItemsCount}"
        callback null, null

  buildOuterIid: (storeId, callback) ->
    @query "call build_outer_iid(#{storeId}, #{(parseInt storeId) + 1})", (err, result) ->
      callback err, result

  makeSaveItemSql: (storeId, storeName, items, cid, catName, pageNumber) ->
    sql = ''
    time = @getDateTime() - pageNumber * 60 # 每一页宝贝的time都倒退1分钟，保证最终add_time是按照新款排序的
    if catName isnt '所有宝贝'
      sql += "insert into ecm_gcategory(cate_id, store_id, cate_name, if_show) values ('#{cid}', '#{storeId}', '#{catName}', 1) on duplicate key update store_id = '#{storeId}', cate_name = '#{catName}', if_show = 1;"
    for item, i in items
      sql += "call proc_merge_good('#{storeId}','#{item.defaultImage}','#{item.price}','#{item.taobaoPrice}','#{item.goodHttp}','#{cid}','#{storeName}',#{@pool.escape(item.goodsName)},'#{time-i}','#{catName}','#{getHuoHao(item.goodsName)}',@o_retcode);"
    sql

  updateCategories: (storeId, cats, callback) ->
    if cats and storeId > 5000
      sql = "delete from ecm_gcategory where store_id = #{storeId} and cate_mname is null;"
    else
      sql = ''
    for cat in cats
      sql += "insert into ecm_gcategory(cate_id, parent_id, store_id, sort_order, cate_name, if_show) values ('#{cat.cid}', '#{cat.parent_cid}', '#{storeId}', '#{cat.sort_order}', '#{cat.name}', 1) on duplicate key update parent_id = '#{cat.parent_cid}', store_id = '#{storeId}', sort_order = '#{cat.sort_order}', cate_name = '#{cat.name}', if_show = 1;"
    @query sql, (err, result) ->
      callback err, result

  getCidFromUrl: (url) ->
    url.match(/category-(\w+)(-\w+)?.htm/)?[1] || ''

  getDateTime: () ->
    date = new Date()
    dateTime = parseInt(date.getTime() / 1000)
    dateTime

  todayZeroTime: ->
    date = new Date
    date.setHours 0
    date.setMinutes 0
    dateTime = parseInt(date.getTime() / 1000)
    dateTime

  oneHourAgo: ->
    date = new Date
    hour = date.getHours()
    date.setHours (hour - 1)
    dateTime = parseInt(date.getTime() / 1000)
    dateTime

  end: () ->
    @pool.end (err) ->
      if err
        error "error in db.end: " + err
      else
        log "database pool ended."

module.exports = db

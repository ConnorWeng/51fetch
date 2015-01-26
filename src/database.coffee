mysql = require 'mysql'
{log, error} = require 'util'

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

  getUnfetchedGoods: (callback) ->
    @query "select * from ecm_goods g where g.good_http is not null and g.goods_id not in (select goods_id from ecm_goods_spec)", (err, result) ->
      callback err, result

  getGoodsWithRemoteImage: (callback) ->
    @query "select * from ecm_goods g where g.default_image like '%taobaocdn.com%'", (err, result) ->
      callback err, result

  getGood: (goodHttp, callback) ->
    @query "select * from ecm_goods where good_http = '#{goodHttp}'", (err, result) ->
      if err
        error "error in getGood: #{goodHttp}"
      callback err, result[0]

  updateGoods: (desc, goodHttp, realPic, skus, callback) ->
    specName1 = skus[0]?[0]?.name || ''
    specName2 = skus[0]?[1]?.name || ''
    specPid1 = skus[0]?[0]?.pid || 0
    specPid2 = skus[0]?[1]?.pid || 0
    specQty = skus[0]?.length || 0
    @query "update ecm_goods set description = '#{desc}', spec_name_1 = '#{specName1}', spec_name_2 = '#{specName2}', spec_pid_1 = #{specPid1}, spec_pid_2 = #{specPid2}, spec_qty = #{specQty}, realpic = #{realPic} where good_http = '#{goodHttp}'", (err, result) ->
      if err
        error "error in update goods: #{goodHttp}"
      callback err, result

  updateCats: (goodsId, storeId, cats, callback) ->
    sql = ''
    gcategorySql = ''
    goodsSql = ''
    cateSql = ''
    cat = cats.pop()
    gcategorySql = "replace into ecm_gcategory(cate_id, store_id, cate_name, parent_id) values (#{cat.cid}, 0, '#{cat.name}', #{cat.parent_cid});"
    goodsSql = "update ecm_goods set cate_id_1 = #{cat.cid}"
    i = 1
    while cats.length > 0
      cat = cats.pop()
      cateId = cat.cid
      cateName = cat.name
      parentCid = cat.parent_cid
      gcategorySql += "replace into ecm_gcategory(cate_id, store_id, cate_name, parent_id) values (#{cateId}, 0, '#{cateName}', #{parentCid});"
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

  updateSpecs: (skus, goodsId, price, callback) ->
    insertSql = ''
    for sku in skus
      spec1 = sku[0]?.value
      spec2 = sku[1]?.value || ''
      specVid1 = sku[0]?.vid || 0
      specVid2 = sku[1]?.vid || 0
      insertSql += "insert into ecm_goods_spec(goods_id, spec_1, spec_2, spec_vid_1, spec_vid_2, price, stock) values ('#{goodsId}', '#{spec1}', '#{spec2}', #{specVid1}, #{specVid2}, #{price}, 1000);"
    if insertSql is ''
      insertSql = "insert into ecm_goods_spec(goods_id, spec_1, spec_2, spec_vid_1, spec_vid_2, price, stock) values ('#{goodsId}', '', '', 0, 0, #{price}, 1000);"
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

  saveItems: (storeId, storeName, items, url, catName) ->
    @saveItemsCounter += 1
    sql = @makeSaveItemSql storeId, storeName, items, @getCidFromUrl(url), catName
    @query sql, (err, result) =>
      @saveItemsCounter -= 1
      if err
        error "error in saveItems: #{err}"
      else
        log "id:#{storeId} #{storeName} is fetched one page: #{@getCidFromUrl url} counts: #{items.length}."

  clearCids: (storeId, callback) ->
    @clearCidsCounter += 1
    @query "update ecm_goods set cids = '' where store_id = #{storeId}", (err, result) =>
      @clearCidsCounter -= 1
      callback err, result

  deleteDelistItems: (storeId, callback) ->
    @deleteDelistItemsCounter += 1
    @query "delete from ecm_goods where store_id = #{storeId} and last_update < #{@todayZeroTime()}", (err, result) =>
      @deleteDelistItemsCounter -= 1
      callback err, result

  makeSaveItemSql: (storeId, storeName, items, cid, catName) ->
    sql = ''
    if catName isnt '所有宝贝'
      sql += "replace into ecm_gcategory(cate_id, store_id, cate_name, if_show) values ('#{cid}', '#{storeId}', '#{catName}', 1);"
    for item in items
      sql += "call proc_merge_good('#{storeId}','#{item.defaultImage}','#{item.price}','#{item.goodHttp}','#{cid}','#{storeName}','#{item.goodsName}','#{@getDateTime()}','#{catName}',@o_retcode);"
    sql

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

  end: () ->
    @pool.end (err) ->
      if err
        error "error in db.end: " + err
      else
        log "database pool ended."

module.exports = db

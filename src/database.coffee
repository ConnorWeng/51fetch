mysql = require 'mysql'
async = require 'async'

class db
  constructor: (databaseConfig) ->
    if databaseConfig? then config = databaseConfig else config =
        host: 'rdsqr7ne2m2ifjm.mysql.rds.aliyuncs.com'
        user: 'wangpi51'
        password: '51374b78b104'
        database: 'wangpi51'
        port: 3306
    config.multipleStatements = true
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
        console.error "error in getGood: #{goodHttp}"
      callback err, result[0]

  updateGoods: (desc, goodHttp, realPic, skus, callback) ->
    specName1 = skus[0]?[0]?.name || ''
    specName2 = skus[0]?[1]?.name || ''
    specQty = skus[0]?.length || 0
    @query "update ecm_goods set description = '#{desc}', spec_name_1 = '#{specName1}', spec_name_2 = '#{specName2}', spec_qty = #{specQty}, realpic = #{realPic} where good_http = '#{goodHttp}'", (err, result) ->
      if err
        console.error "error in update goods: #{goodHttp}"
      callback err, result

  updateCats: (goodsId, storeId, cats, callback) ->
    sql = ''
    gcategorySql = ''
    goodsSql = ''
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
    goodsSql += " where goods_id = #{goodsId};"
    sql = gcategorySql + goodsSql
    @query sql, (err, result) ->
      callback err, result

  updateDefaultSpec: (goodsId, specId, callback) ->
    @query "update ecm_goods set default_spec = #{specId} where goods_id = #{goodsId}", (err, result) ->
      if err
        console.error "error in update default spec, goodsId:#{goodsId}, specId:#{specId}"
      callback err, result

  updateSpecs: (skus, goodsId, price, callback) ->
    insertSql = ''
    for sku in skus
      spec1 = sku[0]?.value
      spec2 = sku[1]?.value || ''
      insertSql += "insert into ecm_goods_spec(goods_id, spec_1, spec_2, price, stock) values ('#{goodsId}', '#{spec1}', '#{spec2}', #{price}, 1000);"
    if insertSql is ''
      insertSql = "insert into ecm_goods_spec(goods_id, spec_1, spec_2, price, stock) values ('#{goodsId}', '', '', #{price}, 1000);"
    @query insertSql, (err, result) ->
      if err
        console.error "error in updateSpecs, goodsId:#{goodsId}"
      callback err, result

  deleteSpecs: (goodsId, callback) ->
    @query "delete from ecm_goods_spec where goods_id = #{goodsId}", (err, result) ->
      callback err, result

  updateStoreCateContent: (storeId, storeName, cateContent) ->
    @query "update ecm_store set cate_content='#{cateContent}' where store_id = #{storeId}", (err, result) ->
      if err
        return console.error "error in updateStoreCateContent: #{storeId} #{storeName} " + err
      console.log "id:#{storeId} #{storeName} updated cate_content."

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

  saveItems: (storeId, storeName, items, url) ->
    sql = @makeSaveItemSql storeId, storeName, items, @getCidFromUrl url
    @query sql, (err, result) =>
      if err
        console.error "error in saveItems: #{err}"
      else
        console.log "id:#{storeId} #{storeName} is fetched one page: #{@getCidFromUrl url} counts: #{items.length}."

  clearCids: (storeId, callback) ->
    @query "update ecm_goods set cids = '' where store_id = #{storeId}", (err, result) ->
      callback err, result

  deleteDelistItems: (storeId, callback) ->
    @query "delete from ecm_goods where store_id = #{storeId} and last_update < #{@todayZeroTime()}", (err, result) ->
      callback err, result

  makeSaveItemSql: (storeId, storeName, items, cid) ->
    sql = ''
    for item in items
      sql += "call proc_merge_good('#{storeId}','#{item.defaultImage}','#{item.price}','#{item.goodHttp}','#{cid}','#{storeName}','#{item.goodsName}','#{@getDateTime()}',@o_retcode);"
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
        console.error "error in db.end: " + err
      else
        console.log "database pool ended."

module.exports = db

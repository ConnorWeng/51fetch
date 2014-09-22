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

  runSql: (sql, callback) ->
    @pool.query sql, (err, result) ->
      callback err, result

  getStores: (condition, callback) ->
    @pool.query "select * from ecm_store where #{condition}", (err, result) ->
      callback err, result

  getUnfetchedGoods: (callback) ->
    @pool.query "select * from ecm_goods g where g.good_http is not null and g.goods_id not in (select goods_id from ecm_goods_spec)", (err, result) ->
      callback err, result

  getGoodsWithRemoteImage: (callback) ->
    @pool.query "select * from ecm_goods g where g.default_image like '%taobaocdn.com%'", (err, result) ->
      callback err, result

  getGood: (goodHttp, callback) ->
    @pool.query "select * from ecm_goods where good_http = '#{goodHttp}'", (err, result) ->
      if err
        console.error "error in getGood: #{goodHttp}"
      callback err, result[0]

  updateGoods: (desc, goodHttp, callback) ->
    @pool.query "update ecm_goods set description = '#{desc}', spec_name_1 = '颜色', spec_name_2 = '尺码', spec_qty = 2 where good_http = '#{goodHttp}'", (err, result) ->
      if err
        console.error "error in update goods: #{goodHttp}"
      callback err, result

  updateCats: (goodsId, storeId, cats, callback) ->
    sql = "update ecm_goods set cate_id_1 = #{cats.pop().cid}"
    i = 1
    while cats.length > 0
      cat = cats.pop()
      cateId = cat.cid
      cateName = cat.name
      parentCid = cat.parent_cid
      sql += ", cate_id_#{++i} = #{cateId}"
    sql += " where goods_id = #{goodsId}"
    @pool.query sql, (err, result) ->
      callback err, result

  updateDefaultSpec: (goodsId, specId, callback) ->
    @pool.query "update ecm_goods set default_spec = #{specId} where goods_id = #{goodsId}", (err, result) ->
      if err
        console.error "error in update default spec, goodsId:#{goodsId}, specId:#{specId}"
      callback err, result

  updateSpecs: (skus, goodsId, price, callback) ->
    insertSql = ''
    for sku in skus
      insertSql += "insert into ecm_goods_spec(goods_id, spec_1, spec_2, price, stock) values ('#{goodsId}', '#{sku[0]}', '#{sku[1]}',#{price}, 1000);"
    if insertSql isnt ''
      @pool.query insertSql, (err, result) ->
        if err
          console.error "error in updateSpecs, goodsId:#{goodsId}"
        callback err, result
    else
      callback null, null

  deleteSpecs: (goodsId, callback) ->
    @pool.query "delete from ecm_goods_spec where goods_id = #{goodsId}", (err, result) ->
      callback err, result

  updateStoreCateContent: (storeId, storeName, cateContent) ->
    @pool.query "update ecm_store set cate_content='#{cateContent}' where store_id = #{storeId}", (err, result) ->
      if err
        return console.error "error in updateStoreCateContent: #{storeId},#{cateContent} " + err
      console.log "id:#{storeId} #{storeName} updated cate_content."

  saveItemAttr: (goodsId, attrs, callback) ->
    sql = ''
    for attr in attrs
      {attrId, attrName, attrValue} = attr
      sql += "replace into ecm_attribute(attr_id, attr_name, input_mode, def_value) values ('#{attrId}', '#{attrName}', 'text', '其他'); insert into ecm_goods_attr(goods_id, attr_name, attr_value, attr_id) values ('#{goodsId}', '#{attrName}', '#{attrValue}', '#{attrId}');"
    @pool.query sql, (err, result) ->
      callback err, result

  deleteItemAttr: (goodsId, callback) ->
    @pool.query "delete from ecm_goods_attr where goods_id = #{goodsId}", (err, result) ->
      callback err, result

  saveItems: (storeId, storeName, items, url) ->
    sql = @makeSaveItemSql storeId, storeName, items, @getCidFromUrl url
    @pool.query sql, (err, result) =>
      if err
        console.error "error in saveItems: #{err}"
      else
        console.log "id:#{storeId} #{storeName} is fetched one page: #{@getCidFromUrl url}."

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

  end: () ->
    @pool.end (err) ->
      if err
        console.error "error in db.end: " + err
      else
        console.log "database pool ended."

module.exports = db

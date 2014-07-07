mysql = require 'mysql'
async = require 'async'

class db
  constructor: (databaseConfig) ->
    if databaseConfig? then config = databaseConfig else config =
        host: 'localhost'
        user: 'root'
        password: '57826502'
        database: 'test2'
        port: 3306
    config.multipleStatements = true
    @pool = mysql.createPool config

  getStores: (condition, callback) ->
    @pool.query "select * from ecm_store where #{condition}", (err, result) ->
      callback err, result

  getUnfetchedGoods: (callback) ->
    @pool.query "select * from ecm_goods g where g.goods_id not in (select goods_id from ecm_goods_spec)", (err, result) ->
      callback err, result

  getGood: (goodHttp, callback) ->
    @pool.query "select * from ecm_goods where good_http = '#{goodHttp}'", (err, result) ->
      if err
        console.error "error in getGood: #{goodHttp}"
      callback err, result[0]

  updateGoods: (desc, goodHttp, callback) ->
    @pool.query "update ecm_goods set description = '#{desc}', spec_name_1 = '颜色', spec_name_2 = '尺码' where good_http = '#{goodHttp}'", (err, result) ->
      if err
        console.error "error in update goods: #{goodHttp}"
      callback err, result

  updateSpecs: (skus, goodsId, price, callback) ->
    insertSql = ''
    for sku in skus
      insertSql += "insert into ecm_goods_spec(goods_id, spec_1, spec_2, price, stock) values ('#{goodsId}', '#{sku[0]}', '#{sku[1]}',#{price}, 1000);"
    @pool.query insertSql, callback

  updateStoreCateContent: (storeId, storeName, cateContent) ->
    @pool.query "update ecm_store set cate_content='#{cateContent}' where store_id = #{storeId}", (err, result) ->
      if err
        return console.error "error in updateStoreCateContent: #{storeId},#{cateContent} " + err
      console.log "id:#{storeId} #{storeName} updated cate_content."

  saveItems: (storeId, storeName, items, url) ->
    sql = @makeSaveItemSql storeId, storeName, items, @getCidFromUrl url
    @pool.query sql, (err, result) =>
      if err
        console.error "error in saveItems: #{sql}"
      else
        console.log "id:#{storeId} #{storeName} is fetched one page: #{@getCidFromUrl url}."

  makeSaveItemSql: (storeId, storeName, items, cid) ->
    sql = ''
    for item in items
      sql += "call proc_merge_good('#{storeId}','#{item.defaultImage}','#{item.price}','#{item.goodHttp}','#{cid}','#{storeName}','#{item.goodsName}','#{@getDateTime()}',@o_retcode);"
    sql

  getCidFromUrl: (url) ->
    url.match(/category-(\w+)(-\w+)?.htm/)[1]

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

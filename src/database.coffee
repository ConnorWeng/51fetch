mysql = require 'mysql'

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

  saveItems: (storeId, storeName, items) ->
    sql = @makeSaveItemSql storeId, storeName, items
    @pool.query sql, (err, result) ->
      if err then throw err else console.log "#{storeName} is fetched one page."

  makeSaveItemSql: (storeId, storeName, items) ->
    sql = ''
    for item in items
      sql += "call proc_merge_good('#{storeId}','#{item.defaultImage}','#{item.price}','#{item.goodHttp}','#{@getDateTime()}','#{storeName}','#{item.goodsName}','',@o_retcode);"
    sql

  getDateTime: () ->
    date = new Date()
    dateTime = parseInt(date.getTime() / 1000)
    ''

module.exports = db

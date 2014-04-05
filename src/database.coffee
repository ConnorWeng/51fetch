mysql = require 'mysql'

class db
  constructor: (databaseConfig) ->
    if databaseConfig? then config = databaseConfig else config =
        host: 'localhost'
        user: 'root'
        password: '57826502'
        database: 'test2'
        port: 3306
    @pool = mysql.createPool config

  getStores: (condition, callback) ->
    @pool.query "select * from ecm_store where #{condition}", (err, result) ->
      callback err, result

  saveItems: (store, items, callback) ->
    console.log store
    console.log items

module.exports = db

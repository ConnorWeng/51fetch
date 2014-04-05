mysql = require 'mysql'

class db
  constructor: (databaseConfig) ->
    if databaseConfig?
      @databaseConfig = databaseConfig
    else
      @databaseConfig =
        host: 'localhost'
        user: 'root'
        password: '57826502'
        database: 'test2'
        port: 3306

  getStores: (condition, callback) ->
    connection = mysql.createConnection @databaseConfig
    connection.query "select * from ecm_store where #{condition}", (err, result) ->
      connection.end()
      callback err, result

  saveItems: (store, items, callback) ->
    console.log store
    console.log items

module.exports = db

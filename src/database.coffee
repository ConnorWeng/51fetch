mysql = require 'mysql'

module.exports = (databaseConfig) ->
  getStores: (condition, callback) ->
    connection = mysql.createConnection databaseConfig
    connection.query "select * from ecm_store where #{condition}", (err, result) ->
      connection.end()
      callback err, result

  saveItems: (store, items, callback) ->
    console.log store
    console.log items

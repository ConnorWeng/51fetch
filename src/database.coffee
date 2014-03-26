mysql = require 'mysql'

module.exports = (databaseConfig) ->
  getStores: (condition, callback) ->
    connection = mysql.createConnection databaseConfig
    connection.query "select * from ecm_store where #{condition}", callback

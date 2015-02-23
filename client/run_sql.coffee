database = require '../src/database'
config = require '../src/config'
args = process.argv.slice 2

db = new database(config.database[args[0]])

db.runSql args[1], (err, result) ->
  console.log result

{log} = require 'util'

exports.log = log
exports.error = (err) ->
  console.error err
  console.error 'stack info: ' + err.stack
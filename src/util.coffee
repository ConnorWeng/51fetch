{log, inspect} = require 'util'

exports.log = log
exports.error = (err) ->
  console.error err
  console.error 'stack info: ' + err.stack
exports.debug = (msg) ->
  if process.env.NODE_ENV is 'debug' or process.env.NODE_ENV is 'trace'
    console.log msg
exports.trace = (msg) ->
  if process.env.NODE_ENV is 'trace'
    console.log '**********trace output start**********'
    console.log msg
    console.log '**********trace output end**********'

exports.inspect = inspect

fs = require 'fs'
path = require 'path'

content = fs.readFileSync path.resolve __dirname, '../config.json'
config = JSON.parse content

module.exports = config

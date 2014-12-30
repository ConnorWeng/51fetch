http = require 'http'
url = require 'url'
querystring = require 'querystring'
{log, error} = require 'util'
{crawl} = require '../src/crawler'

args = process.argv.slice 2

http.createServer((req, res) ->
  args = url.parse(req.url).query
  argsObj = querystring.parse(args)
  crawl argsObj['url'], 'raw', (err, html) ->
    if err
      error err
    else
      res.writeHead 200,
        'Content-Type': 'text/plain'
      res.end html
).listen 8989

db = require './database.js'
assert = require('chai').assert

databaseConfig =
  host: 'localhost'
  user: 'root'
  password: '57826502'
  database: 'test2'
  port: 3306

describe 'database', () ->
  describe '#getStores()', () ->
    it 'should return store correctly', (done) ->
      db(databaseConfig).getStores 'store_id = 1 limit 1', (err, stores) ->
        assert.equal stores[0].store_id, '1'
        done()

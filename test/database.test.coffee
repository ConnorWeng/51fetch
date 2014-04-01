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
  # describe '#saveItems()', () ->
  #   it 'should save items correctly', (done) ->
  #     db(databaseConfig).saveItems {'store_id': 1, 'store_name': 'EVERY_STORE'}, [{
  #       goodsName: 'apple 最新OS系统 U盘安装'
  #       defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i4/T1q3ONFuJdXXXXXXXX_!!0-item_pic.jpg_240x240.jpg'
  #       price: '65.00'
  #       goodHttp: 'http://item.taobao.com/item.htm?id=37498952035'
  #     }, {
  #       goodsName: 'zara 男士休闲皮衣 专柜正品'
  #       defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i1/T1.cFWFuRaXXb0JV6a_240x240.jpg'
  #       price: '299.00'
  #       goodHttp: 'http://item.taobao.com/item.htm?id=37178066336'
  #     }], (err, result) ->
  #       assert.equal result[0]['i_goods_name'], 'apple 最新OS系统 U盘安装'
  #       assert.equal result[1]['i_goods_name'], 'zara 男士休闲皮衣 专柜正品'
  #       done()

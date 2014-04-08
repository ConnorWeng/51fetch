database = require './database.js'
assert = require('chai').assert

describe 'database', () ->
  db = new database()
  db.getDateTime = () -> ''
  describe '#getStores()', () ->
    it 'should return store correctly', (done) ->
      db.getStores 'store_id = 1 limit 1', (err, stores) ->
        assert.equal stores[0].store_id, '1'
        done()
  # describe '#saveItems()', () ->
  #   it 'should save items correctly', (done) ->
  #     db.saveItems 1,2,3, (err, result) ->
  #       console.log result
  #       done()
  describe '#makeSaveItemSql()', () ->
    it 'should make sql correctly', () ->
      sql = db.makeSaveItemSql 'anyStoreId', 'anyStoreName', [{
            goodsName: 'apple 最新OS系统 U盘安装'
            defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i4/T1q3ONFuJdXXXXXXXX_!!0-item_pic.jpg_240x240.jpg'
            price: '65.00'
            goodHttp: 'http://item.taobao.com/item.htm?id=37498952035'
          }, {
            goodsName: 'zara 男士休闲皮衣 专柜正品'
            defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i1/T1.cFWFuRaXXb0JV6a_240x240.jpg'
            price: '299.00'
            goodHttp: 'http://item.taobao.com/item.htm?id=37178066336'
          }]
      assert.equal sql, "call proc_merge_good('anyStoreId','http://img01.taobaocdn.com/bao/uploaded/i4/T1q3ONFuJdXXXXXXXX_!!0-item_pic.jpg_240x240.jpg','65.00','http://item.taobao.com/item.htm?id=37498952035','','anyStoreName','apple 最新OS系统 U盘安装','',@o_retcode);call proc_merge_good('anyStoreId','http://img01.taobaocdn.com/bao/uploaded/i1/T1.cFWFuRaXXb0JV6a_240x240.jpg','299.00','http://item.taobao.com/item.htm?id=37178066336','','anyStoreName','zara 男士休闲皮衣 专柜正品','',@o_retcode);"

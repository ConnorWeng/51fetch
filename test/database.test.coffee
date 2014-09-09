database = require './database.js'
assert = require('chai').assert

db = null

describe 'database', () ->
  beforeEach () ->
    db = new database()
    db.getDateTime = () -> ''

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
          }], 1234567
      assert.equal sql, "call proc_merge_good('anyStoreId','http://img01.taobaocdn.com/bao/uploaded/i4/T1q3ONFuJdXXXXXXXX_!!0-item_pic.jpg_240x240.jpg','65.00','http://item.taobao.com/item.htm?id=37498952035','1234567','anyStoreName','apple 最新OS系统 U盘安装','',@o_retcode);call proc_merge_good('anyStoreId','http://img01.taobaocdn.com/bao/uploaded/i1/T1.cFWFuRaXXb0JV6a_240x240.jpg','299.00','http://item.taobao.com/item.htm?id=37178066336','1234567','anyStoreName','zara 男士休闲皮衣 专柜正品','',@o_retcode);"

  describe '#getCidFromUrl()', () ->
    it 'should return cid', () ->
      assert.equal db.getCidFromUrl('http://shop66794029.taobao.com/category-881893802.htm?search=y&catName=%CF%C4%BF%EE%CC%D7%D7%B0#bd##韩酷休闲服饰##217##减20'), '881893802'
      assert.equal db.getCidFromUrl('http://shop66794029.taobao.com/category-496276028-125439445.htm?search=y&catName=%C1%AC%D2%C2%C8%B9#bd##韩酷休闲服饰##217##减20'), '496276028'

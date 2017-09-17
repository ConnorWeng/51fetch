assert = require('chai').assert
sinon = require 'sinon'
Q = require 'q'
database = require '../src/database'

db = null

describe 'database', () ->
  beforeEach () ->
    db = new database()
    db.getDateTime = () -> 9999

  describe '#makeSaveItemSql()', () ->
    it 'should make sql correctly', () ->
      sql = db.makeSaveItemSql 'anyStoreId', 'anyStoreName', [{
            goodsName: 'apple 最新OS系统 U盘安装'
            defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i4/T1q3ONFuJdXXXXXXXX_!!0-item_pic.jpg_240x240.jpg'
            price: '65.00'
            taobaoPrice: '85.00'
            goodHttp: 'http://item.taobao.com/item.htm?id=37498952035'
          }, {
            goodsName: 'zara 男士休闲皮衣 专柜正品'
            defaultImage: 'http://img01.taobaocdn.com/bao/uploaded/i1/T1.cFWFuRaXXb0JV6a_240x240.jpg'
            price: '299.00'
            taobaoPrice: '319.00'
            goodHttp: 'http://item.taobao.com/item.htm?id=37178066336'
          }], 1234567, '服装', 1
      assert.equal sql, "insert into ecm_gcategory(cate_id, store_id, cate_name, if_show) values ('1234567', 'anyStoreId', '服装', 1) on duplicate key update store_id = 'anyStoreId', cate_name = '服装', if_show = 1;call proc_merge_good('anyStoreId','http://img01.taobaocdn.com/bao/uploaded/i4/T1q3ONFuJdXXXXXXXX_!!0-item_pic.jpg_240x240.jpg','65.00','85.00','http://item.taobao.com/item.htm?id=37498952035','1234567','anyStoreName','apple 最新OS系统 U盘安装','9939','服装','',@o_retcode);call proc_merge_good('anyStoreId','http://img01.taobaocdn.com/bao/uploaded/i1/T1.cFWFuRaXXb0JV6a_240x240.jpg','299.00','319.00','http://item.taobao.com/item.htm?id=37178066336','1234567','anyStoreName','zara 男士休闲皮衣 专柜正品','9938','服装','',@o_retcode);"

  describe '#getCidFromUrl()', () ->
    it 'should return cid', () ->
      assert.equal db.getCidFromUrl('http://shop66794029.taobao.com/category-881893802.htm?search=y&catName=%CF%C4%BF%EE%CC%D7%D7%B0#bd##韩酷休闲服饰##217##减20'), '881893802'
      assert.equal db.getCidFromUrl('http://shop66794029.taobao.com/category-496276028-125439445.htm?search=y&catName=%C1%AC%D2%C2%C8%B9#bd##韩酷休闲服饰##217##减20'), '496276028'
    it 'should return empty string', ->
      assert.equal db.getCidFromUrl('wrong_url'), ''

  describe '#saveItemAttr', ->
    beforeEach ->
      sinon.stub db, 'getItemAttr', ->
        Q [{
          gattr_id: '9999991'
          attr_id: '1'
          value_id: 'vid1'
          attr_name: 'attr11'
          attr_value: 'val11'
        }, {
          gattr_id: '9999992'
          attr_id: '2'
          value_id: 'vid2'
          attr_name: 'attr22'
          attr_value: 'val22'
        }]
      sinon.stub db.pool, 'query', (sql, cb) -> cb()
    assertSql = (attrs, expectSql, done) ->
      db.saveItemAttr 1, attrs, ->
        try
          assert.equal db.pool.query.args[0][0], expectSql
          done()
        catch err
          done err
    it 'should run update sql', (done) ->
      assertSql [{
        attrId: '1'
        valueId: 'vid1'
        attrName: 'attr1'
        attrValue: 'val1'
      }, {
        attrId: '2'
        valueId: 'vid2'
        attrName: 'attr2'
        attrValue: 'val2'
      }], "replace into ecm_attribute(attr_id, attr_name, input_mode, def_value) values ('1', 'attr1', 'select', '其他');update ecm_goods_attr set attr_name = 'attr1', attr_value = 'val1' where gattr_id = 9999991;replace into ecm_attribute(attr_id, attr_name, input_mode, def_value) values ('2', 'attr2', 'select', '其他');update ecm_goods_attr set attr_name = 'attr2', attr_value = 'val2' where gattr_id = 9999992;", done
    it 'should run insert sql', (done) ->
      assertSql [{
        attrId: '1'
        valueId: 'vid1'
        attrName: 'attr1'
        attrValue: 'val1'
      }, {
        attrId: '2'
        valueId: 'vid2'
        attrName: 'attr2'
        attrValue: 'val2'
      }, {
        attrId: '3'
        valueId: 'vid3'
        attrName: 'attr3'
        attrValue: 'val3'
      }], "replace into ecm_attribute(attr_id, attr_name, input_mode, def_value) values ('1', 'attr1', 'select', '其他');update ecm_goods_attr set attr_name = 'attr1', attr_value = 'val1' where gattr_id = 9999991;replace into ecm_attribute(attr_id, attr_name, input_mode, def_value) values ('2', 'attr2', 'select', '其他');update ecm_goods_attr set attr_name = 'attr2', attr_value = 'val2' where gattr_id = 9999992;replace into ecm_attribute(attr_id, attr_name, input_mode, def_value) values ('3', 'attr3', 'select', '其他');insert into ecm_goods_attr(goods_id, attr_name, attr_value, attr_id, value_id) values ('1', 'attr3', 'val3', '3', 'vid3');", done
    it 'should run delete sql', (done) ->
      assertSql [{
        attrId: '1'
        valueId: 'vid1'
        attrName: 'attr1'
        attrValue: 'val1'
      }], "replace into ecm_attribute(attr_id, attr_name, input_mode, def_value) values ('1', 'attr1', 'select', '其他');update ecm_goods_attr set attr_name = 'attr1', attr_value = 'val1' where gattr_id = 9999991;delete from ecm_goods_attr where gattr_id = 9999992;", done

  describe '#updateCats', ->
    it 'should run the correct update sql', ->
      sinon.stub db.pool, 'query', ->
      db.updateCats 1, 2, [{
        "cid": 162103
        "name": "毛衣"
        "parent_cid": 16
      }, {
        "cid": 16
        "name": "女装/女士精品"
        "parent_cid": 0
      }], ->
      assert.isTrue db.pool.query.calledWith "insert into ecm_gcategory(cate_id, store_id, cate_name, parent_id) values (16, 0, '女装/女士精品', 0) on duplicate key update store_id = 0, cate_name = '女装/女士精品', parent_id = 0;insert into ecm_gcategory(cate_id, store_id, cate_name, parent_id) values (162103, 0, '毛衣', 16) on duplicate key update store_id = 0, cate_name = '毛衣', parent_id = 16;update ecm_goods set cate_id_1 = 16, cate_id_2 = 162103 where goods_id = 1;update ecm_goods set cate_id = 162103 where goods_id = 1;"

  describe '#query', ->
    it 'should retry to query when connection is lost', (done) ->
      count = 0
      sinon.stub db.pool, 'query', (sql, callback) ->
        count++;
        if count is 3
          callback null, null
        else
          callback
            code: 'PROTOCOL_CONNECTION_LOST'
          , null
      db.query 'some sql', (err, callback) ->
        assert.equal count, 3
        done();

  describe '#updateSpecs', ->
    oldSpecs = [{
      spec_id: '9999991'
      goods_id: '1'
      spec_1: '天蓝色'
      spec_2: 'S'
      color_rgb: ''
      price: '11.00'
      stock: '1000'
      sku: ''
      spec_vid_1: '3232484'
      spec_vid_2: '28314'
      taobao_price: '31.00'
    }, {
      spec_id: '9999992'
      goods_id: '1'
      spec_1: '天蓝色'
      spec_2: 'XL'
      color_rgb: ''
      price: '11.00'
      stock: '1000'
      sku: ''
      spec_vid_1: '3232484'
      spec_vid_2: '28317'
      taobao_price: '31.00'
    }]
    beforeEach ->
      sinon.stub db.pool, 'query', (sql, cb) -> cb()
      sinon.stub db, 'getSpecs', ->
        Q oldSpecs
    assertSql = (skus, expectSql, done) ->
      db.updateSpecs skus, 1, 12, 13, 999, (err, result) ->
        try
          assert.equal db.pool.query.args[0][0], expectSql
          done()
        catch err
          done err
    it 'should run update sql', (done) ->
      assertSql [
        [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
          price: '11'
          quantity: 100
        ,
          pid: '20509'
          vid: '28314'
          name: '尺码'
          value: 'S'
          price: '11'
          quantity: 100
        ], [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
          price: '11'
          quantity: 100
        ,
          pid: '20509'
          vid: '28317'
          name: '尺码'
          value: 'XL'
          price: '11'
          quantity: 100
        ]
      ], "update ecm_goods_spec set price = '11', stock = '100', sku = '999', taobao_price = '13' where spec_id = 9999991;update ecm_goods_spec set price = '11', stock = '100', sku = '999', taobao_price = '13' where spec_id = 9999992;", done
    it 'should run insert sql', (done) ->
      assertSql [
        [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
          price: '11'
          quantity: 100
        ,
          pid: '20509'
          vid: '28314'
          name: '尺码'
          value: 'S'
          price: '11'
          quantity: 100
        ], [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
          price: '11'
          quantity: 100
        ,
          pid: '20509'
          vid: '28317'
          name: '尺码'
          value: 'XL'
          price: '11'
          quantity: 100
        ], [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
          price: '11'
          quantity: 100
        ,
          pid: '20509'
          vid: '28318'
          name: '尺码'
          value: 'M'
          price: '11'
          quantity: 100
        ]
      ], "update ecm_goods_spec set price = '11', stock = '100', sku = '999', taobao_price = '13' where spec_id = 9999991;update ecm_goods_spec set price = '11', stock = '100', sku = '999', taobao_price = '13' where spec_id = 9999992;insert into ecm_goods_spec(goods_id, spec_1, spec_2, spec_vid_1, spec_vid_2, price, stock, sku, taobao_price) values ('1', '天蓝色', 'M', '3232484', '28318', '11', '100', '999', '13');", done
    it 'should run delete sql', (done) ->
      assertSql [
        [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
          price: '11'
          quantity: 100
        ,
          pid: '20509'
          vid: '28314'
          name: '尺码'
          value: 'S'
          price: '11'
          quantity: 100
        ]
      ], "update ecm_goods_spec set price = '11', stock = '100', sku = '999', taobao_price = '13' where spec_id = 9999991;delete from ecm_goods_spec where spec_id = 9999992;", done
    it 'should run default update sql', (done) ->
      backedSpecs = oldSpecs
      oldSpecs = [{
        spec_id: '9999991'
        goods_id: '1'
        spec_1: ''
        spec_2: ''
        color_rgb: ''
        price: '11.00'
        stock: '1000'
        sku: ''
        spec_vid_1: 0
        spec_vid_2: 0
        taobao_price: '31.00'
      }]
      assertSql [], "update ecm_goods_spec set price = '12', stock = '1000', sku = '999', taobao_price = '13' where spec_id = 9999991;", (err) ->
        oldSpecs = backedSpecs
        done(err)
    it 'should run default insert sql', (done) ->
      backedSpecs = oldSpecs
      oldSpecs = []
      assertSql [], "insert into ecm_goods_spec(goods_id, spec_1, spec_2, spec_vid_1, spec_vid_2, price, stock, sku, taobao_price) values ('1', '', '', '0', '0', '12', '1000', '999', '13');", (err) ->
        oldSpecs = backedSpecs
        done(err)

  describe '#updateGoods', ->
    beforeEach ->
      sinon.stub db.pool, 'query', ->
    it 'should be 1 spec', ->
      db.updateGoods 1, 'title', 15, 30, 'desc', 'good http', 1, [
        [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
        ]
      ], 'default image', null, ->
      assert.isTrue db.pool.query.calledWith "update ecm_goods set goods_name = 'title', price = 15, taobao_price = 30, description = 'desc', spec_name_1 = '颜色分类', spec_name_2 = '', spec_pid_1 = 1627207, spec_pid_2 = 0, spec_qty = 1, realpic = 1 where good_http = 'good http';update ecm_goods set default_image = 'default image' where good_http = 'good http' and (default_image = '' or default_image = 'undefined');"
    it 'should be 2 specs', ->
      db.updateGoods 2, 'title', 15.2, 30.4, 'desc', 'good http', 1, [
        [
          pid: '1627207'
          vid: '3232484'
          name: '颜色分类'
          value: '天蓝色'
        ,
          pid: '20509'
          vid: '28314'
          name: '尺码'
          value: 'S'
        ]
      ], 'default image', null, ->
      assert.isTrue db.pool.query.calledWith "update ecm_goods set goods_name = 'title', price = 15.2, taobao_price = 30.4, description = 'desc', spec_name_1 = '颜色分类', spec_name_2 = '尺码', spec_pid_1 = 1627207, spec_pid_2 = 20509, spec_qty = 2, realpic = 1 where good_http = 'good http';update ecm_goods set default_image = 'default image' where good_http = 'good http' and (default_image = '' or default_image = 'undefined');"

  describe '#updateImWw', ->
    it 'should run the correct update sql', ->
      sinon.stub db.pool, 'query', ->
      db.updateImWw '1', 'store_name', '1234567'
      assert.isTrue db.pool.query.calledWith "update ecm_store set im_ww = '1234567' where store_id = 1"

  describe '#updateItemImgs', ->
    beforeEach ->
      sinon.stub db, 'getItemImgs', ->
        Q [{
          image_id: 29252478
          goods_id: 1
          image_url: 'http://gd2.alicdn.com/imgextra/i2/511039241/TB2cVaYg3JlpuFjSspjXXcT.pXa_!!511039241.jpg'
          thumbnail: 'http://gd2.alicdn.com/imgextra/i2/511039241/TB2cVaYg3JlpuFjSspjXXcT.pXa_!!511039241.jpg_460x460.jpg'
          sort_order: 0
          file_id: 0
        }, {
          image_id: 29252479
          goods_id: 1
          image_url: 'http://gd3.alicdn.com/imgextra/i3/511039241/TB20_necdhvOuFjSZFBXXcZgFXa_!!511039241.jpg'
          thumbnail: 'http://gd3.alicdn.com/imgextra/i3/511039241/TB20_necdhvOuFjSZFBXXcZgFXa_!!511039241.jpg_460x460.jpg'
          sort_order: 1
          file_id: 0
        }]
      sinon.stub db.pool, 'query', (sql, cb) -> cb()
    assertSql = (itemImgs, expectSql, done) ->
      db.updateItemImgs 1, itemImgs, ->
        try
          assert.equal db.pool.query.args[0][0], expectSql
          done()
        catch err
          done err
    it 'should run update sql', (done) ->
      assertSql [{
        url: 'http://gd2.alicdn.com/imgextra/i2/511039241/TB2cVaYg3JlpuFjSspjXXcT.pXa_!!511039241.jpg'
      }, {
        url: 'http://gd3.alicdn.com/imgextra/i3/511039241/TB20_necdhvOuFjSZFBXXcZgFXa_!!511039241.jpg'
      }], "update ecm_goods_image set goods_id = '1', image_url = 'http://gd2.alicdn.com/imgextra/i2/511039241/TB2cVaYg3JlpuFjSspjXXcT.pXa_!!511039241.jpg', thumbnail = 'http://gd2.alicdn.com/imgextra/i2/511039241/TB2cVaYg3JlpuFjSspjXXcT.pXa_!!511039241.jpg_460x460.jpg', sort_order = '0', file_id = '0' where image_id = 29252478;update ecm_goods_image set goods_id = '1', image_url = 'http://gd3.alicdn.com/imgextra/i3/511039241/TB20_necdhvOuFjSZFBXXcZgFXa_!!511039241.jpg', thumbnail = 'http://gd3.alicdn.com/imgextra/i3/511039241/TB20_necdhvOuFjSZFBXXcZgFXa_!!511039241.jpg_460x460.jpg', sort_order = '1', file_id = '0' where image_id = 29252479;", done
    it 'should run delete sql', (done) ->
      assertSql [{
        url: 'http://gd2.alicdn.com/imgextra/i2/511039241/TB2cVaYg3JlpuFjSspjXXcT.pXa_!!511039241.jpg'
      }], "update ecm_goods_image set goods_id = '1', image_url = 'http://gd2.alicdn.com/imgextra/i2/511039241/TB2cVaYg3JlpuFjSspjXXcT.pXa_!!511039241.jpg', thumbnail = 'http://gd2.alicdn.com/imgextra/i2/511039241/TB2cVaYg3JlpuFjSspjXXcT.pXa_!!511039241.jpg_460x460.jpg', sort_order = '0', file_id = '0' where image_id = 29252478;delete from ecm_goods_image where image_id = 29252479;", done
    it 'should run insert sql', (done) ->
      assertSql [{
        url: 'http://gd2.alicdn.com/imgextra/i2/511039241/TB2cVaYg3JlpuFjSspjXXcT.pXa_!!511039241.jpg'
      }, {
        url: 'http://gd3.alicdn.com/imgextra/i3/511039241/TB20_necdhvOuFjSZFBXXcZgFXa_!!511039241.jpg'
      }, {
        url: 'http://gd1.alicdn.com/imgextra/i3/511039241/TB20dnecdhvJJFiSBBBXXcZgFXa_!!511039241.jpg'
      }], "update ecm_goods_image set goods_id = '1', image_url = 'http://gd2.alicdn.com/imgextra/i2/511039241/TB2cVaYg3JlpuFjSspjXXcT.pXa_!!511039241.jpg', thumbnail = 'http://gd2.alicdn.com/imgextra/i2/511039241/TB2cVaYg3JlpuFjSspjXXcT.pXa_!!511039241.jpg_460x460.jpg', sort_order = '0', file_id = '0' where image_id = 29252478;update ecm_goods_image set goods_id = '1', image_url = 'http://gd3.alicdn.com/imgextra/i3/511039241/TB20_necdhvOuFjSZFBXXcZgFXa_!!511039241.jpg', thumbnail = 'http://gd3.alicdn.com/imgextra/i3/511039241/TB20_necdhvOuFjSZFBXXcZgFXa_!!511039241.jpg_460x460.jpg', sort_order = '1', file_id = '0' where image_id = 29252479;insert into ecm_goods_image(goods_id, image_url, thumbnail, sort_order, file_id) values ('1', 'http://gd1.alicdn.com/imgextra/i3/511039241/TB20dnecdhvJJFiSBBBXXcZgFXa_!!511039241.jpg', 'http://gd1.alicdn.com/imgextra/i3/511039241/TB20dnecdhvJJFiSBBBXXcZgFXa_!!511039241.jpg_460x460.jpg', '2', '0');", done

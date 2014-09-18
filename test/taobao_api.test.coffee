taobao_api = require '../src/taobao_api'
assert = require('chai').assert

describe 'taobao_api', ->
  describe '#md5', ->
    it 'should return 7ac66c0f148de9519b8bd264312c4d64 when input is abcdefg', ->
      assert.equal taobao_api.md5('abcdefg'), '7ac66c0f148de9519b8bd264312c4d64'
    it 'should return f506bde359def568e5d8173a8851d53d when input is gfedcba', ->
      assert.equal taobao_api.md5('gfedcba'), 'f506bde359def568e5d8173a8851d53d'

  describe '#ksort', ->
    it 'should return {"a":"a", "b":"b", "c":"c"} when input is {"b":"b", "c":"c", "a":"a"}', ->
      assert.deepEqual taobao_api.ksort({"b":"b", "c":"c", "a":"a"}), {"a":"a", "b":"b", "c":"c"}
    it 'should return {"b":"b", "c":"c", "d":"d"} when input is {"d":"d", "c":"c", "b":"b"}', ->
      assert.deepEqual taobao_api.ksort({"d":"d", "c":"c", "b":"b"}), {"b":"b", "c":"c", "d":"d"}

  describe '#generateSign', ->
    it 'should return E89BCDD8DDE76BBB443ADC55100BCF45', ->
      taobao_api.setConfig
        taobao_app_key: '21357243'
        taobao_secret_key: '244fd3a0b1f554046a282dd9b673b386'
      assert.equal taobao_api.generateSign(
        'app_key': '21357243'
        'v': '2.0'
        'format': 'xml'
        'sign_method': 'md5'
        'method': 'taobao.item.get'
        'timestamp': '2014-09-14 17:36:59'
        'partner_id': 'top-sdk-php-20140420'
        'fields': 'title,desc,pic_url,sku,item_weight,property_alias,price,item_img.url,cid,nick,props_name,prop_img,delist_time'
        'num_iid': '40975693157'
      ), 'E89BCDD8DDE76BBB443ADC55100BCF45'

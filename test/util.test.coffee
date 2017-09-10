assert = require('chai').assert
{getHuoHao, removeNumbersAndSymbols} = require '../src/util'

describe 'util', ->
  describe '#getHuoHao', ->
    it 'should return huo hao', ->
      assert.equal getHuoHao('705#title'), 705
      assert.equal getHuoHao('title705'), 705
      assert.equal getHuoHao('2014title705'), 705
      assert.equal getHuoHao('title'), ''
      assert.equal getHuoHao('title9title705'), 705
      assert.equal getHuoHao('title16title705'), 705
      assert.equal getHuoHao('title#16title705'), 16
      assert.equal getHuoHao('title16#title705'), 16
      assert.equal getHuoHao('17title6488'), 6488

  describe '#removeNumbersAndSymbols', ->
    it 'should remove all numbers and symbols', ->
      assert.equal removeNumbersAndSymbols('实拍 秋装815'), '实拍秋装'
      assert.equal removeNumbersAndSymbols('实拍 秋装815#'), '实拍秋装'
      assert.equal removeNumbersAndSymbols('17/实拍 秋装815#'), '实拍秋装'

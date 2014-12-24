{log, error} = require 'util'
{crawl} = require '../src/crawler'
database = require '../src/database'
config = require '../src/config'

db = new database(config.database['nt'])

goods = []

db.runSql "select * from ecm_goods where good_http != ''", (err, res) ->
  if err
    error err
  else
    goods = res
    updateGood()

updateGood = ->
  if goods.length > 0
    good = goods.shift()
    updateGoodDetail good, updateGood
  else
    log 'complete.'

updateGoodDetail = (good, callback) ->
  crawl good.good_http,
    good_sql: ($) ->
      description = $('.content').html()
      spec1 = $('.item_tail_l dd:eq(3) span:eq(0)').text().trim()
      spec2 = $('.item_tail_l dd:eq(5) span:eq(0)').text().trim()
      "insert into ecm_goods_spec(goods_id, spec_1, spec_2, price, stock) values (#{good.goods_id}, '#{spec1}', '#{spec2}', 100, 100);update ecm_goods set default_spec = last_insert_id(), spec_qty = 2, spec_name_1 = '适用床尺寸', spec_name_2 = '颜色分类', description = '#{description}' where goods_id = #{good.goods_id};"
  , (err, res) ->
    if err
      error err
    else
      db.runSql res['good_sql'], (err, res) ->
        if err
          error err
        else
          console.log res
          updateGood()

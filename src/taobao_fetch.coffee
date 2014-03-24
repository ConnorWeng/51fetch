http = require 'http'

exports.requestHtmlContent = (url, callback) ->
    result = ''
    http.get url, (res) ->
        res.on 'data', (chunk) ->
            result += chunk
        res.on 'end', () ->
            callback null, result

exports.extractItemsFromContent = (content) ->
    [{
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

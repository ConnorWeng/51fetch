{getTaobaoItemsOnsale} = require '../src/taobao_api'
args = process.argv.slice 2

getTaobaoItemsOnsale 'title,pic_url,price,num_iid', args[0], (err, items) ->
  if err then return console.error err
  console.log items

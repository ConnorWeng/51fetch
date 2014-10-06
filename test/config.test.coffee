chai = require 'chai'
config = require '../src/config'

chai.should()

describe 'config', ->
  it 'should return config object from config.json', ->
    config.database.wangpi51_dg.should.eql
      host: 'rdsqr7ne2m2ifjm.mysql.rds.aliyuncs.com'
      user: 'wangpicn'
      password: 'wangpicn123456'
      database: 'wangpi51_dg'
      port: 3306
    config.remote_service_address.should.equal 'http://mall.51zwd.com/index.php?app=default&act=remoteimage'

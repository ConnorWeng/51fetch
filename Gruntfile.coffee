module.exports = (grunt) ->

  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'

    'sftp-deploy':
      jushita:
        auth:
          host: '121.196.142.10'
          port: 30002
          authKey: 'jushita'
        src: './'
        dest: '/alidata/www/test2/node/51fetch_all/'
        exclusions: ['.DS_Store', 'node_modules', '.git', '.ftppass', 'sftpCache.json']
        serverSep: '/'
        concurrency: 4
        progress: true
      aliyun:
        auth:
          host: '112.124.54.224'
          port: 5151
          authKey: 'aliyun'
        src: './'
        dest: '/alidata/www/test2/node/51fetch_all/'
        exclusions: ['.DS_Store', 'node_modules', '.git', '.ftppass', 'sftpCache.json']
        serverSep: '/'
        concurrency: 4
        progress: true

  grunt.loadNpmTasks 'grunt-sftp-deploy'

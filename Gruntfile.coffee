module.exports = (grunt) ->

  serverConfig = grunt.file.readJSON '.ftppass'

  makeDeployTasks = ->
    tasks = {}
    for key, value of serverConfig
      tasks["deploy_#{key}"] =
        files:
          './': filesNeedUpload
        options:
          path: '/alidata/www/test2/node/51fetch_all'
          host: value.host
          port: value.port
          username: value.username
          password: value.password
          createDirectories: true
          showProgress: true
    tasks

  makeTasksName = ->
    tasksName = []
    for key, value of serverConfig
      tasksName.push "sftp:deploy_#{key}"
    tasksName

  filesNeedUpload = ['crawlItem.coffee', 'e2e/**', 'index.coffee', 'package.json', 'script/**', 'single_store.coffee', 'src/**', 'taobao_api/**', 'test/**']

  grunt.initConfig
    secret: serverConfig
    sftp: makeDeployTasks()

  grunt.loadNpmTasks 'grunt-ssh'
  grunt.registerTask 'dist', makeTasksName()

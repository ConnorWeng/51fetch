{merge} = require './src/helpers'

module.exports = (grunt) ->
  serverConfig = grunt.file.readJSON '.ftppass'
  filesNeedUpload = ['crawlItem.coffee', 'e2e/**', 'index.coffee', 'package.json', 'script/**', 'single_store.coffee', 'src/**', 'taobao_api/**', 'test/**']

  # 这里可以不返回一个function, 而直接返回
  # tasks
  # 那么要扩展tasks的时候, 都要写成类似如下的形式:
  # makeDeployTasks = ->
  #   makeTasks 'deploy', -> {...}
  # 这样做增加了用户扩展的成本, 因为他必须要实现一个function去调用makeTasks
  # 通过返回function的方式可以让用户不用重复去定义function, 更抽象, 更接近DSL,
  # 更有一种makeDeployTasks是makeTasks的一种特殊情况; makeTasks是模版的感觉，可读性更高
  makeTasks = (action, configFunc) ->
    ->
      tasks = {}
      for key, value of serverConfig
        tasks["#{action}_#{key}"] = configFunc key, value
        setAuthOptions tasks["#{action}_#{key}"]['options'], value
      tasks

  makeDeployTasks = makeTasks 'deploy', ->
    files:
      './': filesNeedUpload
    options:
      path: '/alidata/www/test2/node/51fetch_all'
      createDirectories: true
      showProgress: true

  makeRunTasks = makeTasks 'run', (key, value) ->
    command: [
      'cd /alidata/www/test2/node/51fetch_all'
      "mv logs/forever.log logs/#{today()}.forever.log"
      "mv logs/#{value.log} logs/#{today()}.#{value.log}"
      "forever stopall"
      "forever start -m 1 -l /alidata/www/test2/node/51fetch_all/logs/forever.log -e ./logs/err.log -o ./logs/#{value.log} -c #{value.command}"
      "forever list"
    ].join ' && '
    options: {}

  makeStatusTasks = makeTasks 'status', (key, value) ->
    command: [
      'cd /alidata/www/test2/node/51fetch_all'
      'forever list'
      "tail logs/#{value.log}"
    ].join ' && '
    options: {}

  today = ->
    d = new Date()
    "#{d.getFullYear()}#{d.getMonth() + 1}#{d.getDate()}"

  setAuthOptions = (options, value) ->
    options.host = value.host
    options.port = value.port
    options.username = value.username
    options.password = value.password

  makeTasksName = (action) ->
    tasksName = []
    for key, value of serverConfig
      tasksName.push "sshexec:#{action}_#{key}"
    tasksName

  grunt.initConfig
    secret: serverConfig
    sftp: makeDeployTasks()
    sshexec: merge makeRunTasks(), makeStatusTasks()

  grunt.loadNpmTasks 'grunt-ssh'
  grunt.registerTask 'dist', makeTasksName('deploy')
  grunt.registerTask 'run', makeTasksName('run')
  grunt.registerTask 'status', makeTasksName('status')

module.exports = (grunt) ->

  serverConfig = grunt.file.readJSON '.ftppass'
  filesNeedUpload = ['crawlItem.coffee', 'e2e/**', 'index.coffee', 'package.json', 'script/**', 'single_store.coffee', 'src/**', 'taobao_api/**', 'test/**']

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
    sshexec: makeRunTasks()

  grunt.loadNpmTasks 'grunt-ssh'
  grunt.registerTask 'dist', makeTasksName('deploy')
  grunt.registerTask 'run', makeTasksName('run')

module.exports = (grunt) ->

  serverConfig = grunt.file.readJSON '.ftppass'

  today = ->
    d = new Date()
    "#{d.getFullYear()}#{d.getMonth() + 1}#{d.getDate()}"

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

  makeDeployTasksName = ->
    tasksName = []
    for key, value of serverConfig
      tasksName.push "sftp:deploy_#{key}"
    tasksName

  makeRunTasks = ->
    tasks = {}
    for key, value of serverConfig
      tasks["run_#{key}"] =
        command: [
          'cd /alidata/www/test2/node/51fetch_all'
          "mv logs/forever.log logs/#{today()}.forever.log"
          "mv logs/#{value.log} logs/#{today()}.#{value.log}"
          "forever stopall"
          "forever start -m 1 -l /alidata/www/test2/node/51fetch_all/logs/forever.log -e ./logs/err.log -o ./logs/#{value.log} -c #{value.command}"
          "forever list"
        ].join ' && '
        options:
          host: value.host
          port: value.port
          username: value.username
          password: value.password
    tasks

  makeRunTasksName = ->
    tasksName = []
    for key, value of serverConfig
      tasksName.push "sshexec:run_#{key}"
    tasksName

  filesNeedUpload = ['crawlItem.coffee', 'e2e/**', 'index.coffee', 'package.json', 'script/**', 'single_store.coffee', 'src/**', 'taobao_api/**', 'test/**']

  grunt.initConfig
    secret: serverConfig
    sftp: makeDeployTasks()
    sshexec: makeRunTasks()

  grunt.loadNpmTasks 'grunt-ssh'
  grunt.registerTask 'dist', makeDeployTasksName()
  grunt.registerTask 'run', makeRunTasksName()

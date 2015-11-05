# Socket test class
# =================================================
# This may be used to check the connection to different ports using TCP.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:socket')
chalk = require 'chalk'
# include alinex modules
async = require 'alinex-async'
Exec = require 'alinex-exec'
{object, string} = require 'alinex-util'
# include classes and helpers
sensor = require '../sensor'

# Schema Definition
# -------------------------------------------------
# This is used as configuration specification and to add the default values for
# specific setting.
#
# It's a n[alinex-validator](http://alinex.githhub.io/node-validator)
# compatible schema definition:
exports.schema =
  title: "Socket connection test"
  description: "the configuration to make TCP socket connections"
  type: 'object'
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on this to run the command"
      type: 'string'
    host:
      title: "Hostname or IP"
      description: "the server hostname or ip address to establish connection to"
      type: 'string'
      default: 'localhost'
    port:
      title: "Port"
      description: "the port number used to connect to"
      type: 'integer'
      min: 1
    timeout:
      title: "Timeout"
      description: "the timeout in milliseconds till the process is stopped
        and be considered as failed"
      type: 'interval'
      unit: 'ms'
      min: 500
      default: 2000
    warn: sensor.schema.warn
    fail: sensor.schema.fail

# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Socket'
  description: "Use TCP sockets to check for the availability of a service
  behind a given port."
  category: 'net'
  hint: "On problems the service may not run or a network problem exists. "

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    responsetime:
      title: "Response Time"
      description: "time in milliseconds till connection could be established"
      type: 'integer'
      unit: 'ms'

# Get content specific name
# -------------------------------------------------
exports.name = (config) -> "#{config.remote ? ''}->#{config.host}:#{config.port}"

# Run the Sensor
# -------------------------------------------------
exports.run = (config, cb = ->) ->
  work =
    sensor: this
    config: config
    result: {}
  if config.remote
    runRemote config, work, cb
  else
    runLocal config, work, cb

runLocal = (config, work, cb) ->
  net = require 'net'
  sensor.start work
  socket = new net.Socket()
  debug "connect to #{@config.host}:#{@config.port}"
  start = new Date().getTime()
  socket.setTimeout config.timeout
  socket.connect config.port, @config.host, ->
    sensor.end work
    debug "connection established"
    end = new Date().getTime()
    socket.destroy()
    # get the values
    val = work.result.values
    val.responseTime = end-start
    sensor.result work
    cb null, work.result
  # Timeout occurred
  socket.on 'timeout', ->
    sensor.end work
    work.err = new Error "server not responding, timeout occurred"
    sensor.result work
    cb null, work.result
  # Error management
  socket.on 'error', (err) ->
    sensor.end work
    work.err = err
    sensor.result work
    cb null, work.result

runRemote = (config, work, cb) ->
  sensor.start work
  # run check
  Exec.run
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "echo > /dev/tcp/#{config.host}/#{config.port}"]
    priority: 'immediately'
  , (err, proc) ->
    work.err = err
    sensor.end work
    val = work.result.values
    # calculate values
    num = 0
    sum = 0
    re = /time=(\d+.?\d*) ms/g
    while match = re.exec proc.stdout()
      time = parseFloat match[1]
      num++
      sum += time
      if not val.responseMin? or time < val.responseMin
        val.responseMin = time
      if not val.responseMax? or time > val.responseMax
        val.responseMax = time
    val.responseTime = Math.round(sum/num*10)/10.0
    match = /\s(\d+)% packet loss/.exec proc.stdout()
    val.quality = 100-match?[1]
    val.quality = val.quality/100 if val.quality
    sensor.result work
    cb null, work.result

# Run additional analysis
# -------------------------------------------------
exports.analysis = (config, cb = ->) ->
  cb()

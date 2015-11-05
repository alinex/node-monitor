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
    transport:
      title: "Transport Protocol"
      description: "the protocol used for internet transport layer"
      type: 'string'
      toLower: true
      values: ['tcp', 'udp']
      default: 'tcp'
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
    responseTime:
      title: "Response Time"
      description: "time in milliseconds till connection could be established"
      type: 'interval'
      unit: 'ms'

# Get content specific name
# -------------------------------------------------
exports.name = (config) -> "#{config.transport}
#{config.remote ? 'localhost'}->#{config.host}:#{config.port}"

# Run the Sensor
# -------------------------------------------------
exports.run = (config, cb = ->) ->
  work =
    sensor: this
    config: config
    result: {}
  sensor.start work
  # run check
  Exec.run
    remote: config.remote
    cmd: 'bash'
    args: ['-c', "echo > /dev/#{config.transport}/#{config.host}/#{config.port}"]
    priority: 'immediately'
  , (err, proc) ->
    work.err = err
    sensor.end work
    if proc.result.lines[0]?[1]
      work.result.message = proc.result.lines[0][1].replace /bash:\s+/, ''
    unless err
      val = work.result.values
      val.responseTime = work.result.date[1] - work.result.date[0]
    sensor.result work
    cb null, work.result

# Run additional analysis
# -------------------------------------------------
exports.analysis = (config, cb = ->) ->
  cb()

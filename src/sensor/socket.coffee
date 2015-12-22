# Socket test class
# =================================================
# This may be used to check the connection to different ports using TCP.


# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:socket')
# include alinex modules
Exec = require 'alinex-exec'


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
      description: "the remote server on which to run the command"
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
    warn:
      title: "Warn if"
      description: "the javascript code to check to set status to warn"
      type: 'string'
      optional: true
    fail:
      title: "Fail if"
      description: "the javascript code to check to set status to fail"
      type: 'string'
      optional: true


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


# Initialize check
# -------------------------------------------------
# This method is used for some precalculations or analyzations and should set:
#
# - check.name = <string> # mandatory
# - check.base = <object> # optionally
exports.init = (cb) ->
  @name ?= "#{@conf.transport} #{@conf.remote ? 'localhost'}->#{@conf.host}:#{@conf.port}"
  cb()


# Run the Sensor
# -------------------------------------------------
exports.run = (cb) ->
  # run check
  Exec.run
    remote: @conf.remote
    cmd: 'bash'
    args: ['-c', "echo > /dev/#{@conf.transport}/#{@conf.host}/#{@conf.port}"]
    priority: 'immediately'
    timeout: @conf.timeout
  , cb


# Get the results
# -------------------------------------------------
exports.calc = (res, cb) ->
  return cb() if @err
  @values.responseTime = @date[1] - @date[0]
  if res.result.lines[0]?[1]
    @err = new Error res.result.lines[0][1].replace /bash:\s+/, ''
  cb()

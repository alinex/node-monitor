# Time check
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
# But the analysis part currently only works on linux.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:time')
chalk = require 'chalk'
ntp = require 'ntp-client'
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
  title: "Time check configuration"
  description: "the configuration to check local time against ntp"
  type: 'object'
  default:
    warn: 'diff > 10000'
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on this to run the command"
      type: 'string'
    host:
      title: "NTP Hostname"
      description: "the name of an NTP server to call"
      type: 'string'
      default: 'pool.ntp.org'
    port:
      title: "NTP Port"
      description: "the port to use for NTP calls"
      type: 'integer'
      default: 123
    timeout:
      title: "Timeout"
      description: "the time in milliseconds to retrieve time"
      type: 'interval'
      unit: 'ms'
      default: 10000
      min: 500
    warn: object.extend {}, sensor.schema.warn,
      default: 'diff > 10000'
    fail: sensor.schema.fail

# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Time Check'
  description: "Check the system time against the Internet."
  category: 'sys'
  hint: "If the time is not correct it may influence some processes which goes
  over multiple hosts. Therefore install and configure `ntpd` on the machine."

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    local:
      title: 'Local Time'
      description: "the time on the local host"
      type: 'date'
    remote:
      title: 'Remote Time'
      description: "the time on an internet time server"
      type: 'date'
    diff:
      title: 'Difference'
      description: "the difference between both times"
      type: 'interval'
      unit: 'ms'

# Get content specific name
# -------------------------------------------------
exports.name = (config) -> ''

# Run the Sensor
# -------------------------------------------------
exports.run = (config, cb = ->) ->
  work =
    sensor: this
    config: config
    result: {}
  sensor.start work
  # run check
  async.parallel [
    (cb) ->
      Exec.run
        remote: config.remote
        cmd: 'date'
        args: ['--iso-8601=seconds']
        priority: 'immediately'
      , cb
    (cb) ->
      ntp.ntpReplyTimeout = config.timeout
      ntp.getNetworkTime config.host, config.port, cb
  ], (err, proc) ->
    sensor.end work
    val = work.result.values
    # check times
    val.local = new Date proc[0].stdout().trim()
    val.remote = proc[1]
    val.diff = Math.abs val.local - val.remote
    sensor.result work
    cb err, work.result

# Run additional analysis
# -------------------------------------------------
exports.analysis = (config, res, cb = ->) ->
  cb()

# Time check
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
#
# This methods will be called in the context of the corresponding check()
# instance.
#
# The analysis part currently is based on debian linux.


# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = require('debug')('monitor:sensor:time')
ntp = require 'ntp-client'
# include alinex modules
config = require 'alinex-config'
async = require 'alinex-async'
Exec = require 'alinex-exec'


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
      description: "the remote server on which to run the command"
      type: 'string'
      values: Object.keys config.get('/exec/remote/server') ? {}
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
    warn:
      title: "Warn if"
      description: "the javascript code to check to set status to warn"
      type: 'string'
      default: 'diff > 10000'
    fail:
      title: "Fail if"
      description: "the javascript code to check to set status to fail"
      type: 'string'
      optional: true


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


# Initialize check
# -------------------------------------------------
# This method is used for some precalculations or analyzations and should set:
#
# - check.name = <string> # mandatory
# - check.base = <object> # optionally
exports.init = (cb) ->
  @name ?= @conf.remote ? 'localhost'
  cb()


# Run the Sensor
# -------------------------------------------------
exports.run = (cb) ->
  # run check
  async.parallel [
    (cb) =>
      Exec.run
        remote: @conf.remote
        cmd: 'date'
        args: ['--iso-8601=seconds']
        priority: 'immediately'
      , cb
    (cb) =>
      ntp.ntpReplyTimeout = @conf.timeout
      ntp.getNetworkTime @conf.host, @conf.port, cb
  ], cb


# Get the results
# -------------------------------------------------
exports.calc = (cb) ->
  return cb() if @err
  res = @result.data
  # check times
  @values.local = new Date res[0].stdout().trim()
  @values.remote = res[1]
  @values.diff = Math.abs @values.local - @values.remote
  cb()

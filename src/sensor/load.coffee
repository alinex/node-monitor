# Load check
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
exports.debug = debug = require('debug')('monitor:sensor:load')
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
  title: "System load check"
  description: "the system load in the last time"
  type: 'object'
  allowedKeys: true
  default:
    warn: "short > 500%"
    analysis:
      minCpu: 0.1
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on which to run the command"
      type: 'string'
    warn:
      title: "Warn if"
      description: "the javascript code to check to set status to warn"
      type: 'string'
      default: 'short > 500%'
    fail:
      title: "Fail if"
      description: "the javascript code to check to set status to fail"
      type: 'string'
      optional: true


# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Load'
  description: "Check the local processor activity over the last minute to 15 minutes."
  category: 'sys'
  hint: "A very high system load makes the system irresponsible or really slow.
  Mostly this is CPU-bound load, load caused by out of memory issues or I/O-bound
  load problems. "

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    short:
      title: "1min Load"
      description: "average value of one minute processor load (normalized)"
      type: 'percent'
    medium:
      title: "5min Load"
      description: "average value of 5 minute processor load (normalized)"
      type: 'percent'
    long:
      title: "15min Load"
      description: "average value of 15 minute processor load (normalized)"
      type: 'percent'


# Initialize check
# -------------------------------------------------
# This method is used for some precalculations or analyzations and should set:
#
# - check.name = <string> # mandatory
# - check.base = <object> # optionally
exports.init = (cb) ->
  @name ?= @conf.remote ? 'localhost'
  Exec.run
    remote: @conf.remote
    cmd: 'sh'
    args: ['-c', "grep processor /proc/cpuinfo | wc -l"]
    priority: 'immediately'
  , (err, res) =>
    return cb err if err
    @base = Number res.stdout()
    cb()


# Run the Sensor
# -------------------------------------------------
exports.run = (cb) ->
  # run check
  Exec.run
    remote: @conf.remote
    cmd: 'cat'
    args: ['/proc/loadavg']
    priority: 'immediately'
  , cb


# Get the results
# -------------------------------------------------
exports.calc = (res, cb) ->
  return cb() if @err
  # cpu info values
  load = res.stdout().split /\s/
  @values.short = Number(load[0]) / @base
  @values.medium = Number(load[1]) / @base
  @values.long = Number(load[2]) / @base
  cb()

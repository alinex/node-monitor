# Load check
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
# But the analysis part currently only works on linux.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:load')
chalk = require 'chalk'
# include alinex modules
async = require 'alinex-async'
Exec = require 'alinex-exec'
{object, string} = require 'alinex-util'
# include classes and helpers
sensor = require '../sensor'
cpu = require './cpu'

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
      description: "the remote server on this to run the command"
      type: 'string'
    warn: object.extend {}, sensor.schema.warn,
      default: 'short > 500%'
    fail: sensor.schema.fail
    analysis:
      title: "Analysis Run"
      description: "the configuration for the analysis if it is run"
      type: 'object'
      allowedKeys: true
      keys:
        minCpu:
          title: "Minimum %CPU"
          description: "the minimum CPU usage to include"
          type: 'percent'
          min: 0
          default: 0.1
        numProc:
          title: "Top X"
          description: "the number of top CPU heavy processes for analysis"
          type: 'integer'
          min: 1

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
    cpus:
      title: "Num Cores"
      description: "number of cpu cores"
      type: 'integer'
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
  async.map [
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "grep processor /proc/cpuinfo | wc -l"]
    priority: 'immediately'
  ,
    remote: config.remote
    cmd: 'cat'
    args: ['/proc/loadavg']
    priority: 'immediately'
  ], (setup, cb) ->
    Exec.run setup, cb
  , (err, proc) ->
    sensor.end work
    # analyses results
    if err
      work.err = err
    else
      val = work.result.values
      # cpu info values
      val.cpus = Number proc[0].stdout()
      load = proc[1].stdout().split /\s/
      val.short = Number load[0]
      val.medium = Number load[1]
      val.long = Number load[2]
      sensor.result work
      cb err, work.result

# Run the Sensor
# -------------------------------------------------
exports.analysis = cpu.analysis

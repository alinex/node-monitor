# Explore hardware
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
# But the analysis part currently only works on linux.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:explorer:hardware')
chalk = require 'chalk'
# include alinex modules
async = require 'alinex-async'
Exec = require 'alinex-exec'
{object, string} = require 'alinex-util'
# include classes and helpers
explorer = require '../explorer'


# Schema Definition
# -------------------------------------------------
# This is used as configuration specification and to add the default values for
# specific setting.
#
# It's an [alinex-validator](http://alinex.githhub.io/node-validator)
# compatible schema definition:
exports.schema =
  title: "Hardware Explorer"
  description: "the configuration to check the hardware of a server"
  type: 'object'
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on which to run the command"
      type: 'string'

# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Hardware Explorer'
  description: "Check the hardware of the given system."
  category: 'sys'
  hint: "Depending on the user rights this report may be more or less complete."

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    systemId:
      title: "System ID"
      description: "name of the system by manufacturer"
      type: 'string'

# Get content specific name
# -------------------------------------------------
exports.name = (config) -> config.remote

# Run the Sensor
# -------------------------------------------------
exports.run = (config, cb = ->) ->
  work =
    explorer: this
    config: config
    result: {}
  explorer.start work
  # run possibilities
  run work, (err, result) ->
    explorer.end work
    cb err, result

run = (work, cb) ->
  runLshw work, (err, result) ->
    return cb null, result unless err
    runDmidecode work, (err, result) ->
      return cb null, result unless err
      runCore work, (err, result) ->
        return cb null, result

runLshw = (work, cb) ->
  # run first alternative: lshw -json
  Exec.run
    remote: work.config.remote
    cmd: 'lshw'
    args: ['-json']
    priority: 'immediately'
  , (err, proc) ->
    # run second alternative
    if err
      work.hint ?= []
      work.hint.push "Install the command `lshw` to get a lot more information."
      return err
    data = JSON.parse proc.stdout()
    # store values
    val = work.result.values
    val.systemId = data.id
    cb null, work.result

runDmidecode = (work, cb) ->
  # run first alternative: lshw -json
  Exec.run
    remote: work.config.remote
    cmd: 'dmidecode'
    priority: 'immediately'
  , (err, proc) ->
    # run second alternative

    cb null, work.result

runCore = (work, cb) ->
  # run first alternative: lshw -json
  async.map [
    remote: config.remote
    cmd: 'lscpu'
    priority: 'immediately'
  ,
    remote: config.remote
    cmd: 'lspci'
    priority: 'immediately'
  ,
    remote: config.remote
    cmd: 'lsusb'
    priority: 'immediately'
#   cat /proc/cpuinfo
#   cat /proc/diskstats
  ], (setup, cb) ->
    Exec.run setup, cb
  , (err, proc) ->
    # run second alternative

    cb null, work.result

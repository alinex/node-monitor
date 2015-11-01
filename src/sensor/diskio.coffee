# Check Disk IO
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
# But the analysis part currently only works on linux.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:diskio')
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
  title: "Disk IO Test"
  description: "the configuration for the disk input/output check"
  type: 'object'
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on this to run the command"
      type: 'string'
    device:
      title: "Device name"
      description: "the disk's device name like sda, ..."
      type: 'string'
    warn: sensor.schema.warn
    fail: sensor.schema.fail

# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Disk IO'
  description: "Check the disk io traffic."
  category: 'sys'
  hint: "If there are any problems here check the device for hardware or
  network problems."

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    read:
      title: "Read operations/s"
      description: "the amount of operations to read from the device per second"
      type: 'float'
    write:
      title: "Write operation/s"
      description: "the amount of operations to written to the device per second"
      type: 'float'
    readSize:
      title: "Read/s"
      description: "the amount of data read from the device per second"
      type: 'byte'
      unit: 'B'
    writeSize:
      title: "Write/s"
      description: "the amount of data written to the device per second"
      type: 'byte'
      unit: 'B'
    readTotal:
      title: "Total Read"
      description: "the total amount of read data"
      type: 'byte'
      unit: 'B'
    writeTotal:
      title: "Total Write"
      description: "the total amount of written data"
      type: 'byte'
      unit: 'B'
    readTime:
      title: "Read/s"
      description: "the amount of data read from the device per second"
      type: 'interval'
      unit: 'ms'
    writeTime:
      title: "Write/s"
      description: "the amount of data written to the device per second"
      type: 'interval'
      unit: 'ms'

# Run the Sensor
# -------------------------------------------------
exports.run = (name, config, cb = ->) ->
  work =
    sensor: this
    name: name
    config: config
    result: {}
  timerange = 3
  sensor.start work
  # run check
  async.map [
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "grep #{config.device} /proc/diskstats"]
    priority: 'immediately'
  ,
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "sleep #{timerange} && grep #{config.device} /proc/diskstats"]
    priority: 'immediately'
  ], (setup, cb) ->
    Exec.run setup, cb
  , (err, proc) ->
    sensor.end work
    # analyse results
    if err
      work.err = err
    else
      val = work.result.values
      # calculate diffs
      l1 = proc[0].stdout().trim().split(/\s+/)
      l2 = proc[1].stdout().trim().split(/\s+/)
      val.read = (Number(l2[3]) - Number(l1[3])) / timerange
      val.write = (Number(l2[7]) - Number(l1[7])) / timerange
      val.readSize = (Number(l2[5]) - Number(l1[5])) / timerange * 512
      val.writeSize = (Number(l2[9]) - Number(l1[9])) / timerange * 512
      val.readTotal = Number(l2[5]) * 512
      val.writeTotal = Number(l2[9]) * 512
      val.readTime = (Number(l2[6]) - Number(l1[6])) / timerange
      val.writeTime = (Number(l2[10]) - Number(l1[10])) / timerange
      sensor.result work
      cb err, work.result

# Run additional analysis
# -------------------------------------------------
exports.analysis = (name, config, cb = ->) ->
  cb()

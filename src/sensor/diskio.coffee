# Check Disk IO
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
exports.debug = debug = require('debug')('monitor:sensor:diskio')
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
  title: "Disk IO Test"
  description: "the configuration for the disk input/output check"
  type: 'object'
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on which to run the command"
      type: 'string'
      values: Object.keys config.get('/exec/remote/server') ? {}
    device:
      title: "Device name"
      description: "the disk's device name like sda, ..."
      type: 'string'
    time:
      title: "Measurement Time"
      description: "the time for the measurement"
      type: 'interval'
      unit: 's'
      default: 10
      min: 1
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
      title: "Read Time/s"
      description: "the amount of data read from the device per second"
      type: 'interval'
      unit: 'ms'
    writeTime:
      title: "Write Time/s"
      description: "the amount of data written to the device per second"
      type: 'interval'
      unit: 'ms'



# Initialize check
# -------------------------------------------------
# This method is used for some precalculations or analyzations and should set:
#
# - check.name = <string> # mandatory
# - check.base = <object> # optionally
exports.init = (cb) ->
  @name ?= "#{@conf.remote ? 'localhost'}:#{@conf.device}"
  cb()


# Run the Sensor
# -------------------------------------------------
exports.run = (cb) ->
  # run check
  async.map [
    remote: @conf.remote
    cmd: 'sh'
    args: ['-c', "grep #{@conf.device} /proc/diskstats"]
    priority: 'immediately'
  ,
    remote: @conf.remote
    cmd: 'sh'
    args: ['-c', "sleep #{@conf.time} && grep #{@conf.device} /proc/diskstats"]
    priority: 'immediately'
  ], (setup, cb) ->
    Exec.run setup, cb
  , cb


# Get the results
# -------------------------------------------------
exports.calc = (cb) ->
  return cb() if @err
  res = @result.data
  # calculate diffs
  l1 = res[0].stdout().trim().split(/\s+/)
  l2 = res[1].stdout().trim().split(/\s+/)
  @values.read = (Number(l2[3]) - Number(l1[3])) / @conf.time
  @values.write = (Number(l2[7]) - Number(l1[7])) / @conf.time
  @values.readSize = (Number(l2[5]) - Number(l1[5])) / @conf.time * 512
  @values.writeSize = (Number(l2[9]) - Number(l1[9])) / @conf.time * 512
  @values.readTotal = Number(l2[5]) * 512
  @values.writeTotal = Number(l2[9]) * 512
  @values.readTime = (Number(l2[6]) - Number(l1[6])) / @conf.time
  @values.writeTime = (Number(l2[10]) - Number(l1[10])) / @conf.time
  cb()

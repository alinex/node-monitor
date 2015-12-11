# Check cpu core
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
exports.debug = debug = require('debug')('monitor:sensor:memory')
# include alinex modules
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
  title: "Memory check"
  description: "the memory usage on the machine"
  type: 'object'
  default:
    warn: 'free < 1%'
    analysis:
      minMem: 0.1
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on which to run the command"
      type: 'string'
    warn:
      title: "Warn if"
      description: "the javascript code to check to set status to warn"
      type: 'string'
      default: 'free < 1%'
    fail:
      title: "Fail if"
      description: "the javascript code to check to set status to fail"
      type: 'string'
      optional: true


# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Memory'
  description: "Check the free and used memory."
  category: 'sys'
  hint: "Check which process consumes how much memory, maybe some processes have
    a memory leak."

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    total:
      title: "Total"
      description: "total system memory"
      type: 'byte'
      unit: 'B'
    used:
      title: "Used"
      description: "used system memory"
      type: 'byte'
      unit: 'B'
    free:
      title: "Free"
      description: "free system memory"
      type: 'byte'
      unit: 'B'
    shared:
      title: "Shared"
      description: "shared system memory"
      type: 'byte'
      unit: 'B'
    buffers:
      title: "Buffers"
      description: "system memory used as buffer"
      type: 'byte'
      unit: 'B'
    cached:
      title: "Cached"
      description: "system memory used as cache"
      type: 'byte'
      unit: 'B'
    swapTotal:
      title: "Swap Total"
      description: "total swap memory"
      type: 'byte'
      unit: 'B'
    swapUsed:
      title: "Swap Used"
      description: "used swap memory"
      type: 'byte'
      unit: 'B'
    swapFree:
      title: "Swap Free"
      description: "free swap memory"
      type: 'byte'
      unit: 'B'
    actualFree:
      title: "Actual Free"
      description: "real free system memory"
      type: 'byte'
      unit: 'B'
    percentFree:
      title: "Percent Free"
      description: "percentage of real free system memory"
      type: 'percent'
    swapPercentFree:
      title: "Swap Percent Free"
      description: "percentage of free swap memory"
      type: 'percent'


# Initialize check
# -------------------------------------------------
# This method is used for some precalculations or analyzations and should set:
#
# - check.name = <string> # mandatory
# - check.base = <object> # optionally
exports.init = (cb) ->
  @name = @conf.remote ? 'localhost'
  cb()


# Run the Sensor
# -------------------------------------------------
exports.run = (cb) ->
  # run check
  Exec.run
    remote: @conf.remote
    cmd: 'cat'
    args: ['/proc/meminfo']
    priority: 'immediately'
  , cb


# Get the results
# -------------------------------------------------
exports.calc = (res, cb) ->
  return cb() if @err
  # calculate results
  for line in res.stdout().split /\n/
    col = line.split /\s+/
    switch col[0]
      when 'MemTotal:' then @values.total = col[1] * 1024
      when 'MemFree:' then @values.free = col[1] * 1024
      when 'MemShared:' then @values.shared = col[1] * 1024
      when 'Shmem:' then @values.shared = col[1] * 1024
      when 'Buffers:' then @values.buffers = col[1] * 1024
      when 'Cached:' then @values.cached = col[1] * 1024
      when 'SwapTotal:' then @values.swapTotal = col[1] * 1024
      when 'SwapFree:' then @values.swapFree = col[1] * 1024
  @values.used = @values.total - @values.free
  @values.swapUsed = @values.swapTotal - @values.swapFree
  @values.actualFree = @values.free + @values.buffers + @values.cached
  @values.percentFree = @values.actualFree/@values.total
  @values.swapPercentFree = @values.swapFree/@values.swapTotal
  cb()

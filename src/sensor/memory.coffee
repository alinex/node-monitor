# Check cpu core
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
# But the analysis part currently only works on linux.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:memory')
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
    warn: object.extend {}, sensor.schema.warn,
      default: 'free < 1%'
    fail: sensor.schema.fail
    analysis:
      title: "Analysis Run"
      description: "the configuration for the analysis if it is run"
      type: 'object'
      allowedKeys: true
      keys:
        minMem:
          title: "Minimum %MEM"
          description: "the minimum memory usage to include"
          type: 'percent'
          min: 0
          default: 0.1
        numProc:
          title: "Top X"
          description: "the number of top CPU heavy processes for analysis"
          type: 'integer'
          min: 1
          default: 5

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
  Exec.run
    remote: config.remote
    cmd: 'cat'
    args: ['/proc/meminfo']
    priority: 'immediately'
  , (err, proc) ->
    sensor.end work
    # analyse results
    if err
      work.err = err
    else
      val = work.result.values
      # calculate results
      for line in proc.stdout().split /\n/
        col = line.split /\s+/
        switch col[0]
          when 'MemTotal:' then val.total = col[1] * 1024
          when 'MemFree:' then val.free = col[1] * 1024
          when 'MemShared:' then val.shared = col[1] * 1024
          when 'Shmem:' then val.shared = col[1] * 1024
          when 'Buffers:' then val.buffers = col[1] * 1024
          when 'Cached:' then val.cached = col[1] * 1024
          when 'SwapTotal:' then val.swapTotal = col[1] * 1024
          when 'SwapFree:' then val.swapFree = col[1] * 1024
      val.used = val.total - val.free
      val.swapUsed = val.swapTotal - val.swapFree
      val.actualFree = val.free + val.buffers + val.cached
      val.percentFree = val.actualFree/val.total
      val.swapPercentFree = val.swapFree/val.swapTotal
      sensor.result work
      cb err, work.result

# Run additional analysis
# -------------------------------------------------
exports.analysis = (config, res, cb = ->) ->
  return cb() unless config.analysis?
  # get additional information
  if config.analysis.minMem
    min = Math.floor config.analysis.minMem * 100
    report = "The top memory consuming processes above #{min}% are:\n\n"
  else
    report = "The top #{config.analysis.numProc} memory consuming processes are:\n\n"
  report += """
    | COUNT |  %CPU |  %MEM | COMMAND                                            |
    | ----: | ----: | ----: | -------------------------------------------------- |\n"""
  Exec.run
    remote: config.remote
    cmd: 'sh'
    args: [
      '-c'
      "ps axu | awk 'NR>1 {print $2, $3, $4, $11}'"
    ]
    priority: 'immediately'
  , (err, proc) ->
    return cb err if err
    procs = {}
    for line in proc.stdout().split /\n/
      continue unless line
      col = line.split /\s/, 4
      procs[col[3]] ?= [ 0, 0, 0 ]
      procs[col[3]][0]++
      procs[col[3]][1] += parseFloat col[1]
      procs[col[3]][2] += parseFloat col[2]
    keys = Object.keys(procs).sort (a, b) ->
      procs[b][2] - procs[a][2]
    found = false
    num = 0
    for proc in keys
      num++
      value = procs[proc]
      continue if min and value[1] < min
      continue if config.analysis.numProc and num > config.analysis.numProc
      found = true
      value[1] = if value[1] > 100 then Math.floor value[1] else Math.round(value[1] * 10) / 10
      value[2] = if value[2] > 100 then Math.floor value[2] else Math.round(value[2] * 10) / 10
      report += "| #{string.lpad value[0], 5} | #{string.lpad value[1].toString() + '%', 5}
        | #{string.lpad value[2].toString() + '%', 5} | #{string.rpad proc, 50} |\n"
    if min and not found
      return cb null, "No high memory consuming processes over #{min}% found!"
    cb null, report

# Check cpu core
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
# But the analysis part currently only works on linux.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:cpu')
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
  title: "CPU check configuration"
  description: "the configuration to check the CPU utilization"
  type: 'object'
  default:
    warn: 'active >= 100%'
    analysis:
      minCpu: 0.1
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on which to run the command"
      type: 'string'
    time:
      title: "Measurement Time"
      description: "the time for the measurement"
      type: 'interval'
      unit: 's'
      default: 10
      min: 1
    warn: object.extend {}, sensor.schema.warn,
      default: 'active >= 100%'
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
          default: 5

# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'CPU'
  description: "Check the current activity in average percent of all cores."
  category: 'sys'
  hint: "A high CPU usage means that the server may not start another task immediately.
  If the load is also very high the system is overloaded, check if any application
  goes evil."

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    cpus:
      title: "CPU Cores"
      description: "number of cpu cores"
      type: 'integer'
    speed:
      title: "CPU Speed"
      description: "speed in MHz"
      type: 'integer'
      unit: 'MHz'
    user:
      title: "User Time"
      description: "percentage of user time over all cpu cores"
      type: 'percent'
    nice:
      title: "Nice User Time"
      description: "percentage of niced user time over all cpu cores"
      type: 'percent'
    system:
      title: "System Time"
      description: "percentage of system time over all cpu cores"
      type: 'percent'
    idle:
      title: "Idle Time"
      description: "percentage of idle time over all cpu cores"
      type: 'percent'
    active:
      title: "Activity"
      description: "percentage of active time over all cpu cores"
      type: 'percent'
    wait:
      title: "I/O Wait Time"
      description: "percentage of time waiting for I/O completion"
      type: 'percent'
    hwint:
      title: "Hardware Interrupt Time"
      description: "percentage of time spent serving hardware interrupts"
      type: 'percent'
    swint:
      title: "Software Interrupt Time"
      description: "percentage of time spent serving software interrupts"
      type: 'percent'
    low:
      title: "Lowest CPU Core"
      description: "percentage of lowest usage of a CPU core"
      type: 'percent'
    high:
      title: "Highest CPU Core"
      description: "percentage of highest usage of a CPU core"
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
    args: ['-c', "cat /proc/cpuinfo | egrep '(processor|cpu MHz)'"]
    priority: 'immediately'
  ,
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "grep cpu /proc/stat"]
    priority: 'immediately'
  ,
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "sleep #{config.time} && grep cpu /proc/stat"]
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
      # cpu info values
      val.cpus = 0
      val.speed = 0
      for line in proc[0].stdout().split /\n/
        match =  line.match(/^(\w+(?: \w+)*).*:\s+(.*)/)
        switch match[1]
          when 'processor' then val.cpus++
          when 'cpu MHz' then val.speed += Number match[2]
      val.speed /= val.cpus
      # cpu load
      l1 = proc[1].stdout().split(/\n/).map (line) ->
        line.split(/\s+/).map (c) ->
          if string.starts c, 'cpu' then 0 else Number c
      l2 = proc[2].stdout().split(/\n/).map  (line) ->
        line.split(/\s+/).map (c) ->
          if string.starts c, 'cpu' then 0 else Number c
      for num in [0..l1.length-1]
        l1[num][0] += c for c in l1[num][1..]
        l2[num][0] += c for c in l2[num][1..]
      # get percentage
      percent = (col) -> (l2[0][col] - l1[0][col]) / (l2[0][0] - l1[0][0])
      val.user = percent 1
      val.nice = percent 2
      val.system = percent 3
      val.idle = percent 4
      val.wait = percent 5
      val.hwint = percent 6
      val.swint = percent 7
      val.active = 1.0 - val.idle
      # get min/max cpus
      val.low = 1.0
      val.high = 0.0
      for num in [1..l1.length-1]
        active = 1.0 - (l2[num][4] - l1[num][4]) / (l2[num][0] - l1[num][0])
        val.low = active if active < val.low
        val.high = active if active > val.high
      sensor.result work
      cb err, work.result

# Run additional analysis
# -------------------------------------------------
exports.analysis = (config, res, cb = ->) ->
  return cb() unless config.analysis?
  # get additional information
  if config.analysis.minCpu
    min = Math.floor config.analysis.minCpu * 100
  criteria = if min then " above #{min}%" else ''
  criteria += if config.analysis.numProc
  then " (max. #{config.analysis.numProc})" else ''
  report = "The top CPU consuming processes#{criteria} are:\n\n"
  report += """
    | COUNT |  %CPU |  %MEM | COMMAND                                            |
    | ----: | ----: | ----: | -------------------------------------------------- |\n"""
  async.map [
    remote: config.remote
    cmd: 'sh'
    args: [
      '-c'
      "ps axu | awk 'NR>1 {print $2, $3, $4, $11}'"
    ]
    priority: 'immediately'
  ,
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "grep processor /proc/cpuinfo | wc -l"]
    priority: 'immediately'
  ], (setup, cb) ->
    Exec.run setup, cb
  , (err, proc) ->
    return cb err if err
    procs = {}
    for line in proc[0].stdout().split /\n/
      continue unless line
      cpus = Number proc[1].stdout()
      col = line.split /\s/, 4
      procs[col[3]] ?= [ 0, 0, 0 ]
      procs[col[3]][0]++
      procs[col[3]][1] += parseFloat col[1]
      procs[col[3]][2] += parseFloat col[2]
    keys = Object.keys(procs).sort (a, b) ->
      procs[b][1] - procs[a][1]
    found = false
    num = 0
    for proc in keys
      value = procs[proc]
      value[1] /= cpus
      continue if min and value[1] < min
      num++
      break if config.analysis.numProc and num > config.analysis.numProc
      found = true
      value[1] = if value[1] > 100 then Math.floor value[1] else Math.round(value[1] * 10) / 10
      value[2] = if value[2] > 100 then Math.floor value[2] else Math.round(value[2] * 10) / 10
      report += "| #{string.lpad value[0], 5} | #{string.lpad value[1].toString() + '%', 5}
        | #{string.lpad value[2].toString() + '%', 5} | #{string.rpad proc, 50} |\n"
    if min and not found
      return cb null, "No high cpu consuming processes over #{min}% found!"
    cb null, report

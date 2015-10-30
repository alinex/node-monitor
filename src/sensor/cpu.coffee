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
os = require 'os'
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
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on this to run the command"
      type: 'string'
    warn: object.extend {}, sensor.schema.warn,
      default: 'active >= 100%'
    fail: sensor.schema.fail
    analysis:
      title: "Analysis Run"
      description: "the configuration for the analysis if it is run"
      type: 'object'
      allowedKeys: true
      keys:
        procNum:
          title: "Top X"
          description: "the number of top cpu heavy processes for analysis"
          type: 'integer'
          min: 1
          default: 5

# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Cpu'
  description: "Check the current activity in average percent of all cores."
  category: 'sys'
  hint: "A high cpu usage means that the server may not start another task immediately.
  If the load is also very high the system is overloaded check if any application
  goes evil."

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    cpu:
      title: "CPU Model"
      description: "cpu model name with brand"
      type: 'string'
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
      description: "percentage of lowest usage of a cpu core"
      type: 'percent'
    high:
      title: "Highest CPU Core"
      description: "percentage of highest usage of a cpu core"
      type: 'percent'

# Run the Sensor
# -------------------------------------------------
exports.run = (name, config, cb = ->) ->
  work =
    sensor: this
    name: name
    config: config
    result: {}
  sensor.start work
  # run check
  async.map [
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "cat /proc/cpuinfo | egrep '(model name|processor|cpu MHz)'"]
#    | sort | uniq | sed 's/.*: //'"]
    priority: 'immediately'
    check:
      noExitCode: true
  ,
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "grep cpu /proc/stat"]
    priority: 'immediately'
    check:
      noExitCode: true
  ,
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "sleep 3 && grep cpu /proc/stat"]
    priority: 'immediately'
    check:
      noExitCode: true
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
          when 'model name' then val.cpu = match[2]
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
      val.user = (l2[0][1] - l1[0][1]) / (l2[0][0] - l1[0][0])
      val.nice = (l2[0][2] - l1[0][2]) / (l2[0][0] - l1[0][0])
      val.system = (l2[0][3] - l1[0][3]) / (l2[0][0] - l1[0][0])
      val.idle = (l2[0][4] - l1[0][4]) / (l2[0][0] - l1[0][0])
      val.wait = (l2[0][5] - l1[0][5]) / (l2[0][0] - l1[0][0])
      val.hwint = (l2[0][6] - l1[0][6]) / (l2[0][0] - l1[0][0])
      val.swint = (l2[0][7] - l1[0][7]) / (l2[0][0] - l1[0][0])
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

# Run the Sensor
# -------------------------------------------------
exports.analysis = (name, config, cb = ->) ->
  return cb() unless config.analysis?
  # get additional information
  report = analysis = """
    Currently the top #{config.analysis.procNum} cpu consuming processes are:

    |  PID  |  %CPU |  %MEM | COMMAND                                            |
    | ----: | ----: | ----: | -------------------------------------------------- |\n"""
  Exec.run
    cmd: 'sh'
    args: [
      '-c'
      "ps axu | awk '{print $2, $3, $4, $11}' | sort -k2 -nr | head -#{config.analysis.procNum}"
    ]
  , (err, proc) ->
    return cb err if err
    for line in proc.stdout().split /\n/
      continue unless line
      col = line.split /\s/, 4
      report += "| #{string.lpad col[0], 5} | #{string.lpad col[1], 5}
        | #{string.lpad col[2], 5} | #{string.rpad col[3], 50} |\n"
    cb null, report

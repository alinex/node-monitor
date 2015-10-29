# Check cpu core
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
# But the analysis part currently only works on linux.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:cpu')
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
    args: ['-c', "cat /proc/cpuinfo | egrep '(model name|processor|cpu MHz)'
    | sort | uniq | sed 's/.*: //'"]
    priority: 'immediately'
    check:
      noExitCode: true
  ,
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "top -b -n 1 | head -n 3 | tail -n 1"]
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
      [speed, model, ..., cpus] = proc[0].stdout().split /\n/
      val.speed = Number speed
      val.cpu = model.replace /\s+/g, ' '
      val.cpus = Number cpus
      # cpu load
      col = proc[1].stdout().split /\s+/
      val.user = 100 / Number col[1]
      val.system = 100 / Number col[3]
      val.nice = 100 / Number col[5]
      val.idle = 100 / Number col[7]
      val.active = 1 - 100 / val.idle
      val.wait = 100 / Number col[9]
      val.hwint = 100 / Number col[11]
      val.swint = 100 / Number col[13]
      sensor.result work
      cb err, work.result

# Run the Sensor
# -------------------------------------------------
exports.analysis = (name, config, cb = ->) ->
  return cb() unless config.analysis?
  # get additional information
  report = analysis = """
    Currently the top #{@config.analysis} cpu consuming processes are:

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

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
exports.debug = debug = require('debug')('monitor:sensor:cpu')
chalk = require 'chalk'
# include alinex modules
async = require 'alinex-async'
Exec = require 'alinex-exec'
{object, string} = require 'alinex-util'
Report = require 'alinex-report'


# Schema Definition
# -------------------------------------------------
# This is used as configuration specification and to add the default values for
# specific setting.
#
# It's an [alinex-validator](http://alinex.githhub.io/node-validator)
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
      description: "the remote server on which to run the command"
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
      default: 'active >= 100%'
    fail:
      title: "Fail if"
      description: "the javascript code to check to set status to fail"
      type: 'string'
      optional: true


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
  async.map [
    remote: @conf.remote
    cmd: 'sh'
    args: ['-c', "cat /proc/cpuinfo | egrep '(processor|cpu MHz)'"]
    priority: 'immediately'
  ,
    remote: @conf.remote
    cmd: 'sh'
    args: ['-c', "grep cpu /proc/stat"]
    priority: 'immediately'
  ,
    remote: @conf.remote
    cmd: 'sh'
    args: ['-c', "sleep #{@conf.time} && grep cpu /proc/stat"]
    priority: 'immediately'
  ], (setup, cb) ->
    Exec.run setup, cb
  , cb


# Get the results
# -------------------------------------------------
exports.calc = (res, cb) ->
  return cb() if @err
  # cpu info values
  @values.cpus = 0
  @values.speed = 0
  for line in res[0].stdout().split /\n/
    match =  line.match(/^(\w+(?: \w+)*).*:\s+(.*)/)
    switch match[1]
      when 'processor' then @values.cpus++
      when 'cpu MHz' then @values.speed += Number match[2]
  @values.speed /= @values.cpus
  # cpu load
  l1 = res[1].stdout().split(/\n/).map (line) ->
    line.split(/\s+/).map (c) ->
      if string.starts c, 'cpu' then 0 else Number c
  l2 = res[2].stdout().split(/\n/).map  (line) ->
    line.split(/\s+/).map (c) ->
      if string.starts c, 'cpu' then 0 else Number c
  for num in [0..l1.length-1]
    l1[num][0] += c for c in l1[num][1..]
    l2[num][0] += c for c in l2[num][1..]
  # get percentage
  percent = (col) -> (l2[0][col] - l1[0][col]) / (l2[0][0] - l1[0][0])
  @values.user = percent 1
  @values.nice = percent 2
  @values.system = percent 3
  @values.idle = percent 4
  @values.wait = percent 5
  @values.hwint = percent 6
  @values.swint = percent 7
  @values.active = 1.0 - @values.idle
  # get min/max cpus
  @values.low = 1.0
  @values.high = 0.0
  for num in [1..l1.length-1]
    active = 1.0 - (l2[num][4] - l1[num][4]) / (l2[num][0] - l1[num][0])
    @values.low = active if active < @values.low
    @values.high = active if active > @values.high
  cb()

# Check disk space
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
# But the analysis part currently only works on linux.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:user')
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
  title: "User Check"
  description: "the setup to check for an active users"
  type: 'object'
  allowedKeys: true
  mandatoryKeys: ['user']
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on this to run the command"
      type: 'string'
    user:
      title: "Username to check"
      description: "the local user name to check"
      type: 'string'
    warn: sensor.schema.warn
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
          default: 0.01
        minMem:
          title: "Minimum %MEM"
          description: "the minimum memory usage to include"
          type: 'percent'
          min: 0
          default: 0.01
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
  title: 'Active User'
  description: "Check what an active user do."
  category: 'sys'
  hint: "This check will give an overview of the activities of an (logged in) user.
  If you look at the processes you may find out that some other warnings
  like high load are user made and you may contact this person directly. "

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    num:
      title: 'Processes'
      description: "number of running processes"
      type: 'integer'
    cpu:
      title: '% CPU'
      description: "usage of CPU"
      type: 'percent'
    memory:
      title: '% Memory'
      description: "usage of Memory"
      type: 'percent'
    rss:
      title: 'Physical Memory'
      description: "resident set size, the non-swapped physical memory"
      type: 'byte'
      unit: 'B'
    vss:
      title: 'Virtual Memory'
      description: "virtual memory usage"
      type: 'byte'
      unit: 'B'

# Get content specific name
# -------------------------------------------------
exports.name = (config) -> config.user

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
    args: ['-c', "ps -U #{config.user} --no-headers -o pcpu,pmem,vsz,rss
    | awk '{n++; pcpu+=$1; pmem+=$2; rss+=$3; vmem+=$4}
    END{print n\" \"pcpu\" \"pmem\" \"rss\" \"vmem}'"]
    priority: 'immediately'
  ,
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "grep processor /proc/cpuinfo | wc -l"]
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
      cpus = Number proc[1].stdout()
      col = proc[0].stdout().split /\s+/
      val.num = Number col[0]
      val.cpu = Number(col[1]) / 100 / cpus
      val.memory = Number(col[2]) / 100
      val.rss = Number col[3]
      val.vss = Number col[4]
    sensor.result work
    cb err, work.result

# Run the Sensor
# -------------------------------------------------
exports.analysis = (config, res, cb = ->) ->
  return cb() unless config.analysis?
  # get additional information
  async.map [
    remote: config.remote
    cmd: 'who'
    priority: 'immediately'
  ,
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "ps aux --no-headers | egrep ^#{config.user} | sort -k3 -n -r"]
    priority: 'immediately'
  ], (setup, cb) ->
    Exec.run setup, cb
  , (err, proc) ->
    return cb err if err
    report = ''
    if proc[1].stdout()?
      if config.analysis.minCpu
        minCpu = Math.floor config.analysis.minCpu * 100
      if config.analysis.minCpu
        minMem = Math.floor config.analysis.minMem * 100
      criteria = if minCpu then " above #{minCpu}% CPU" else ''
      criteria += if minMem then " above #{minMem}% MEM" else ''
      criteria += if config.analysis.numProc
      then " (max. #{config.analysis.numProc} processes)" else ''
      report = "The top CPU consuming processes#{criteria} are:\n\n"
      report += """
        |  PID  | %CPU | %MEM |   VSZ   |   RSS  |  TIME |           COMMAND         |
        | ----- | ---- | ---- | ------- | ------ | ----- | ------------------------- |\n"""#
      num = 0
      for line in proc[1].stdout().split /\n/
        col = line.trim().split /\s+/
        continue if minCpu and col[2] < minCpu
        continue if minMem and col[3] < minMem
        num++
        break if config.analysis.numProc and num > config.analysis.numProc

        report += "| #{string.lpad col[1], 5}
        | #{string.lpad col[2], 4} | #{string.lpad col[3], 4} | #{string.lpad col[4], 7}
        | #{string.lpad col[5], 6} | #{string.lpad col[9], 5} | #{string.rpad col[10], 25} |\n"
    if proc[0].stdout()?
      report += """
        \nThe active logins are:

        |   TERM    |    LOGIN     |         IP         |
        | --------- | ------------ | ------------------ |\n"""#
      for line in proc[0].stdout().split /\n/
        col = line.trim().split /\s+/
        report += "| #{string.rpad col[1], 9} | #{col[2]} #{col[3]} #{col[4]}
        | #{string.lpad col[5].replace(/[():]/g, ''), 18} |\n"
    cb null, report

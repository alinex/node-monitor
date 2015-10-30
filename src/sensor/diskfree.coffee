# Check disk space
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
# But the analysis part currently only works on linux.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:diskfree')
os = require 'os'
math = require 'mathjs'
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
  title: "Disk Free Test"
  description: "the setup for a check for free disk space"
  type: 'object'
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on this to run the command"
      type: 'string'
    share:
      title: "Share or Mount"
      description: "the disk share's path or mount point to check"
      type: 'string'
#    timeout:
#      title: "Measurement Time"
#      description: "the time in milliseconds the whole test may take before
#        stopping and failing it"
#      type: 'interval'
#      unit: 'ms'
#      min: 500
#      default: 5000
#    analysisTimeout:
#      title: "Analysis Time"
#      description: "the time in milliseconds the analysis test may take before
#        stopping and failing it"
#      type: 'interval'
#      unit: 'ms'
#      min: 500
#      default: 5000
    warn: sensor.schema.warn
    fail: object.extend {}, sensor.schema.fail,
      default: 'free is 0'
    analysis:
      title: "Analysis Run"
      description: "the configuration for the analysis if it is run"
      type: 'object'
      allowedKeys: true
      keys:
        dirs:
          title: "Analysis Paths"
          description: "the list of directories to monitor their volume"
          type: 'array'
          delimiter: /,\s+/
          entries:
            title: "Directory"
            description: "the list of directories to check for waste of space"
            type: 'string'

# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Diskfree'
  description: "Test the free diskspace of one share."
  category: 'sys'
  hint: "If a share is full it will make I/O problems in the system or applications
  in case of the root partition it may also neither be possible to log errors.
  Maybe some old files like temp or logs can be removed or compressed. "

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    share:
      title: 'Share'
      description: "path name of the share"
      type: 'string'
    type:
      title: 'Type'
      description: "type of filesystem"
      type: 'string'
    total:
      title: 'Available'
      description: "the space, which is available"
      type: 'byte'
      unit: 'B'
    used:
      title: 'Used'
      description: "the space, which is already used"
      type: 'byte'
      unit: 'B'
    usedPercent:
      title: '% Used'
      description: "the space, which is already used"
      type: 'percent'
    free:
      title: 'Free'
      description: "the space, which is free"
      type: 'byte'
      unit: 'B'
    freePercent:
      title: '% Free'
      description: "the space, which is free"
      type: 'percent'
    mount:
      title: 'Mountpoint'
      description: "the path this share is mounted to"
      type: 'string'

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
  Exec.run
    remote: config.remote
    cmd: 'df'
    args: ['-kT', config.share]
    priority: 'immediately'
    check:
      noExitCode: true
  , (err, proc) ->
    sensor.end work
    # analyse results
    if err
      work.err = err
    else
      val = work.result.values
      lines = proc.stdout().split /\n/
      col = lines[1].split /\s+/
      val.share = col[0]
      val.type = col[1]
      val.used = Number(col[3])*1024
      val.free = Number(col[4])*1024
      val.total = val.used + val.free
      val.mount = col[6]
      val.usedPercent = val.used / val.total
      val.freePercent = val.free / val.total
    sensor.result work
    cb err, work.result

# Run the Sensor
# -------------------------------------------------
exports.analysis = (name, config, cb = ->) ->
  return cb() unless config.analysis?
  # get additional information
  report = analysis = """
    Maybe some files in one of the following directories may be deleted or moved:

    | PATH                                |  FILES   |    SIZE    |   OLDEST    |
    | ----------------------------------- | -------: | ---------: | :---------- |\n"""
  async.mapLimit config.analysis.dirs, os.cpus().length, (dir, cb) ->
    Exec.run
      cmd: 'sh'
      args: [
        '-c'
        "find #{dir} -type f -exec ls -ltr --time-style=+%Y-%m-%d {} +
        | awk '{n++;b+=$5;if(d==\"\"){d=$6};if(d>$6){d=$6}} END{print n,b,d}'"
      ]
    , (err, proc) ->
      return cb err if err
      exact = if proc.stderr() then '*' else ' '
      unless stdout = proc.stdout()
        return cb null, "| #{string.rpad dir, 35} |        ? |          ? |      ?      |\n"
      col = stdout.split /\s+/
      byte = math.unit parseInt(col[1]), 'B'
      cb null, "| #{string.rpad dir, 35} | #{string.lpad col[0], 7}#{exact}
      | #{string.lpad byte.format(3), 9}#{exact}
      | #{string.lpad col[2], 10}#{exact} |\n"
  , (err, res) ->
    # add together
    report += res.join ''
    # add comment for *
    if report.match /\* \|/
      report += "\n__(*)__\n: The rows marked with a '*' are only assumptions, because not all
      \nfiles were readable. All the values are minimum values, the real values may
      \nbe higher.\n"
    if report.match /\? \|/
      report += "\n__(?)__\n: The rows marked with a '?' as value could not be determinded, mostly
      \nbecause their content is too large to discover in time.\n"
    cb null, report

# Check disk space
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
# But the analysis part currently only works on linux.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:diskfree')
chalk = require 'chalk'
os = require 'os'
# include alinex modules
async = require 'alinex-async'
Exec = require 'alinex-exec'
{object} = require 'alinex-util'
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
    analysis:
      title: "Analysis Paths"
      description: "list of directories to monitor their volume on warning"
      type: 'array'
      optional: true
      delimiter: /,\s+/
      entries:
        title: "Directory"
        type: 'string'
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
    name: "#{name}:#{@meta.title.toLowerCase()}"
    config: config
    result: {}
  sensor.start work
  # run check
  Exec.run
    remote: config.remote
    cmd: 'df'
    args: ['-kT', config.share]
    check:
      noExitCode: true
  , (err, exec) ->
    sensor.end work
    # analyse results
    if err
      work.err = err
    else
      val = work.result.values
      lines = exec.stdout().split /\n/
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
exports.analysis = (name, config, result, cb = ->) ->
  return cb() config.analysis?.length
  # get additional information
  result.analysis = """
    Maybe some files in one of the following directories may be deleted or moved:
    | PATH                                |  FILES  |    SIZE    |   OLDEST   |
    | ----------------------------------- | ------: | ---------: | :--------- |\n"""
  async.mapLimit config.analysis, os.cpus().length, (dir, cb) ->
    Exec.run
      cmd: 'find'
      args: [
        dir
        '-type', 'f'
        '-exec', 'ls'
        '-ltr'
        '--time-style=+%Y-%m-%d'
        '{}'
        '\\;'
      ]
#    | awk '{n++;b+=$5;if(d==\"\"){d=$6};if(d>$6){d=$6}} END{print n,b,d}'"
#    exec cmd,
#      timeout: @config.analysisTimeout
#    , (err, stdout, stderr) ->
#      unless stdout
#        return cb null, "| #{string.rpad dir, 35} |       ? |          ? | ?          |\n"
#      col = stdout.toString().split /\s+/
#      byte = math.unit parseInt(col[1]), 'B'
#      cb null, "| #{string.rpad dir, 35} | #{string.lpad col[0], 7}
#      | #{string.lpad byte.format(3), 10}
#      | #{string.lpad col[2], 10} |\n"
#  , (err, lines) =>
#    @result.analysis += line for line in lines
#    debug @result.analysis
#    @_end status, message, cb

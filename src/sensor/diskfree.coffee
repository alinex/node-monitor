# Check disk space
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
exports.debug = debug = require('debug')('monitor:sensor:diskfree')
# include alinex modules
Exec = require 'alinex-exec'


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
      description: "the remote server on which to run the command"
      type: 'string'
    share:
      title: "Share or Mount"
      description: "the disk share's path or mount point to check"
      type: 'string'
    timeout:
      title: "Measurement Time"
      description: "the time in milliseconds the whole test may take before
        stopping and failing it"
      type: 'interval'
      unit: 'ms'
      min: 500
      default: 5000
    warn:
      title: "Warn if"
      description: "the javascript code to check to set status to warn"
      type: 'string'
      optional: true
      default: 'freePercent < 10%'
    fail:
      title: "Fail if"
      description: "the javascript code to check to set status to fail"
      type: 'string'
      optional: true
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
    mount:
      title: 'Mountpoint'
      description: "the path this share is mounted to"
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


# Initialize check
# -------------------------------------------------
# This method is used for some precalculations or analyzations and should set:
#
# - check.name = <string> # mandatory
# - check.base = <object> # optionally
exports.init = (cb) ->
  @name = "#{@conf.remote ? 'localhost'}:#{@conf.share}"
  cb()


# Run the Sensor
# -------------------------------------------------
exports.run = (cb) ->
  # run check
  Exec.run
    remote: @conf.remote
    cmd: 'df'
    args: ['-kT', @conf.share]
    priority: 'immediately'
    timeout: @conf.timeout
    check:
      noExitCode: true
  , cb


# Get the results
# -------------------------------------------------
exports.calc = (res, cb) ->
  return cb() if @err
  # cpu info values
  lines = res.stdout().split /\n/
  col = lines[1].split /\s+/
  @values.share = col[0]
  @values.type = col[1]
  @values.used = Number(col[3])*1024
  @values.free = Number(col[4])*1024
  @values.total = @values.used + @values.free
  @values.mount = col[6]
  @values.usedPercent = @values.used / @values.total
  @values.freePercent = @values.free / @values.total
  cb()

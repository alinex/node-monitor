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
exports.debug = debug = require('debug')('monitor:sensor:user')
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
  title: "User Check"
  description: "the setup to check for an active users"
  type: 'object'
  allowedKeys: true
  mandatoryKeys: ['user']
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on which to run the command"
      type: 'string'
    user:
      title: "Username to check"
      description: "the local user name to check"
      type: 'string'
    warn:
      title: "Warn if"
      description: "the javascript code to check to set status to warn"
      type: 'string'
      optional: true
    fail:
      title: "Fail if"
      description: "the javascript code to check to set status to fail"
      type: 'string'
      optional: true


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


# Initialize check
# -------------------------------------------------
# This method is used for some precalculations or analyzations and should set:
#
# - check.name = <string> # mandatory
# - check.base = <object> # optionally
exports.init = (cb) ->
  @name ?= @conf.remote ? 'localhost'
  cb()


# Run the Sensor
# -------------------------------------------------
exports.run = (cb) ->
  # run check
  async.map [
    remote: @conf.remote
    cmd: 'sh'
    args: ['-c', "ps -U #{@conf.user} --no-headers -o pcpu,pmem,vsz,rss
    | awk '{n++; pcpu+=$1; pmem+=$2; rss+=$3; vmem+=$4}
    END{print n\" \"pcpu\" \"pmem\" \"rss\" \"vmem}'"]
    priority: 'immediately'
  ,
    remote: @conf.remote
    cmd: 'sh'
    args: ['-c', "grep processor /proc/cpuinfo | wc -l"]
    priority: 'immediately'
  ], (setup, cb) ->
    Exec.run setup, cb
  , cb


# Get the results
# -------------------------------------------------
exports.calc = (res, cb) ->
  return cb() if @err
  cpus = Number res[1].stdout()
  col = res[0].stdout().split /\s+/
  @values.num = Number col[0]
  @values.cpu = Number(col[1]) / 100 / cpus
  @values.memory = Number(col[2]) / 100
  @values.rss = Number col[3]
  @values.vss = Number col[4]
  cb()

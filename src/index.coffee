# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor')
async = require 'async'
os = require 'os'
util = require 'util'
yargs = require 'yargs'
chalk = require 'chalk'
# include alinex modules
Config = require 'alinex-config'
validator = require 'alinex-validator'
error = require 'alinex-error'
# include classes and helpers
Controller = require './controller'
check = require './check'
error.install()

# Start argument parsing
# -------------------------------------------------
GLOBAL.argv = yargs
.usage("""
  Server monitoring toolkit.

  Usage: $0 [-vC]
  """)
# examples
.example('$0', 'to simply check all controllers once')
.example('$0 -v', 'to get more information of each check')
# general options
.boolean('C')
.alias('C', 'nocolors')
.describe('C', 'turn of color output')
.boolean('v')
.alias('v', 'verbose')
.describe('v', 'run in verbose mode')
# general help
.help('h')
.alias('h', 'help')
.showHelpOnFail(false, "Specify --help for available options")
.argv
# implement some global switches
chalk.enabled = false if argv.nocolors

console.log chalk.blue.bold "Starting system checks..."

# Definition of Configuration
# -------------------------------------------------
# The configuration will be set in the [alinex-validator](http://alinex.github.io/node-validator)
# style. It will be checked after configuration load.
config = Config.instance 'monitor'
config.setCheck (source, values, cb) ->
  validator.check source, check.monitor, values, (err, result) ->
    return cb err if err
    # additional checks
    for key, value of result.contacts
      continue unless value instanceof Array
      for entry in value
        unless result.contacts[entry]?
          return cb new Error "No matching entry '#{entry}' from group '#{key}' in #{source} found."
    cb null, result


# Initialize Monitor
# -------------------------------------------------

# list of all controllers
controller = {}

# do parallel config loading
debug "load configurations for #{os.hostname()}"
async.parallel
  # read monitor config
  config: (cb) ->
    config = Config.instance 'monitor'
    config.load cb
  # get controller configuration
  controller: (cb) ->
    # find controller configs in folder
    Config.find 'controller', (err, list) ->
      return cb err if err
      async.map list, (name, cb) ->
        # add controller check
        config = Config.instance name
        config.setCheck Controller.check
        config.load (err, config) ->
          return cb err if err
          # return controller name
          cb null, name
      , cb
, (err, {config,controller}) ->
  return error.report err if err
#    # filter out all not relevant controllers
#    controller = controller.filter (n) -> n?
  debug "start monitor on #{os.hostname()}"
  status = 'undefined'
  async.each controller, (ctrl, cb) ->
    Controller.run ctrl, (err, instance) ->
      return cb err if err
      # overall status
      if instance.result.status is 'fail' or status is 'undefined' or \
      status is 'disabled' or (status is 'ok' and instance.result.status is 'warn')
        status = instance.result.status
      # skip output if disabled
      return cb null, instance if instance.result.status is 'disabled'
      # output
      console.log "#{instance.result.date} - #{instance.name} -
        #{colorStatus instance.result.status}"
      if argv.verbose or instance.result.status in ['warn', 'fail']
        console.log '  ' + wordwrap(instance.format()).replace /\n/g, '\n  '
      cb null, instance
  , (err, instances) ->
    throw err if err
    console.log "\nMONITOR DONE => #{colorStatus status}"
    # return with exit code
    switch status
      when 'warn'
        process.exit 1
      when 'fail'
        process.exit 2
      when 'ok', 'disabled'
        process.exit 0
      else
        process.exit 3


# Helper to colorize output
# -------------------------------------------------
colorStatus = (status, text) ->
  text = status unless text?
  switch status
    when 'ok'
      chalk.green text
    when 'warn'
      chalk.yellow text
    when 'fail'
      chalk.red text
    when 'disabled'
      chalk.grey text
    else
      text

# ### WordWrap
#
# - width -
#   maximum amount of characters per line
# - break
#   string that will be added whenever it's needed to break the line
# - cutType
#   0 = words longer than "maxLength" will not be broken
#   1 = words will be broken when needed
#   2 = any word that trespass the limit will be broken
wordwrap = (str, width = 100, brk = '\n', cut = 1) ->
  return str unless str and width
  l = (r = str.split("\n")).length
  i = -1
  while ++i < l
    s = r[i]
    r[i] = ""
    while s.length > width
      j = (if cut is 2 or (j = s.slice(0, width + 1).match(/\S*(\s)?$/))[1] then \
      width else j.input.length - j[0].length or cut is 1 and m or \
      j.input.length + (j = s.slice(m).match(/^\S*/)).input.length)
      r[i] += s.slice(0, j) + ((if (s = s.slice(j)).length then brk else ""))
    r[i] += s
  r.join "\n"

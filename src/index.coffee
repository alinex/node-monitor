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

  Usage: $0 [-vCclt] <controller...>
  """)
# examples
.example('$0', 'to simply check all controllers once')
.example('$0 -v', 'to get more information of each check')
.example('$0 -l', 'to list the possible checks')
.example('$0 -c rz:web1:cpu', 'to call a single controller')
# general options
.alias('C', 'nocolors')
.describe('C', 'turn of color output')
.boolean('C')
.alias('v', 'verbose')
.describe('v', 'run in verbose mode')
.boolean('v')
.alias('l', 'list')
.describe('l', 'list the configured controllers')
.boolean('l')
.alias('t', 'tree')
.describe('t', 'show the controller list as tree')
.boolean('t')
# general help
.help('h')
.alias('h', 'help')
.showHelpOnFail(false, "Specify --help for available options")
.argv
# implement some global switches
chalk.enabled = false if argv.nocolors


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


# Get list of controllers
# -------------------------------------------------
list = (cb) ->
  Config.find 'controller', (err, list) ->
    return cb err if err
    # if no controller specified, get list of all
    if not argv._.length
      controller = list
    else
      if typeof argv._ is 'string'
        controller = [argv._]
      else
        # get collection
        controller = []
        for name in argv._
          ########## TODO add posibility for using wildcards
          controller.push name if name in list
    cb null, controller

# Read configuration
# -------------------------------------------------
config = (cb) ->
  debug "load configuration"
  list (err, controller) ->
    return cb err if err
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
            config.load (err) -> cb err, name
          , cb
    , (err, {config,list}) ->
      cb err,
        config: config
        controller: controller

# Start routine
# -------------------------------------------------
exitCodes =
  warn: 1
  fail: 2
  ok: 0
  disabled: 0
config (err, {config,controller}) ->
  throw err if err
  debug "initialized with #{controller.length} controllers"
  # check what to do
  if argv.tree
    console.log chalk.blue.bold "Tree view of configured controllers\n"
    done = {}
    trees = {}
    root = {}
    # calculate the tree recursively
    tree = (name) ->
      ctrlConfig = Config.instance(name).data
      console.log name, ctrlConfig
      trees[name] = "- #{name} - #{ctrlConfig.name}"
      for depend in ctrlConfig.depend
        continue unless depend.controller?
        tree depend.controller unless done[depend.controller]?
        delete root[depend.controller]
        trees[name] += "\n  #{trees[depend.controller].replace /\n/g, '\n  '}"
      done[name] = true
      root[name] = true
    # make structures by calling above method
    for name in controller
      tree name unless done[name]?
    # output result
    for name of root
      console.log trees[name]
  else if argv.list
    console.log chalk.blue.bold "List configured controllers\n"
    for name in controller
      ctrlConfig = Config.instance(name).data
      console.log "- #{name} - #{ctrlConfig.name}"
      if argv.verbose
        console.log chalk.grey "  #{ctrlConfig.description.trim()}" if ctrlConfig.description
  else
    console.log chalk.blue.bold "Run sensors once...\n"
    return run config, controller, (err, status) ->
      throw err if err
      console.log chalk.bold "\nDone => #{colorStatus status}\n"
      code = exitCodes[status]?
      #process.exit code ? 3
  console.log chalk.green.bold "\nDone.\n"


# Monitoring run
# -------------------------------------------------
run = (config, controller, cb) ->
  debug "run monitor on #{os.hostname()}"
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
      if argv.verbose or instance.result.sensorStatus in ['warn', 'fail']
        console.log '  ' + wordwrap(instance.format()).replace /\n/g, '\n  '
      cb null, instance
  , (err) ->
    return cb err if err
    cb null, status


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

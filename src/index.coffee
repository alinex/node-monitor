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
Config.addCheck 'monitor', (source, values, cb) ->
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
    new Config 'monitor', cb
  # get controller
  controller: (cb) ->
    # find controller configs in folder
    Config.find 'controller', (err, list) ->
      return cb err if err
      async.map list, (name, cb) ->
        # add controller check
        Config.addCheck name, Controller.check, (err) ->
          return cb err if err
          # read in configuration
          new Config name, (err, config) ->
            return cb err if err
            #
            if config.runat? and config.runat isnt os.hostname()
              return cb null
            # return new controller instance
            cb null, new Controller config
      , (err, results) ->
        return cb err if err
        cb null, results
, (err, {config,controller}) ->
  if err
    error.report err
  else
    # filter out all not relevant controllers
    controller = controller.filter (n) -> n?
    run controller

# Run Monitor
# -------------------------------------------------
# Currently this will step over all defined controllers running each and output
# the results.
run = (controller) ->
  debug "start monitor on #{os.hostname()}"
  # check controller once
  status = 'undefined'
  async.each controller, (ctrl, cb) ->
    debug "run #{ctrl.name} controller"
    ctrl.run (err) ->
      return cb err if err
      # overall status
      if ctrl.status is 'fail' or status is 'undefined' or status is 'ok'
        status = ctrl.status
      # output
      console.log "#{ctrl.lastrun} - #{ctrl.name} - #{colorStatus ctrl.status}"
      if argv.verbose
        console.log "#{ctrl.config.name}:"
        for instance in ctrl.sensors
          out = {}
          for key, val of instance.config
            out[key] = val if val?
          console.log chalk.grey "values:  #{util.inspect(instance.result.value).replace /\n\s+/g, ' '}"
          console.log chalk.grey "config:  #{util.inspect(out).replace /\n\s+/g, ' '}"
          console.log chalk.grey "success: #{colorStatus instance.result.status}"
      if ctrl.message
        console.log chalk.yellow ctrl.message
      if ctrl.status in ['fail', 'warn']
        console.log chalk.magenta ctrl.config.hint
      cb()
  , (err) ->
    throw err if err
    console.log "DONE => #{colorStatus status}"
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
colorStatus = (status) ->
  switch status
    when 'ok'
      chalk.green status
    when 'warn'
      chalk.yellow status
    when 'fail'
      chalk.red status
    when 'disabled'
      chalk.grey status
    else
      status


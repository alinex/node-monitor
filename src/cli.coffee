# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor')
async = require 'alinex-async'
yargs = require 'yargs'
chalk = require 'chalk'
fspath = require 'path'
# include alinex modules
config = require 'alinex-config'
# include classes and helpers
logo = require './logo'
monitor = require './index'
#Controller = require './controller'

# Start argument parsing
# -------------------------------------------------
argv = yargs
.usage("""
  #{logo}
  Usage: $0 [-vCclt] <controller...>
  """)
# examples
.example('$0', 'to simply check all services once')
.example('$0 -v', 'to get more information of each check')
.example('$0 -l', 'to list the possible groups and services')
.example('$0 rz:web1:cpu', 'to call a single service or group')
.example('$0 -d', 'run contineously as a daemon')
# general options
.alias('C', 'nocolors')
.describe('C', 'turn of color output')
.boolean('C')
.alias('v', 'verbose')
.describe('v', 'run in verbose mode')
.boolean('v')
.alias('l', 'list')
.describe('l', 'list the configured groups and services')
.boolean('l')
.alias('t', 'tree')
.describe('t', 'show the service list as tree')
.boolean('t')
.alias('r', 'reverse')
.describe('r', 'show the tree in reverse order (used by)')
.boolean('r')
.alias('d', 'daemon')
.describe('d', 'run as a daemon')
.boolean('d')
# general help
.help('h')
.alias('h', 'help')
.epilogue("For more information, look into the man page.")
.showHelpOnFail(false, "Specify --help for available options")
.strict()
.fail (err) ->
  console.error """
    #{logo}
    #{chalk.red.bold 'CLI Parameter Failure:'} #{chalk.red err}

    """
  process.exit 1
.argv
# implement some global switches
chalk.enabled = false if argv.nocolors

console.log require './logo'


monitor.setup argv._
# Setup
# -------------------------------------------------
# add schema for module's configuration
config.setSchema '/monitor', schema
# set module search path
config.register 'monitor', fspath.dirname __dirname


# register selected controllers from /etc/monitor-controller
if argv._.length
  # specific controllers only
  for ctrl in argv._
    config.register 'monitor', fspath.dirname(__dirname),
      uri: "#{ctrl}*"
      folder: 'controller'
      path: 'monitor/controller'
else
  # read all controllers
  config.register 'monitor-controller', fspath.dirname(__dirname),
    folder: 'controller'
    path: 'monitor/controller'

# Commands
# -------------------------------------------------

list = (conf) ->
  for ctrl of conf.controller
    console.log ctrl

tree = (conf) ->
  console.log "tree to be programmed..."

once = (conf) ->
  # run all sensor in parallel
  # debug call once
  # give output
  # collected results
  # output summary
  console.log "default to be programmed..."

daemon = (conf) ->
  # instantiate all controllers
  # call parallel
  # set Event for next call before running
  # check rules
  # send emails
  console.log "daemon to be programmed..."


# Main routine
# -------------------------------------------------
config.init (err) ->
  if err
    console.error chalk.red.bold "FAILED: #{err.message}"
    console.error err.description
    process.exit 1
  conf = config.get 'monitor'
  if argv.list
    list conf
  else if argv.tree or argv.reverse
    tree conf
  else if argv.daemon
    daedmon conf
  else
    once conf

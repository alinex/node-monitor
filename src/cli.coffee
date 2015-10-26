# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
async = require 'alinex-async'
yargs = require 'yargs'
chalk = require 'chalk'
fspath = require 'path'
# include alinex modules
config = require 'alinex-config'
Exec = require 'alinex-exec'
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


# Commands
# -------------------------------------------------

list = (conf) ->
  for ctrl of conf.controller
    console.log ctrl

tree = (conf) ->
  console.log "tree to be programmed..."

fail = (err) ->
  if err
    console.error chalk.red.bold "FAILED: #{err.message}"
    console.error err.description
    process.exit 1

# Main routine
# -------------------------------------------------
console.log require './logo'
monitor.setup argv._

console.log "Initializing..."
Exec.init (err) ->
  monitor.init (err) ->
    fail err
    conf = config.get 'monitor'
    if argv.list
      list conf
    else if argv.tree or argv.reverse
      tree conf
    else if argv.daemon
      monitor.start()
      monitor.on 'done', (ctrl) ->
    else
      monitor.on 'result', (ctrl) ->
        console.log '------- result', ctrl.name
      monitor.onetime (err, results) ->
        fail err
        console.log '------- done'

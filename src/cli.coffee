# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
yargs = require 'yargs'
chalk = require 'chalk'
fspath = require 'path'
moment = require 'moment'
# include alinex modules
async = require 'alinex-async'
config = require 'alinex-config'
# include classes and helpers
logo = require('./logo') 'Monitoring Application'
monitor = require './index'
#Controller = require './controller'

process.title = 'Monitor'

# Start argument parsing
# -------------------------------------------------
argv = yargs
.usage("""
  #{logo}
  Usage: $0 [-vCclt] <controller...>
  """)
# examples
.example('$0', 'to simply check all services once')
.example('$0 fileserv', 'to call a single service or group')
.example('$0 -d -C >/dev/null', 'run continuously as a daemon')
.example('$0 -tvvv', 'make a try run and show all details')
.example('$0 -i', 'run in interactive mode')
# general options
.alias('C', 'nocolors')
.describe('C', 'turn of color output')
.boolean('C')
.alias('v', 'verbose')
.describe('v', 'run in verbose mode (multiple makes more verbose)')
.count('verbose')
# controller run
.alias('t', 'try')
.describe('t', 'try run which prevent actors to run')
.boolean('t')
# daemon
.alias('d', 'daemon')
.describe('d', 'run as a daemon')
.boolean('d')
# exploring with special data
.alias('e', 'explore')
.describe('e', 'explorer to run with given data')
.alias('j', 'json')
.describe('j', 'json data for the explorer')
# interactive mode
.alias('i', 'interactive')
.describe('i', 'interactive mode')
.boolean('i')

.describe('ssh', 'info: ssh connection url')
.describe('key', 'info: ssh private key to connect')
.describe('pass', 'info: ss password to connect')
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
    console.error err.description if err.description
    process.exit 1

# Main routine
# -------------------------------------------------
console.log logo
monitor.setup argv._

console.log "Initializing..."
monitor.init (err) ->
  fail err
  conf = config.get 'monitor'
  if argv.info
    console.log 'Not implemented!'
  else if argv.list
    list conf
  else if argv.tree or argv.reverse
    tree conf
  else if argv.daemon
    monitor.start()
    monitor.on 'done', (ctrl) ->
  else
    monitor.on 'result', (ctrl) ->
      console.log chalk.grey "#{moment().format("YYYY-MM-DD HH:mm:ss")}
      Controller #{chalk.white ctrl.name} => #{ctrl.colorStatus()}"
    console.log "Analyzing systems..."
    monitor.onetime
      verbose: argv.verbose
    , (err, results) ->
      fail err
      console.log "Finished.\n"

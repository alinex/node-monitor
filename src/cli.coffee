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
{string} = require 'alinex-util'
Exec = require 'alinex-exec'
database = require 'alinex-database'
# include classes and helpers
logo = require('./logo') 'Monitoring Application'
monitor = require './index'
Report = require 'alinex-report'
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
.alias('c', 'command')
.describe('c', 'command to execute')
.array('c')
.alias('j', 'json')
.describe('j', 'json data for the command')
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


# Error management
# -------------------------------------------------
exit = (err) ->
  # exit without error
  process.exit 0 unless err
  # exit with error
  console.error chalk.red.bold "FAILED: #{err.message}"
  console.error err.description if err.description
  process.exit 1 unless argv.daemon
  monitor.stop()
  setTimeout ->
    process.exit 1
  , 2000

process.on 'SIGINT', -> exit new Error "Got SIGINT signal"
process.on 'SIGTERM', -> exit new Error "Got SIGTERM signal"
process.on 'SIGHUP', -> exit new Error "Got SIGHUP signal"
process.on 'SIGQUIT', -> exit new Error "Got SIGQUIT signal"
process.on 'SIGABRT', -> exit new Error "Got SIGABRT signal"
process.on 'exit', ->
  console.log "Goodbye\n"
  Exec.close()
  database.close()

# Main routine
# -------------------------------------------------
console.log logo
monitor.setup argv._

console.log "Initializing..."
monitor.init
  verbose: argv.verbose
  try: argv.try
, (err) ->
  exit err if err
  conf = config.get 'monitor'
  if argv.command
    # direct command given to execute
    args = argv.command.slice()
    args = args[0].trim().split /\s+/ if args.length is 1
    command = args.shift()
    if commands[command]?
      console.log ''
      commands[command].run args, (err) ->
        console.log ''
        exit err
    else
      console.log chalk.red "Unknown command #{chalk.bold command} use
      #{chalk.bold 'help'} for more information!"
      exit()
  else if argv.interactive
    # interactive console
    require('./prompt') conf
  else if argv.daemon
    # daemon start
    monitor.start()
  else
    # run all once
    console.log "Analyzing systems..."
    monitor.runController null, (err, results) ->
      exit err if err
      console.log "Finished.\n"
      exit()

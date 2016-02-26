# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
yargs = require 'yargs'
chalk = require 'chalk'
# include alinex modules
config = require 'alinex-config'
Exec = require 'alinex-exec'
database = require 'alinex-database'
# include classes and helpers
logo = require('alinex').logo 'Monitoring Application'
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
# parse data
argv.json = JSON.parse argv.json if argv.json
# implement some global switches
chalk.enabled = false if argv.nocolors


# Error management
# -------------------------------------------------
exit = (code = 0, err) ->
  # exit without error
  process.exit code unless err
  # exit with error
  console.error chalk.red.bold "FAILED: #{err.message}"
  console.error err.description if err.description
  process.exit code unless argv.daemon
  monitor.stop()
  setTimeout ->
    process.exit code
  , 2000

process.on 'SIGINT', -> exit 130, new Error "Got SIGINT signal"
process.on 'SIGTERM', -> exit 143, new Error "Got SIGTERM signal"
process.on 'SIGHUP', -> exit 129, new Error "Got SIGHUP signal"
process.on 'SIGQUIT', -> exit 131, new Error "Got SIGQUIT signal"
process.on 'SIGABRT', -> exit 134, new Error "Got SIGABRT signal"
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
  exit 1, err if err
  conf = config.get 'monitor'
  if argv.command
    # direct command given to execute
    args = argv.command.slice()
    args = args[0].trim().split /\s+/ if args.length is 1
    require('./prompt').run args, argv.json, (err) ->
      exit 1, err if err
      exit()
  else if argv.interactive
    # interactive console
    require('./prompt').interactive conf, argv.json
  else if argv.daemon
    # daemon start
    monitor.start()
  else
    # run all once
    console.log "Analyzing systems..."
    monitor.runController null, (err, status) ->
      exit 1, err if err
      console.log "Finished.\n"
      exit() if status is 'ok'
      exit if status is 'fail' then 2 else 3

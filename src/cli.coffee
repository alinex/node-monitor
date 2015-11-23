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


# Interactive Console
# -------------------------------------------------
commands =
  help:
    description: "list a help page with possible commands"
    run: (args, cb) ->
      if args.length and args[0] in Object.keys commands
        cmd = args[0]
        console.log chalk.bold """
        Help for #{cmd} command
        ===========================================================================
        """
        console.log """
        \nThis command #{commands[cmd].description}.
        """

        return cb()
      console.log chalk.bold """
      Help for interactive console
      ===========================================================================
      """
      console.log """
      \nWithin this interactive console you can use different commands with sub
      arguments to run. See the list of possibilities below.
      You can also use code completion to get a list of available commands.

      To close this console use Ctrl-C or the #{chalk.bold 'exit'} command.

      The following commands are possible:
      """
      for name, def of commands
        console.log "- #{string.rpad name, 10} #{def.description}"
      console.log """
      \nTo get more information about a speciific command and its additional
      arguments type #{chalk.bold 'help <command>'}.
      """
      cb()
  exit:
    description: "close the console"
    run: ->
      exit null
  list:
    description: "show the list of possible elements"
  show:
    description: "get more information about the element"
  run:
    description: "run the specified element"

interactive = (conf) ->
  console.log """
    \nWelcome to the #{chalk.bold 'interactive monitor console'} in which you can get more
    information about special tools, run individual tests and explore systems.

    To get help call the command #{chalk.bold 'help'} and close with #{chalk.bold 'exit'}!
  """
  readline = require('readline').createInterface
    input: process.stdin
    output: process.stdout
    completer: (line) ->
      parts = line.split /\s+/
      list = Object.keys commands
      hits = list.filter (c) -> c.indexOf(line) == 0
      [
        if hits.length then hits else list
        line
      ]
  readline.on 'SIGINT', -> exit new Error "Got SIGINT signal"
  async.forever (cb) ->
    getCommand readline, cb
  , (err) ->
    readline.close()
    exit err

getCommand = (readline, cb) ->
  console.log ''
  readline.question 'monitor> ', (line) ->
    console.log ''
    args = line.split /\s+/
    command = args.shift()
    if commands[command]?
      commands[command].run args, cb
    else
      console.log chalk.red "Unknown command #{chalk.bold command} use
      #{chalk.bold 'help'} for more information!"
      cb()

exit = (err) ->
  # exit without error
  process.exit 0 unless err
  # exit with error
  console.error chalk.red.bold "FAILED: #{err.message}"
  console.error err.description if err.description
  process.exit 1


# Main routine
# -------------------------------------------------
process.on 'SIGINT', -> exit new Error "Got SIGINT signal"
process.on 'SIGTERM', -> exit new Error "Got SIGTERM signal"
process.on 'SIGHUP', -> exit new Error "Got SIGHUP signal"
process.on 'SIGQUIT', -> exit new Error "Got SIGQUIT signal"
process.on 'SIGABRT', -> exit new Error "Got SIGABRT signal"
process.on 'exit', -> console.log "Goodbye\n"

console.log logo
monitor.setup argv._

console.log "Initializing..."
monitor.init (err) ->
  exit err if err
  conf = config.get 'monitor'
  if argv.info
    console.log 'Not implemented!'
  else if argv.daemon
    monitor.start()
    monitor.on 'done', (ctrl) ->
  else if argv.interactive
    interactive conf
  else
    monitor.on 'result', (ctrl) ->
      console.log chalk.grey "#{moment().format("YYYY-MM-DD HH:mm:ss")}
      Controller #{chalk.white ctrl.name} => #{ctrl.colorStatus()}"
    console.log "Analyzing systems..."
    monitor.onetime
      verbose: argv.verbose
    , (err, results) ->
      exit err if err
      console.log "Finished.\n"

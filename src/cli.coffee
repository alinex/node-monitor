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


# COmmands
# -------------------------------------------------
types = ['controller', 'sensor', 'actor', 'explorer']
commands =
  # ### Integrated help
  help:
    description: "list a help page with possible commands"
    commands: ->
      Object.keys commands
      .filter (e) -> e isnt 'help'
      .map (e) -> "help #{e}"
    run: (args, cb) ->
      report = new Report()
      if args.length and args[0] in Object.keys commands
        cmd = args[0]
        report.h1 "Help for #{cmd} command"
        report.p "This command will #{commands[cmd].description}."
        report.p commands[cmd].help() if commands[cmd].help?
        console.log report.toString()
        return cb()
      report.h1 "Help for interactive console"
      report.p "Within this interactive console you can use different
      commands with sub arguments to run. See the list of possibilities below.
      You can also use code completion to get a list of available commands."
      report.p "To close this console use Ctrl-C or the
      #{Report.b 'exit'} command."
      report.p "The following commands are possible:"
      report.ul Object.keys(commands).map (name) ->
        "#{string.rpad name, 10} #{commands[name].description}"
      report.p "To get more information about a specific command and
      its additional arguments type #{Report.b 'help <command>'}."
      console.log report.toConsole()
      cb()

  # change verbose level
  verbose:
    description: "change the verbosity level between 0..9"
    commands: ->
      [0..9].map (e) -> "verbose #{e}"
    run: (args, cb) ->
      monitor.mode.verbose = Number args[0] if args[0]?
      console.log chalk.grey "Verbosity set to level #{monitor.mode.verbose}"
      cb()

  # ### exit console
  exit:
    description: "close the console"
    run: ->
      exit null

  # ### list elements of type
  list:
    description: "show the list of possible elements"
    help: ->
      text = """
      Usage: list <type>

      The list command will display a list of elements for the specified `type`:\n
      """
      text += types.map((e) -> "  - #{e}").join '\n'
    commands: (parts) ->
      if parts.length is 1 or parts[1] not in types
        types.map (e) -> "#{parts[0]} #{e}"
      else
        []
    run: (args, cb) ->
      unless args.length is 1
        console.log chalk.red "Wrong number of parameters for command #{chalk.bold 'list'}
        use #{chalk.bold 'help list'} for more information!"
        return cb()
      switch args[0]
        when 'controller'
          conf = config.get '/monitor/controller'
          console.log chalk.bold "Controllers:"
          for el in monitor.listController()
            console.log "  - #{el} #{chalk.gray conf[el].name}"
        when 'sensor'
          console.log chalk.bold "Sensors:"
          for el in monitor.listSensor()
            console.log "  - #{el}"
        else
          console.log chalk.red "Given type #{chalk.bold args[0]} not possible in
          #{chalk.bold 'list'} command. Use #{chalk.bold 'help list'} for more
          information!"
      cb()

  # ### Show element
  show:
    description: "get more information about the element"
    help: ->
      text = """
      Usage: show <type> <element>

      The show command will display detailed information about the specified `type`:\n
      """
      text += types.map((e) -> "  - #{e}").join '\n'
      text += """
      \n\nUse code completion by typing #{chalk.bold 'TAB'} to get a list of possible
      elements.
      """
    commands: (parts) ->
      if parts.length is 1 or parts[1] not in types
        types.map (e) -> "#{parts[0]} #{e}"
      else if parts.length > 2 # only allow one element
        []
      else
        num = 1
        elements = switch parts[1]
          when 'controller' then monitor.listController()
          when 'sensor' then monitor.listSensor()
          else []
        num++ while parts[num+1] in elements
        line = parts[0..num].join ' '
        elements.map (e) -> "#{line} #{e}"
    run: (args, cb) ->
      unless args.length > 1
        console.log chalk.red "Too less parameters for command #{chalk.bold 'show'}
        use #{chalk.bold 'help show'} for more information!"
        return cb()
      switch args[0]
        when 'controller'
          conf = config.get "/monitor/controller/#{args[1]}"
          unless conf
            console.log chalk.red "Given controller #{chalk.bold args[1]} not defined.
            Maybe use #{chalk.bold 'list controller'} for a list of possible ones."
            return cb()
          monitor.showController args[1], (err, report) ->
            return cb err if err
            console.log report
            cb()
        when 'sensor'
          monitor.listSensors()
          cb()
        else
          console.log chalk.red "Given type #{chalk.bold args[0]} not possible in
          #{chalk.bold 'show'} command. Use #{chalk.bold 'show list'} for more
          information!"
          cb()

  # Run element
  run:
    description: "run the specified element"
    help: ->
      text = """
      Usage: run <type> <element>

      The run command will start a specified element:\n
      """
      text += types.map((e) -> "  - #{e}").join '\n'
      text += """
      \nUse code completion by typing #{chalk.bold 'TAB'} to get a list of possible
      elements.
      """
    commands: (parts) ->
      if parts.length is 1 or parts[1] not in types
        types.map (e) -> "#{parts[0]} #{e}"
      else if parts.length > 2 # only allow one element
        []
      else
        num = 1
        elements = switch parts[1]
          when 'controller' then monitor.listController()
          when 'sensor' then monitor.listSensor()
          else []
        num++ while parts[num+1] in elements
        line = parts[0..num].join ' '
        elements.map (e) -> "#{line} #{e}"
    run: (args, cb) ->
      if args.length is 0
        console.log chalk.red "Too less parameters for command #{chalk.bold 'show'}
        use #{chalk.bold 'help show'} for more information!"
        return cb()
      switch args[0]
        when 'controller'
          if args[1]
            conf = config.get "/monitor/controller/#{args[1]}"
            unless conf
              console.log chalk.red "Given controller #{chalk.bold args[1]} not defined.
              Maybe use #{chalk.bold 'list controller'} for a list of possible ones."
              return cb()
          monitor.runController args[1], (err) ->
            return cb err if err
            console.log chalk.grey "DONE"
            cb()
        when 'sensor'
          unless args.length > 1
            console.log chalk.red "Too less parameters for command #{chalk.bold 'show'}
            use #{chalk.bold 'help show'} for more information!"
            return cb()
          monitor.listSensors()
          cb()
        else
          console.log chalk.red "Given type #{chalk.bold args[0]} not possible in
          #{chalk.bold 'show'} command. Use #{chalk.bold 'show list'} for more
          information!"
          cb()

# Interactive Console
# -------------------------------------------------
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
      parts = line.trim().split /\s+/
      list = Object.keys commands
      if parts[0] in list and commands[parts[0]].commands
        list = commands[parts[0]].commands parts
      hits = list.filter (c) ->
        c.indexOf(line) is 0
      .map (e) -> "#{e} "
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
    args = line.trim().split /\s+/
    command = args.shift()
    if commands[command]?
      commands[command].run args, cb
    else
      console.log chalk.red "Unknown command #{chalk.bold command} use
      #{chalk.bold 'help'} for more information!"
      cb()


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
    interactive conf
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

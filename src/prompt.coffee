# Prompt (Interactive Console)
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
chalk = require 'chalk'
# include alinex modules
async = require 'alinex-async'
config = require 'alinex-config'
{string} = require 'alinex-util'
# include classes and helpers
monitor = require './index'
Report = require 'alinex-report'

# Setup
# -------------------------------------------------

types = ['controller', 'sensor', 'actor', 'explorer']

# Commands
# -------------------------------------------------
# Each key in the following object is a command with the following fields:
#
# - description - a short description line
# - help - a specific help text (optional, markdown possible)
# - commands(parts) - method to get a command completion array (optional)
# - run(parts, cb) - do the task
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
      if args.length > 1 and args[1] in Object.keys commands
        # specific help for one command
        cmd = args[0]
        report.h1 "Help for #{cmd} command"
        report.p "This command will #{commands[cmd].description}."
        report.p commands[cmd].help() if commands[cmd].help?
        console.log report.toString()
        return cb()
      # General help page
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

  # ### exit console
  exit:
    description: "close the console"
    help: "You may also type `Ctrl` + `C` to exit ungraceful."
    run: ->
      exit null

  # change verbose level
  set:
    description: "display or change generel or specific settings"
    commands: (parts) ->
      subcmd = ['try', 'verbose'] #, 'controller']
      if parts.length is 1 or parts[1] not in subcmd
        subcmd.map (e) -> "#{parts[0]} #{e}"
      else if parts[1] is 'verbose'
        if parts.length is 2 or Number(parts[2]) not in [0..9]
          [0..9].map (e) -> "#{parts[0]} #{parts[1]} #{e}"
        else
          []
      else if parts[1] is 'try'
        if parts.length is 2 or Boolean(parts[2]) not in ['true', 'false']
          ['true', 'false'].map (e) -> "#{parts[0]} #{parts[1]} #{e}"
        else
          []
      else
        []
    run: (args, cb) ->
      subcmd = ['try', 'verbose'] #, 'controller']
      unless args.length is 3
        console.log chalk.red "Wrong number of parameters for command #{chalk.bold 'set'}
        use #{chalk.bold 'help set'} for more information!"
        return cb()
      switch args[1]
        when 'verbose'
          num = Number args[2] if args[2]?
          if isNaN num
            console.log chalk.red "The value #{args[2]} is not a number."
            cb()
          monitor.mode.verbose = num
          console.log chalk.grey "Verbosity set to level #{monitor.mode.verbose}"
          cb()
        when 'try'
          num = Boolean args[2] if args[2]?
          unless num
            console.log chalk.red "The value #{args[2]} is not a number."
            cb()
          monitor.mode.try = num
          console.log chalk.grey "Try mode is set to #{monitor.mode.try}"
          cb()
        else
          console.log chalk.red "Unknown setting #{args[1]} in command."
          cb()

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
      unless args.length is 2
        console.log chalk.red "Wrong number of parameters for command #{chalk.bold 'list'}
        use #{chalk.bold 'help list'} for more information!"
        return cb()
      switch args[1]
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
          console.log chalk.red "Given type #{chalk.bold args[1]} not possible in
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
      unless args.length > 2
        console.log chalk.red "Too less parameters for command #{chalk.bold 'show'}
        use #{chalk.bold 'help show'} for more information!"
        return cb()
      switch args[1]
        when 'controller'
          conf = config.get "/monitor/controller/#{args[2]}"
          unless conf
            console.log chalk.red "Given controller #{chalk.bold args[2]} not defined.
            Maybe use #{chalk.bold 'list controller'} for a list of possible ones."
            return cb()
          monitor.showController args[2], (err, report) ->
            return cb err if err
            console.log report.toConsole()
            cb()
        when 'sensor'
          monitor.listSensors()
          cb()
        else
          console.log chalk.red "Given type #{chalk.bold args[1]} not possible in
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
      if args.length is 1
        console.log chalk.red "Too less parameters for command #{chalk.bold 'show'}
        use #{chalk.bold 'help show'} for more information!"
        return cb()
      switch args[1]
        when 'controller'
          if args[2]
            conf = config.get "/monitor/controller/#{args[2]}"
            unless conf
              console.log chalk.red "Given controller #{chalk.bold args[2]} not defined.
              Maybe use #{chalk.bold 'list controller'} for a list of possible ones."
              return cb()
          monitor.runController args[2], (err) ->
            return cb err if err
            console.log chalk.grey "DONE"
            cb()
        when 'sensor'
          unless args.length > 2
            console.log chalk.red "Too less parameters for command #{chalk.bold 'show'}
            use #{chalk.bold 'help show'} for more information!"
            return cb()
          monitor.listSensors()
          cb()
        else
          console.log chalk.red "Given type #{chalk.bold args[1]} not possible in
          #{chalk.bold 'show'} command. Use #{chalk.bold 'show list'} for more
          information!"
          cb()

# Interactive Console
# -------------------------------------------------
exports.interactive = (conf) ->
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

# Direct command execution
# -------------------------------------------------
exports.run = (args) ->
  command = args[0]
  if commands[command]?
    console.log ''
    commands[command].run args, (err) ->
      console.log ''
      exit err if err
  else
    exit new Error "Unknown command #{chalk.bold command} use
    #{chalk.bold 'help'} for more information!"

# Helper methods
# -------------------------------------------------

# ### ask for the next command
getCommand = (readline, cb) ->
  console.log ''
  readline.question 'monitor> ', (line) ->
    console.log ''
    args = line.trim().split /\s+/
    command = args[0]
    if commands[command]?
      commands[command].run args, cb
    else
      console.log chalk.red "Unknown command #{chalk.bold command} use
      #{chalk.bold 'help'} for more information!"
      cb()

# ### Error management
exit = (err) ->
  # exit without error
  process.exit 0 unless err
  # exit with error
  console.error chalk.red.bold "FAILED: #{err.message}"
  console.error err.description if err.description
  process.exit 1

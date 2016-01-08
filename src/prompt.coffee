# Prompt (Interactive Console)
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
chalk = require 'chalk'
os = require 'os'
# include alinex modules
async = require 'alinex-async'
config = require 'alinex-config'
{string} = require 'alinex-util'
Report = require 'alinex-report'
# include classes and helpers
monitor = require './index'
Check = require './check'

# set to true if interactive console is running
interactive = false


# Setup
# -------------------------------------------------

types = ['controller', 'sensor', 'actor', 'analyzer']


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
    run: (args, data, cb) ->
      report = new Report()
      if args.length > 1 and args[1] in Object.keys commands
        # specific help for one command
        cmd = args[1]
        report.h1 "Help for #{cmd} command"
        report.p "This command will #{commands[cmd].description}."
        report.add commands[cmd].help() if commands[cmd].help?
        console.log report.toConsole()
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
    help: ->
      report = new Report()
      report.p "You may also type `Ctrl` + `C` to exit ungraceful. But be patient
      till the program exits. This may take some time to close opened connections."
    run: ->
      exit()

  # change verbose level
  set:
    description: "change general or specific settings"
    help: ->
      report = new Report()
      report.box "Usage: __set <option> [<value>]", 'info'
      report.p "The following parameters may be changed:"
      report.ul [
        "verbose - run in verbose mode (integer for verbose level 0..9)"
        "try     - try run which prevent actors to run (boolean)"
      ]
      report.p "The changes will take effect on the next command."
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
        if parts.length is 2 or parts[2] not in ['true', 'false']
          ['true', 'false'].map (e) -> "#{parts[0]} #{parts[1]} #{e}"
        else
          []
      else
        []
    run: (args, data, cb) ->
      subcmd = ['try', 'verbose'] #, 'controller']
      unless 1 < args.length < 4
        console.log chalk.red "Wrong number of parameters for command #{chalk.bold 'set'}
        use #{chalk.bold 'help set'} for more information!"
        return cb()
      if args.length is 3
        # set
        switch args[1]
          when 'verbose'
            num = Number args[2] if args[2]?
            if isNaN num
              console.log chalk.red "The value #{args[2]} is not a number."
              return cb()
            monitor.mode.verbose = num
          when 'try'
            unless args[2] in ['true', 'false']
              console.log chalk.red "The value #{args[2]} is not a number."
              return cb()
            monitor.mode.try = args[2] is 'true'
      # output
      switch args[1]
        when 'verbose'
          console.log chalk.grey "Verbosity set to level #{monitor.mode.verbose}"
          cb()
        when 'try'
          console.log chalk.grey "Try mode is set to #{monitor.mode.try}"
          cb()
        else
          console.log chalk.red "Unknown setting #{args[1]} in command."
          cb()

  # ### list elements of type
  list:
    description: "show the list of possible elements"
    help: ->
      report = new Report()
      report.box "Usage: #{Report.b 'list <type>'}", 'info'
      report.p "The list command will display a list of elements for the specified `type`:"
      report.ul types
    commands: (parts) ->
      if parts.length is 1 or parts[1] not in types
        types.map (e) -> "#{parts[0]} #{e}"
      else
        []
    run: (args, data, cb) ->
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
      report = new Report()
      report.box "Usage: #{Report.b 'show <type> <element>'}", 'info'
      report.p "The show command will display detailed information about the specified `type`:"
      report.ul types
      report.p "Use code completion by typing `TAB` to get a list of possible
      elements."
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
    run: (args, data, cb) ->
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
          check = new Check
            sensor: args[2]
          check.init (err) ->
            return cb err if err
            console.log check.report().toConsole()
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
      report = new Report()
      report.box "Usage: #{Report.b 'run <type> <element>'}", 'info'
      report.p "The run command will start a specified element which type is one of:"
      report.ul types
      report.p "Use code completion by typing `TAB` to get a list of possible
      elements."
    commands: (parts) ->
      if parts.length is 1 or parts[1] not in types
        types.map (e) -> "#{parts[0]} #{e}"
      else if parts.length > 3 # only allow one element
        []
      else
        num = 1
        elements = switch parts[1]
          when 'controller'
            if parts[2] in monitor.listController() then  [] else monitor.listController()
          when 'sensor'
            if parts[2] in monitor.listSensor() then [] else monitor.listSensor()
          else []
        num++ while parts[num+1] in elements
        line = parts[0..num].join ' '
        elements.map (e) -> "#{line} #{e}"
    run: (args, data, cb) ->
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
          # ask for data if not given
          askForSensor args[2], data, (err, data) ->
            return cb err if err
            # init check
            check = new Check
              sensor: args[2]
              config: data
            check.init (err) ->
              return cb err if err
              # and run it
              check.run (err) ->
                console.log check.report().toConsole()
                cb()
        else
          console.log chalk.red "Given type #{chalk.bold args[1]} not possible in
          #{chalk.bold 'show'} command. Use #{chalk.bold 'show list'} for more
          information!"
          cb()


# Interactive Console
# -------------------------------------------------
exports.interactive = (conf, data) ->
  console.log """
    \nWelcome to the #{chalk.bold 'interactive monitor console'} in which you can get more
    information about special tools, run individual tests and explore systems.

    To get help call the command #{chalk.bold 'help'} and close with #{chalk.bold 'exit'}!
  """
  interactive = true
  async.forever (cb) ->
    getCommand data, cb
  , (err) ->
    readline.close()
    exit 1, err

# Direct command execution
# -------------------------------------------------
exports.run = (args, data = {}, cb = ->) ->
  console.log ''
  command = args[0]
  if commands[command]?
    commands[command].run args, data, (err) ->
      console.log ''
      cb err
  else
    cb new Error "Unknown command #{chalk.bold command} use
    #{chalk.bold 'help'} for more information!"

# Helper methods
# -------------------------------------------------

# ### ask for the next command
getCommand = (data, cb) ->
  require('readline-history').createInterface
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
    path: "#{os.tmpdir()}/#{process.title}-history"
    maxLength: 1000
    next: (readline) =>
      readline.on 'SIGINT', -> exit 130, new Error "Got SIGINT signal"
      console.log ''
      readline.question 'monitor> ', (line) ->
        readline.close()
        console.log ''
        args = line.trim().split /\s+/
        command = args[0]
        if commands[command]?
          commands[command].run args, data, cb
        else
          console.log chalk.red "Unknown command #{chalk.bold command} use
          #{chalk.bold 'help'} for more information!"
          cb()

# ### Error management
exit = (code = 0, err) ->
  # exit without error
  process.exit code unless err
  # exit with error
  console.error chalk.red.bold "FAILED: #{err.message}"
  console.error err.description if err.description
  process.exit code

# ### Ask for missing data
askForSensor = (type, data, cb) ->
  return  cb() unless interactive
  monitor.getSensor type, (err, sensor) ->
    return cb err if err
    askFor sensor.schema, data, cb

# ### Ask user to give the data for the schema
askFor = (schema, predef = {}, cb) ->
  validator = require 'alinex-validator'
  console.log """Give the settings to run this (default is used if nothing given).
  Type 'null' to clear default value."""
  # for each key
  data = {}
  async.eachSeries Object.keys(schema.keys), (key, cb) ->
    def = schema.keys[key]
    # ask for each one
    base = predef[key] ? def.default
    readline = require('readline').createInterface
      input: process.stdin
      output: process.stdout
      completer: (line) ->
        list = def.values ? []
        hits = list.filter (c) ->
          c.indexOf(line) is 0
        [
          if hits.length then hits else list
          line
        ]
    async.retry 3, (cb) ->
      readline.question "#{def.title}#{if base? then ' (' + base + ')' else ''}: ", (line) ->
        # get result
        line = switch
          when line is 'null' then null
          when line then line
          else base
        # validate
        validator.check
          name: 'userResponse'
          value: line
          schema: def
        , (err, result) ->
          if err
            console.log chalk.magenta err.message
            console.log err.description if err.description
            return cb err
          data[key] = result ? base
          cb()
    , (err) ->
      readline.close()
      cb err
  , (err) ->
    console.log ''
    cb err, data

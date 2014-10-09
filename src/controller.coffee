# Controller for specific element
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:controller')
async = require 'async'
chalk = require 'chalk'
EventEmitter = require('events').EventEmitter
os = require 'os'
# include alinex modules
Config = require 'alinex-config'
sensor = require 'alinex-monitor-sensor'
validator = require 'alinex-validator'
{string} = require 'alinex-util'
# include classes and helpers
check = require './check'


# Controller class
# -------------------------------------------------
class Controller extends EventEmitter

  # ### Check method for configuration
  #
  # This function may be used to be added to [alinex-config](https://alinex.github.io/node-config).
  # It allows to use human readable settings.
  @check = (name, values, cb) =>
    # check general config
    debug "#{name} check configuration"
    validator.check name, check.controller, values, (err, result) ->
      return cb err if err
      values = result
      # check sensors
      async.each [0..values.depend.length-1], (num, cb) ->
        return cb() unless values.depend[num].sensor?
        sensorName = values.depend[num].sensor
        unless sensor[sensorName]?
          return cb new Error "Sensor type #{sensorName} not accessible in alinex-monitor-sensor."
        source = "#{name}.depend[#{num}].config"
        val = values.depend[num].config
        validator.check source, sensor[sensorName].meta.config, val, cb
      , cb

  # ### Factory
  # Get an instance for the name
  @_instances = {}
  @instance = (name) ->
    # create new instance if needed
    unless @_instances[name]?
      @_instances[name] = new Controller name
    # return instance
    @_instances[name]

  # ### Short to run controller
  @run = (name, cb) ->
    ctrl = @instance(name)
    ctrl.run (err) -> cb err, ctrl

  # ### Create instance
  constructor: (@name) ->
    @config = Config.instance name
    @config.setCheck Controller.check
    debug "#{@name} initialized."

  # ### Run the controller
  running: false
  run: (cb) ->
    @config.load (err, config) =>
      # check if configuration is correct
      if err
        @result =
          date: new Date
          status: 'disabled'
        debug chalk.grey "#{@name} disabled caused by config error"
        console.warn chalk.magenta "Controller #{@name} configuration error: #{err}"
        return cb null, @result
      # check if controller is already running and listen on it
      if @running
        return @once 'done', -> cb null, @result
      # check if controller is disabled manually
      if config.disabled
        @result =
          date: new Date
          status: 'disabled'
        debug chalk.grey "#{@name} disabled manually"
        return cb null, @result
      # check if disabled on this machine
      if config.runat? and config.runat isnt os.hostname()
        @result =
          date: new Date
          status: 'disabled'
        debug chalk.grey "#{@name} disabled because wrong host"
        return cb null, @result
      # return if already run
      if @result? and @result.date.getTime() >= Date.now() - config.validity
        return cb null, @result
      # start normal run
      @running = 'true'
      # listen on finished loading
      @once 'error', (err) ->
        debug chalk.red "#{@name} failed with #{err}"
        cb err, @result
      @once 'done', ->
        debug "#{@name} done", @result
        cb null, @result
      # run the controller
      @result =
        date: new Date
        status: 'running'
      debug "#{@name} start new run"
      async.map [0..config.depend.length-1], (num, cb) =>
        # run sensor
        sensorName = config.depend[num].sensor
        if sensorName?
          instance = new sensor[sensorName] config.depend[num].config
          instance.weight = config.depend[num].weight ? 1
          return instance.run cb
        # run sub controller
        controllerName = config.depend[num].controller
        Controller.run controllerName, cb
      , (err, @depend) =>
        if err
          @result.status = 'disabled'
          @result.message = "Depend error: #{err}"
          return @emit 'done', @result
        # calculate status
        @result.status = calcStatus @config.combine, depend
        # combine messages
        messages = []
        for instance in depend
          messages.push instance.result.message if instance.result.message
        @result.message = messages.join '\n' if messages.length
        @emit 'error', err if err
        @emit 'done', @result

  # ### Format output
  format: ->
    # Introduce
    text = chalk.bold """#{@name}: #{@config.name}
    ======================================================================"""
    text += "\n#{@config.description}" if @config.description
    text += "\nResult: #{colorStatus @result.status, @result.status.toUpperCase()}"
    text += " #{colorStatus @result.status, @result.message}" if @result.message
    text += "\n\n#{@config.hint}" if @config.hint
    # add dependencie
    return text unless @depend
    text += "\n\nIndividual tests:\n"
    for instance in @depend
      text += "\n- #{instance.constructor.name} - #{colorStatus instance.result.status}"
    # add dependent text
    for instance in @depend
      if argv.verbose or ctrl.result.status in ['warn', 'fail']
        continue if instance instanceof Controller
        text += chalk.bold """\n\n#{instance.constructor.name}
        ----------------------------------------------------------------------"""
        text += "\n#{instance.format()}"
    text


# Export class
# -------------------------------------------------
module.exports = Controller


# ### Calculate status
#
# The three methods are:
#
# - or - the one with the highest failure value is used
# - and - the lowest failure value is used
# - average - the average status (arithmetic round) is used
#
# With the `weight` settings on the different entries single group entries may
# be rated specific not like the others. Use a number in `average` to make the
# weight higher (1 is normal).  Also the weight 'up' makes this the highest
# priority in method `and` and `average` or 'down' will degrade in `or` method.
calcStatus = (combine, depend) ->
  # translate name to number
  values =
    'ok': 0
    'disabled': 0
    'warn': 1
    'fail': 2
  # calculate values
  switch combine
    when 'or'
      status = 0
      max = 0
      for instance in depend
        continue if instance.weight is 0
        val = values[instance.result.status]
        if instance.weight is 'down'
          max = val if val > max
        else
          status = val if val > status
      status = max if max > status
    when 'and'
      status = 9
      num = 0
      max = 0
      for instance in depend
        continue if instance.weight is 0
        val = values[instance.result.status]
        status = val if val < status
        max = val if instance.weight is 'up' and val > max
        num++
      status = 0 unless num
      status = max if max > status
    when 'average'
      status = 0
      num = 0
      max = 0
      for instance in depend
        continue if instance.weight is 0
        status += values[instance.result.status] * instance.weight
        num += instance.weight
        max = val if instance.weight is 'up' and val > max
      status = Math.round status/num
      status = max if max > status
  # translate status number to name
  for name, val in values
    return name if status is val
  return 'ok'

# Helper to colorize output
# -------------------------------------------------
colorStatus = (status, text) ->
  text = status unless text?
  switch status
    when 'ok'
      chalk.green text
    when 'warn'
      chalk.yellow text
    when 'fail'
      chalk.red text
    when 'disabled'
      chalk.grey text
    else
      text


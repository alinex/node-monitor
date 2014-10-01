# Controller for specific element
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:controller')
async = require 'async'
# include alinex modules
sensor = require 'alinex-monitor-sensor'
validator = require 'alinex-validator'
{string} = require 'alinex-util'
# include classes and helpers
check = require './check'


# Controller class
# -------------------------------------------------
class Controller

  # ### Check method for configuration
  #
  # This function may be used to be added to [alinex-config](https://alinex.github.io/node-config).
  # It allows to use human readable settings.
  @check = (name, values, cb) =>
    # check general config
    debug "#{@name} check configuration"
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

  # ### Create instance
  constructor: (@name, @config) ->
    unless config
      throw new Error "Could not initialize controller without configuration."
    debug "#{@name} initialized."

  # ### Status
  # The status of a controller may be one of the underlying sensor: ok, warn, fail
  # or disabled, undefined.
  # The status disabled will be used as ok and undefined as warning for the
  # following logic.
  status: 'running'

  # ### Run the controller
  run: (cb) ->
    debug "#{@name} start new run"
    # check if a run is necessary
    if @config.disabled
      @lastrun = new Date
      @status = 'disabled'
      return cb()
    # run the sensors and controllers
    @result =
      date: new Date
      status: 'running'
    async.map [0..@config.depend.length-1], (num, cb) =>
      # run if it is a sensor
      sensorName = @config.depend[num].sensor
      if sensorName?
        config = @config.depend[num].config
        instance = new sensor[sensorName] config
        instance.weight = @config.depend[num].weight ? 1
        return instance.run cb
      # return directly if valid
      controllerName = @config.depend[num].controller
      # listen event if running
      # else run
    , (err, @depend) =>
      return err if err
      # calculate status
      status = @calcStatus @config.combine depend
      # combine messages
      messages = []
      for instance in depend
        messages.push instance.result.message if instance.result.message
      @result.message = messages.join '\n' if messages.length
      cb()

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
  calcStatus: (combine, depend) ->
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

  # ### Format output
  format: ->
    # Introduce
    text = "#{@config.name}:\n"
    text += "#{@config.description}\n" if @config.description
    # add dependent text
    for instance in @config.depend
      text += instance.format()
    # add hint
    text += "\n#{@config.hint}" if @config.hint

# Export class
# -------------------------------------------------
module.exports = Controller

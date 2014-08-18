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
    validator.check name, check.controller, values, (err, result) ->
      return cb err if err
      values = result
      # check sensors
      async.each [0..values.sensors.length-1], (num, cb) ->
        sensorName = values.sensors[num].sensor
        source = "#{name}.sensors[#{num}].config"
        values = values.sensors[num].config
        validator.check source, sensor[sensorName].meta.config, values, cb
      , cb

  # ### Create instance
  constructor: (@config) ->
    unless config
      throw new Error "Could not initialize controller without configuration."
    @name = config._name
    debug "#{@name} initialized."

  status: null

  run: (cb) ->
    debug "#{@name} start new run"
    # run the sensors
    async.map [0..@config.sensors.length-1], (num, cb) =>
      sensorName = @config.sensors[num].sensor
      config = @config.sensors[num].config
      instance = new sensor[sensorName] config
      instance.run cb
    , (err, sensors) =>
      return err if err
      # store results
      messages = []
      for instance in sensors
        # calculate status
        if instance.result.status is 'fail' or not @status or @status is 'ok'
          @status = instance.result.status
        # get message
        messages.push instance.result.message if instance.result.message
      @message = messages.join '\n' if messages.length
      @lastrun = instance.result.date
      cb()

  message: ->
    '????'

# Export class
# -------------------------------------------------
module.exports = Controller

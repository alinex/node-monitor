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

  @calcStatus = (list...) ->
    status = null
    for entry in list
      if not status? or status is 'running' or entry is 'fail'
        status = entry
      else if status is 'ok'
        status = entry
    status


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
      async.each [0..values.sensors.length-1], (num, cb) ->
        sensorName = values.sensors[num].sensor
        unless sensor[sensorName]?
          return cb new Error "Sensor type #{sensorName} not accessible in alinex-monitor-sensor."
        source = "#{name}.sensors[#{num}].config"
        val = values.sensors[num].config
        validator.check source, sensor[sensorName].meta.config, val, cb
      , cb

  # ### Create instance
  constructor: (@config) ->
    unless config
      throw new Error "Could not initialize controller without configuration."
    @name = config._name
    debug "#{@name} initialized."

  # ### Status
  # The status of a controller may be one of the underlying sensor: ok, warn, fail
  # or disabled, undefined.
  # The status disabled will be used as ok and undefined as warning for the
  # following logic.
  status: 'running'

  # ### Create instance
  run: (cb) ->
    debug "#{@name} start new run"
    # check if a run is necessary
    if @config.disabled
      @lastrun = new Date
      @status = 'disabled'
      return cb()
    # run the sensors
    async.map [0..@config.sensors.length-1], (num, cb) =>
      sensorName = @config.sensors[num].sensor
      config = @config.sensors[num].config
      instance = new sensor[sensorName] config
      instance.run cb
    , (err, @sensors) =>
      return err if err
      # store results
      messages = []
      for instance in sensors
        @status = Controller.calcStatus @status, instance.result.status
        messages.push instance.result.message if instance.result.message
      @message = messages.join '\n' if messages.length
      @lastrun = instance.result.date
      cb()

# Export class
# -------------------------------------------------
module.exports = Controller

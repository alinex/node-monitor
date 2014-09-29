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
      async.each [0..values.sensors.length-1], (num, cb) ->
        sensorName = values.sensors[num].sensor
        unless sensor[sensorName]?
          return cb new Error "Sensor type #{sensorName} not accessible in alinex-monitor-sensor."
        source = "#{name}.sensors[#{num}].config"
        val = values.sensors[num].config
        validator.check source, sensor[sensorName].meta.config, val, cb
      , cb

  # ### Create instance
  constructor: (@name,  @config) ->
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
    async.map [0..@config.depend.length-1], (num, cb) =>
      # run if it is a sensor
      sensorName = @config.depend[num].sensor
      if sensorName?
        config = @config.sensors[num].config
        instance = new sensor[sensorName] config
        return instance.run cb
      # return directly if valid
      controllerName = @config.depend[num].controller
      # listen event if running
      # else run
    , (err, @depend) =>
      return err if err
      # store results
      messages = []
      status = []
      for instance in depend
        status.push instance.result.status
        messages.push instance.result.message if instance.result.message
        @lastrun = instance.result.date if @lastrun < instance.result.date
      @status = @calcStatus status
      @message = messages.join '\n' if messages.length
      cb()

  calcStatus = (list...) ->
    status = null
    for entry in list
      if not status? or status is 'running' or entry is 'fail'
        status = entry
      else if status is 'ok'
        status = entry
    status

# Export class
# -------------------------------------------------
module.exports = Controller

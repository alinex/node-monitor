# Controller for specific element
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
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
    validator.check name, values, check.controller, (err, result) ->
      return cb err if err
      values = result
      # check sensors
      async.each Object.keys(values.sensors), (sensorName, cb) ->
        source = name+'.sensors.'+sensorName
        values = values.sensors[sensorName]
        check = sensor[string.ucFirst sensorName].meta.config
        validator.check source, values, check, cb
      , cb

  # ### Create instance
  constructor: (@config) ->
    unless config
      throw new Error "Could not initialize controller without configuration."

  status: 'undefined'

  run: ->



# Export class
# -------------------------------------------------
module.exports = Controller

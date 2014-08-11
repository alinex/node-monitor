# Controller for specific element
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
async = require 'async'
sensor = require 'alinex-monitor-sensor'
validator = require 'alinex-validator'
{string} = require 'alinex-util'

# Controller class
# -------------------------------------------------
class Controller

  @config =
    check: 'type.object'

  # ### Check method for configuration
  # This function may be used to be added to [alinex-config](https://alinex.github.io/node-config).
  # It allows to use human readable settings.
  @check = (name, values, cb) =>
    # check general config
    validator.check name, values, @config, (err, result) ->
      return cb err if err
      values = result
      # check sensors
      async.each Object.keys(values.sensors), (sensorName, cb) ->
        source = name+'.sensors.'+sensorName
        values = values.sensors[sensorName]
        check = sensor[string.ucFirst sensorName].meta.config
        return validator.check source, values, check, cb
      , cb

  # ### Create instance
  constructor: (@config) ->
    unless config
      throw new Error "Could not initialize controller without configuration."


# Export class
# -------------------------------------------------
module.exports = Controller

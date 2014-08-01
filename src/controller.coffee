# Controller for specific element
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
async = require 'async'
sensor = require 'alinex-monitor-sensor'
{string} = require 'alinex-util'

# Controller class
# -------------------------------------------------
class Controller

  # ### Check method for configuration
  # This function may be used to be added to [alinex-config](https://alinex.github.io/node-config).
  # It allows to use human readable settings.
  @check = (name, values, cb) ->
    # check general config

    # check sensors
    async.each Object.keys(values.sensors), (sensorName, cb) ->
      check = sensor[string.ucFirst sensorName].check
      return cb() unless check?
      # run sensor check
      check name+'.sensors.'+sensorName
      , values.sensors[sensorName], cb
    , cb

  # ### Create instance
  constructor: (@config) ->
    unless config
      throw new Error "Could not initialize controller without configuration."


# Export class
# -------------------------------------------------
module.exports = Controller

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
    mandatoryKeys: ['name', 'interval', 'validity']
    allowedKeys: ['description', 'depend', 'runat', 'sensors', 'group', 'rules', 'hint']
    entries:
      name:
        check: 'type.string'
      description:
        check: 'type.string'
        optional: true
      depend:
        check: 'type.array'
        separator: /,\s*/
        optional: true
        default: []
      interval:
        check: 'type.integer'
        min: 0
      validity:
        check: 'type.integer'
        min: 0
      runat:
        title: "Location"
        description: "the location of this machine to run only tests which have
          the same location or no location at all"
        check: 'type.string'
        optional: true
      sensors:
        check: 'type.object'
      rules:
        check: 'type.array'
        optional: true
        default: []
        mandatoryKeys: ['status']
        allowedKeys: true
        entries:
          check: 'type.object'
          entries:
            status:
              check: 'type.string'
              values: ['ok', 'warn', 'fail']
            attempt:
              check: 'type.integer'
            wait:
              check: 'type.integer'
            checkdepend:
              check: 'type.boolean'
            resend:
              check: 'type.integer'
            email:
              check: 'type.object'
              entries:
                to:
                  check: 'type.string'
                template:
                  check: 'type.string'
      hint:
        check: 'type.string'

  # ### Check method for configuration
  #
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

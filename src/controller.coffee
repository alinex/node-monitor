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

  # Configuration checks
  # -------------------------------------------------
  @configRunat =
    title: "Location"
    description: "the location of this machine to run only tests which have
      the same location or no location at all"
    check: 'type.string'
    optional: true
  @configInterval =
    title: "Check Interval"
    description: "the default time (in seconds) to rerun a check"
    check: 'date.interval'
    unit: 's'
    min: 0
  @configValidity =
    title: "Result Validity"
    description: "the time (in seconds) the result will be valid and should not be rechecked"
    check: 'date.interval'
    unit: 's'
    min: 0
  @configRules =
    title: "Activities"
    description: "the rules which should be followed after state changes"
    check: 'type.array'
    optional: true
    default: []
    mandatoryKeys: ['status']
    allowedKeys: true
    entries:
      title: "Activity Rule"
      description: "a rule definition describing when and what to do"
      check: 'type.object'
      allowedKeys: true
      entries:
        status:
          title: "Status"
          description: "the status the controller should have to execute this rule"
          check: 'type.string'
          values: ['ok', 'warn', 'fail']
        num:
          title: "Number of Checks"
          description: "the minimal number of checks to wait before executing this rule"
          check: 'type.integer'
          min: 1
        latency:
          title: "Latency"
          description: "the time (in seconds) to wait before executing this rule"
          check: 'date.interval'
          unit: 's'
          min: 0
        dependskip:
          title: "Dependent Skip"
          description: "the flag indicating if this rule should be skipped if
            dependent controllers failed"
          check: 'type.boolean'
        redo:
          title: "Redo Action"
          description: "the time (in seconds) after which the action will be executed again"
          check: 'date.interval'
          unit: 's'
          min: 0
        email:
          title: "Send Email"
          description: "the settings for sending an email as action"
          check: 'type.object'
          allowedKeys: true
          entries:
            to:
              title: "Contact Alias"
              description: "the person or group to send email to as contact alias"
              check: 'type.string'
            template:
              title: "Template"
              description: "the template to be used for emails"
              check: 'type.string'
  @config =
    title: "Monitoring controller configuration"
    check: 'type.object'
    mandatoryKeys: ['name']
    allowedKeys: true
    entries:
      name:
        title: "Name"
        description: "the short title of the controller to be used in display"
        check: 'type.string'
      description:
        title: "Description"
        description: "a short abstract of what this controller will check"
        check: 'type.string'
        optional: true
      runat: Controller.configRunat
      interval: Controller.configInterval
      validity: Controller.configValidity
      depend:
        title: "Dependent Controllers"
        description: "a list of controllers which this controller depend on"
        check: 'type.array'
        separator: /,\s*/
        optional: true
        default: []
        entries:
          title: "Name of Controller"
          description: "the name of the controller which is dependent for this"
          check: 'type.string'
      sensors:
        title: "Sensors"
        description: "the configuration of sensors to run"
        check: 'type.object'
      rules: Controller.configRules
      hint:
        title: "Hints"
        description: "a complete description what may be done if this check failed
          and other things which are helpful to know"
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

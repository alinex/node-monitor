# Check definitions
# =================================================
# This contains different check definitions for the
# [alinex-validator](http://alinex.github.io/node-validator).

# Parts which are used later
# -------------------------------------------------
interval =
  title: "Check Interval"
  description: "the default time (in seconds) to rerun a check"
  type: 'interval'
  unit: 's'
  min: 0

validity =
  title: "Result Validity"
  description: "the time (in seconds) the result will be valid and should not be rechecked"
  type: 'interval'
  unit: 's'
  min: 0

rules =
  title: "Activities"
  description: "the rules which should be followed after state changes"
  type: 'array'
  default: []
  entries:
    title: "Activity Rule"
    description: "a rule definition describing when and what to do"
    type: 'object'
    allowedKeys: true
    entries:
      status:
        title: "Status"
        description: "the status the controller should have to execute this rule"
        type: 'string'
        values: ['ok', 'warn', 'fail']
      num:
        title: "Number of Checks"
        description: "the minimal number of checks to wait before executing this rule"
        type: 'integer'
        min: 1
      latency:
        title: "Latency"
        description: "the time (in seconds) to wait before executing this rule"
        type: 'interval'
        unit: 's'
        min: 0
      dependskip:
        title: "Dependent Skip"
        description: "the flag indicating if this rule should be skipped if
          dependent controllers failed"
        type: 'boolean'
      redo:
        title: "Redo Action"
        description: "the time (in seconds) after which the action will be executed again"
        type: 'interval'
        unit: 's'
        min: 0
      email:
        title: "Send Email"
        description: "the settings for sending an email as action"
        type: 'object'
        allowedKeys: true
        entries:
          to:
            title: "Contact Alias"
            description: "the person or group to send email to as contact alias"
            type: 'string'
          template:
            title: "Template"
            description: "the template to be used for emails"
            type: 'string'

# monitor
# -------------------------------------------------
# Configuration for the base class
exports.monitor =
  title: "Monitoring Configuration"
  type: 'object'
  mandatoryKeys: ['interval', 'validity']
  allowedKeys: true
  entries:
    master:
      title: "Master Hostname"
      description: "the hostname of the machine to run unspecific tests or no
      hostname to use this machine"
      type: 'string'
      optional: true
    interval: interval
    validity: validity
    rules: rules
    contacts:
      title: "Contacts"
      description: "the possible contacts to be referred from controller for
        email alerts"
      type: 'object'
      entries:
        type: 'any'
        entries: [
          title: "Contact Group"
          description: "the list of references in the group specifies the individual
            contacts"
          type: 'array'
          entries:
            type: 'string'
        ,
          title: "Contact Details"
          description: "the name and email address for a specific contact"
          type: 'object'
          mandatoryKeys: ['email']
          allowedKeys: ['name']
          entries:
            type: 'string'
        ]
    email:
      title: "Email Templates"
      description: "the email templates to be used for different states"
      type: 'object'
      mandatoryKeys: ['default']
      allowedKeys: ['fail', 'warn', 'ok']
      entries:
        title: "Email Template"
        description: "the subject and HTML body which is used to create the email
          (variables are included)"
        type: 'object'
        mandatoryKeys: ['subject', 'body']
        entries:
          type: 'string'

# controller
# -------------------------------------------------
# Configuration for individual controllers.
exports.controller =
  title: "Monitoring controller configuration"
  type: 'object'
  mandatoryKeys: ['name']
  allowedKeys: true
  entries:
    name:
      title: "Name"
      description: "the short title of the controller to be used in display"
      type: 'string'
    description:
      title: "Description"
      description: "a short abstract of what this controller will check"
      type: 'string'
      optional: true
    runat:
      title: "Run at host"
      description: "the hostname of the machine to run the tests or no hostname to
      run on master"
      type: 'string'
      optional: true
    interval: interval
    validity: validity
    disabled:
      title: "Disabled"
      description: "a flag to temporarily disable this check"
      type: 'boolean'
    depend:
      title: "Dependent Controllers"
      description: "a list of controllers which this controller depend on"
      type: 'array'
      delimiter: /,\s*/
      default: []
      entries:
        title: "Name of Controller"
        description: "the name of the controller which is dependent for this"
        type: 'string'
    sensors:
      title: "Sensors"
      description: "the configuration of sensors to run"
      type: 'array'
      default: []
      entries:
        title: "Sensor"
        description: "the type and configuration for a sensor run"
        type: 'object'
        mandatoryKeys: ['sensor', 'config']
        allowedKeys: true
        entries:
          sensor:
            title: "Sensor Class"
            description: "the  class name of a sensor to run"
            type: 'string'
            lowerCase: true
            upperCase: 'first'
          config:
            title: "Sensor Configuration"
            description: "the configuration for a sensor run"
            type: 'object'

    rules: rules
    hint:
      title: "Hints"
      description: "a complete description what may be done if this check failed
        and other things which are helpful to know"
      type: 'string'

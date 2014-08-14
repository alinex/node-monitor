# Check definitions
# =================================================
# This contains different check definitions for the
# [alinex-validator](http://alinex.github.io/node-validator).

# Parts which are used later
# -------------------------------------------------
runat =
  title: "Location"
  description: "the location of this machine to run only tests which have
    the same location or no location at all"
  check: 'type.string'
  optional: true

interval =
  title: "Check Interval"
  description: "the default time (in seconds) to rerun a check"
  check: 'date.interval'
  unit: 's'
  min: 0

validity =
  title: "Result Validity"
  description: "the time (in seconds) the result will be valid and should not be rechecked"
  check: 'date.interval'
  unit: 's'
  min: 0

rules =
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

# monitor
# -------------------------------------------------
# Configuration for the base class
exports.monitor =
  title: "Monitoring Configuration"
  check: 'type.object'
  mandatoryKeys: ['interval', 'validity']
  allowedKeys: true
  entries:
    runat: runat
    interval: interval
    validity: validity
    rules: rules
    contacts:
      title: "Contacts"
      description: "the possible contacts to be referred from controller for
        email alerts"
      check: 'type.object'
      entries:
        check: 'type.any'
        entries: [
          title: "Contact Group"
          description: "the list of references in the group specifies the individual
            contacts"
          check: 'type.array'
          entries:
            check: 'type.string'
        ,
          title: "Contact Details"
          description: "the name and email address for a specific contact"
          check: 'type.object'
          mandatoryKeys: ['email']
          allowedKeys: ['name']
          entries:
            check: 'type.string'
        ]
    email:
      title: "Email Templates"
      description: "the email templates to be used for different states"
      check: 'type.object'
      mandatoryKeys: ['default']
      allowedKeys: ['fail', 'warn', 'ok']
      entries:
        title: "Email Template"
        description: "the subject and HTML body which is used to create the email
          (variables are included)"
        check: 'type.object'
        mandatoryKeys: ['subject', 'body']
        entries:
          check: 'type.string'

# controller
# -------------------------------------------------
# Configuration for individual controllers.
exports.controller =
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
    runat: runat
    interval: interval
    validity: validity
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
    rules: rules
    hint:
      title: "Hints"
      description: "a complete description what may be done if this check failed
        and other things which are helpful to know"
      check: 'type.string'

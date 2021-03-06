# Configuration Schema
# =================================================

# Contacts
# -------------------------------------------------

contact =
  title: "Contacts"
  description: "the possible contacts to be referred from controller for email alerts"
  type: 'object'
  entries: [
    type: 'or'
    or: [
      title: "Contact Group"
      description: "the list of references in the group specifies the individual
        contacts"
      type: 'array'
      toArray: true
      minLength: 1
      entries:
        type: 'string'
    ,
      title: "Contact Details"
      description: "the name and email address for a specific contact"
      type: 'object'
      mandatoryKeys: ['name']
      allowedKeys: true
      keys:
        name:
          title: "Name"
          description: "the full name of the contact"
          type: 'string'
        position:
          title: "Position"
          description: "the position within the organization (informal)"
          type: 'string'
        company:
          title: "Company"
          description: "the company name this person belongs to"
          type: 'string'
        email:
          title: "Email"
          description: "the email address to send alerts"
          type: 'email'
        phone:
          title: "Phone"
          description: "the phone numbers used for direct contact"
          type: 'array'
          toArray: true
          entries:
            type: 'string'
    ]
  ]


# Email Action
# -------------------------------------------------

email =
  title: "Email Action"
  description: "the setup for an individual email action"
  type: 'object'
  allowedKeys: true
  keys:
    base:
      title: "Base Template"
      description: "the template used as base for this"
      type: 'string'
      list: '<<<context:///monitor/email>>>'
    transport:
      title: "Service Connection"
      description: "the service connection to send mails through"
      type: 'or'
      or: [
        type: 'string'
      ,
        type: 'object'
      ]
    from:
      title: "From"
      description: "the address emails are send from"
      type: 'string'
    to:
      title: "To"
      description: "the address emails are send to"
      type: 'string'
    cc:
      title: "Cc"
      description: "the carbon copy addresses"
      type: 'string'
    bcc:
      title: "Bcc"
      description: "the blind carbon copy addresses"
      type: 'string'
    subject:
      title: "Subject"
      description: "the subject line of the generated email"
      type: 'handlebars'
    body:
      title: "Content"
      description: "the body content of the generated email"
      type: 'handlebars'


# Rule Definition
# -------------------------------------------------

rule =
  title: "Rule"
  description: "a rule to run after the controller is done"
  type: 'object'
  allowedKeys: true
  keys:
    name:
      title: "Name"
      description: "a specific name to refer to this check"
      type: 'string'
    base:
      title: "Base Rule"
      description: "the template to use for this rule"
      type: 'string'
      list: '<<<context:///monitor/rule>>>'
    status:
      title: "Status"
      description: "the status on which to act"
      type: 'string'
      list: ['ok', 'warn', 'fail']
    attempt:
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
    check:
      title: "Filter Checks"
      description: "a filter to work only on specific check status or values"
      type: 'string'
    dependskip:
      title: "Dependent Skip"
      description: "the flag indicating if this rule should be skipped if
        dependent controllers failed"
      type: 'boolean'
      default: false
    email: email
    redo:
      title: "Redo Action"
      description: "the time (in seconds) after which the action will be executed again"
      type: 'interval'
      unit: 's'
      min: 0

# Controller
# -------------------------------------------------

# ### Defining the checks first

check =
  title: "Checks"
  description: "the list of checks which have to be run"
  type: 'array'
  default: []
  entries:
    title: "Check"
    description: "the type and configuration for a check run"
    type: 'object'
    allowedKeys: true
    keys:
      sensor:
        title: "Sensor Class"
        description: "the  class name of a sensor to run"
        type: 'string'
        lowerCase: true
      name:
        title: "Name"
        description: "a specific name to refer to this check"
        type: 'string'
      depend:
        title: "Dependent Check"
        description: "a list of check names, which should run before this"
        type: 'array'
        toArray: true
        optional: true
        entries: [
          name: "Dependency"
          description: "the dependent check which have to complete before starting this"
          type: 'string'
        ]
      config:
        title: "Sensor Configuration"
        description: "the configuration for a sensor run"
        type: 'object'
      weight:
        title: "Weight"
        description: "the special weight for the combination of sensors"
        optional: true
        type: 'or'
        or: [
          title: "Up/Down"
          description: "the info to rate the status more or less important
            in the calculation"
          type: 'string'
          values: ['up', 'down']
        ,
          # wenn combine = 'average' ->
          # if:
          #   cmd: 'eq'
          #   op1: '<<<combine>>>'
          #   op2: 'average'
          title: "Priority"
          description: "the priority for the 'average' combination method"
          type: 'integer'
          min: 0
        ]
      hint:
        title: "Hint"
        description: "a specific description for this sensor that describes
          what may be done if this check failed and other things which are
          helpful to know"
        type: 'handlebars'

# ### Controller containing Checks

controller =
  title: "Controller List"
  description: "the list of controllers to check"
  type: 'object'
  flatten: true
  entries: [
    title: "Controller"
    description: "a single controller checking one part of the system"
    type: 'object'
    flatten: true
    mandatoryKeys: ['name']
    allowedKeys: true
    keys:
      name:
        title: "Name"
        description: "the short title of the controller to be used in display"
        type: 'string'
      description:
        title: "Description"
        description: "a short abstract of what this controller will check"
        type: 'string'
      validity:
        title: "Result Validity"
        description: "the time (in seconds) the result will be valid and should not be rechecked"
        type: 'interval'
        unit: 's'
        min: 0
        default: 60
      interval:
        title: "Check Interval"
        description: "the default time (in seconds) to rerun a check"
        type: 'interval'
        unit: 's'
        min: 0
        default: 300
      disabled:
        title: "Disabled"
        description: "the controller is disabled for automatic run"
        type: 'boolean'
        default: false
      check: check
      parallel:
        title: "Max. Parallel Checks"
        description: "the maximum number of parallel running checks"
        type: 'integer'
        min: 1
        default: 5
      combine:
        title: "Combine Method"
        description: "the calculation of the combined status"
        type: 'string'
        values: ['min', 'max', 'average']
        default: 'max'
      rule:
        title: "Rules"
        description: "the list of rules (references) to be used"
        type: 'array'
        toArray: true
        entries: rule
      info:
        title: "Info"
        description: "a general information about this part of the system"
        type: 'string'
      hint:
        title: "Hint"
        description: "a specific description for this controller that describes
          what may be done if this check failed and other things which are helpful to know"
        type: 'handlebars'
      contact:
        title: "Contact Types"
        description: "the contacts categorized into groups"
        type: 'object'
        entries: [
          title: "Contact List"
          description: "the list of contacts for the group"
          type: 'array'
          toArray: true
          entries:
            type: 'string'
            list: '<<<context:///monitor/contact>>>'
        ]
      ref:
        title: "References"
        description: "the list of URL references which may help getting informed
          as title - URL pairs"
        type: 'object'
        entries: [
          title: "Access URL"
          description: "the URL to access this reference"
          type: 'array'
          toArray: true
          entries:
            type: 'string'
        ]
  ]

# ### Persistent storage definition

storage =
  title: "Storage"
  description: "the storage to use for results"
  type: 'object'
  allowedKeys: true
  mandatoryKeys: ['database']
  keys:
    database:
      title: "Database"
      description: "the alias name of the database to store to"
      type: 'string'
      list: '<<<context:///database>>>'
      optional: true
    prefix:
      title: "Table Prefix"
      description: "a prefix to be put before each table name"
      type: 'string'
      default: ''
    cleanup:
      title: "Cleanup Sensor Data"
      description: "the number of sensor data entries per each interval"
      type: 'object'
      mandatoryKeys: true
      keys:
        minute:
          title: "Max. Time Entries"
          description: "the interval for sensor data time entries to keep, older will be removed"
          type: 'integer'
          min: 1
        hour:
          title: "Max. Time Entries"
          description: "the interval for sensor data time entries to keep, older will be removed"
          type: 'integer'
          min: 1
        day:
          title: "Max. Time Entries"
          description: "the interval for sensor data time entries to keep, older will be removed"
          type: 'integer'
          min: 1
        week:
          title: "Max. Time Entries"
          description: "the interval for sensor data time entries to keep, older will be removed"
          type: 'integer'
          min: 1
        month:
          title: "Max. Time Entries"
          description: "the interval for sensor data time entries to keep, older will be removed"
          type: 'integer'
          min: 1
        other:
          title: "Max. Time Entries"
          description: "the interval for other entries to keep, older will be removed"
          type: 'interval'
          unit: 'd'
          min: 1


# Complete Schema Definition
# -------------------------------------------------

module.exports =
  title: "Monitor Setup"
  description: "the configuration for the monitor system"
  type: 'object'
  allowedKeys: true
  keys:
    contact: contact
    email:
      title: "Email Templates"
      description: "the possible templates used for sending emails"
      type: 'object'
      entries: [email]
    rule:
      title: "Rule Templates"
      description: "the possible templates used for rules"
      type: 'object'
      entries: [rule]
    controller: controller
    storage: storage
    log:
      title: "File Logger"
      description: "the setup for the file logger"
      type: 'object'
      allowedKeys: true
      keys:
        filename:
          title: "Filename"
          description: "the filename within the log directory"
          type: 'file'
        datePattern:
          title: "Rotation Pattern"
          description: "the date pattern to be used for rotating files"
          type: 'string'
          minLength: 1
        maxSize:
          title: "max. Size"
          description: "the maximum file size before file rotation"
          type: 'byte'
          min: 1
        maxFiles:
          title: "max. Files"
          description: "the maximum number of files (older ones will be deleted on rotation)"
          type: 'integer'
          min: 1
        compress:
          title: "Compress"
          description: "a flag indicating rotated files should be compressed"
          type: 'boolean'
    plugins:
      title: "Enabled Plugins"
      description: "the list of enabled plugins"
      type: 'array'
      toArray: true
      entries:
        title: "Plugin"
        description: "the name of the already installed npm plugin module"
        type: 'string'

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
          type: 'string'
        phone:
          title: "Phone"
          description: "the phone number used for direct contact"
          type: 'string'
    ]
  ]

# Email Templates
# -------------------------------------------------

email =
  title: "Email Template"
  description: "a single template used for emails"
  type: 'object'
  allowedKeys: true
  keys:
    base:
      title: "Base Template"
      description: "the template used as base for this"
      type: 'string'
      list: '<<<context:///monitor/email>>>'
    from:
      title: "From"
      description: "the address emails are send from"
      type: 'string'
      default: 'monitor'
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
  title: "Rules"
  description: "the list of all possible rules to be referenced from controller"
  type: 'object'
  entries: [
    title: "Rule"
    description: "a rule to run after the controller is done"
    type: 'object'
    allowedKeys: true
    keys:
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
  ]

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
  entries: [
    title: "Controller"
    description: "a single controller checking one part of the system"
    type: 'object'
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
      check: check
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
        entries:
          type: 'string'
          list: '<<<context:///monitor/rule>>>'
      info:
        title: "Info"
        description: "a general information about this part of the system"
        type: 'handlebars'
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
      entries: [ email ]
    rule: rule
    controller: controller

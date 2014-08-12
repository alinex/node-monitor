# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor')
async = require 'async'
Config = require 'alinex-config'
validator = require 'alinex-validator'
require('alinex-error').install()
# include classes
Controller = require './controller'


# Definition of Configuration
# -------------------------------------------------
# The configuration will be set in the [alinex-validator](http://alinex.github.io/node-validator)
# style. It will be checked after configuration load.
Config.addCheck 'monitor', (source, values, cb) ->
  validator.check source, values,
    title: "Monitoring Configuration"
    check: 'type.object'
    allowedKeys: true
    entries:
      runat:
        title: "Location"
        description: "the location of this machine to run only tests which have
          the same location or no location at all"
        check: 'type.string'
        optional: true
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
  , (err, result) ->
    return cb err if err
    # additional checks
    for key, value of result.contacts
      continue unless value instanceof Array
      for entry in value
        unless result.contacts[entry]?
          return cb new Error "No matching entry '#{entry}' from group '#{key}' in #{source} found."
    cb null, result


# Initialize Monitor
# -------------------------------------------------

# do parallel config loading
debug "load configurations"
async.parallel
  # read monitor config
  config: (cb) ->
    new Config 'monitor', cb
  # get controller
  controller: (cb) ->
    # find controller configs in folder
    Config.find 'controller', (err, list) ->
      return cb err if err
      async.map list, (name, cb) ->
        # add controller check
        Config.addCheck name, Controller.check, (err) ->
          return cb err if err
          # read in configuration
          new Config name, (err, config) ->
            return cb err if err
            # return new controller instance
            cb null, new Controller config
      , (err, results) ->
        return cb err if err
        cb null, results
, (err, {config,controller}) ->
  if err
    return setTimeout ->
      throw err
    , 1000

  return setTimeout ->
    # init controller
    for ctrl in controller
      debug "controller #{ctrl.config._name} initialized."

    console.log controller
  , 1000


# run controller once




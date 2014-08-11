# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
async = require 'async'
Config = require 'alinex-config'
require('alinex-error').install()
# include classes
Controller = require './controller'


# Definition of Configuration
# -------------------------------------------------
# The configuration will be set in the [alinex-validator](http://alinex.github.io/node-validator)
# style. It will be checked after configuration load.
Config.addCheck 'monitor',
  title: "Monitoring Configuration"
  check: 'type.object'
  allowedKeys: ['runat', 'contacts', 'email']
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
        list: [
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


# Initialize Monitor
# -------------------------------------------------

# do parallel config loading
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
        cb null, results
, (err, {config,controller}) ->
  if err
    return setTimeout ->
      throw err
    , 1000
  console.log config
  console.log controller


# init controller

# run controller once




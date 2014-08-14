# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor')
async = require 'async'
# include alinex modules
Config = require 'alinex-config'
validator = require 'alinex-validator'
require('alinex-error').install()
# include classes and helpers
Controller = require './controller'
check = require './check'

# Definition of Configuration
# -------------------------------------------------
# The configuration will be set in the [alinex-validator](http://alinex.github.io/node-validator)
# style. It will be checked after configuration load.
Config.addCheck 'monitor', (source, values, cb) ->
  validator.check source, values, check.monitor, (err, result) ->
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

  # check controller once
  async.each controller, (ctrl, cb) ->
    ctrl.run (err) ->
      return cb err if err
      console.log "#{ctrl.lastrun} - #{ctrl.name} - #{colorStatus ctrl.status}"
      unless ctrl.message
        console.log ctrl.message.grey
      cb()
  , (err) ->
    throw err if err
    console.log 'DONE'.green

# Helper to colorize output
# -------------------------------------------------
colorStatus = (status) ->
  switch status
    when 'ok'
      status.green
    when 'warn'
      status.yellow
    when 'fail'
      status.red
    else
      status


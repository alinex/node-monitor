# Controller for specific element
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:controller')
chalk = require 'chalk'
EventEmitter = require('events').EventEmitter
# include alinex modules
async = require 'alinex-async'
{string} = require 'alinex-util'
validator = require 'alinex-validator'
# include classes and helpers

# Controller class
# -------------------------------------------------
class Controller extends EventEmitter

  # ### Create instance
  constructor: (@name, @conf) ->

  init: (cb) ->
    async.mapOf @conf.check, (check, num, cb) =>
      try
        sensor = require "./sensor/#{check.sensor.toLowerCase()}"
      catch err
        debug chalk.red "Failed to load '#{check.sensor.toLowerCase()}' lib because of: #{err}"
        return cb new Error "Check '#{check.sensor.toLowerCase()}' not supported"
      validator.check
        name: "#{@name}:#{num}"
        value: check.config
        schema: sensor.schema
      , (err, result) =>
        return cb err if err
        @conf.check[num].config = result
        cb()
    , (err) ->
      debug "#{chalk.grey @name} Initialized controller"
      cb err

  run: (cb) ->
    # for each sensor in parallel
    async.mapOf @conf.check, (check, num, cb) =>
      debug "#{chalk.grey @name} Running check ##{num}:#{check.sensor}..."
      sensor = require "./sensor/#{check.sensor.toLowerCase()}"
      # run sensor
      sensor.run "#{@name}:#{num}", check.config, (err, res) ->
        return cb err if err
        # keep results
        console.log res
        # output status line on console
        # store results
        cb()
    , cb

    # analysis on state change
    # run analyzer
    # keep report

    # action
    # create full report
    # store  report
    # send email



# Export class
# -------------------------------------------------

module.exports =  Controller

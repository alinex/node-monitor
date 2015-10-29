# Controller for specific element
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:controller')
debugSensor = require('debug')('monitor:sensor')
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
        sensor = require "./sensor/#{check.sensor}"
      catch err
        debug chalk.red "Failed to load '#{check.sensor}' lib because of: #{err}"
        return cb new Error "Check '#{check.sensor}' not supported"
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
      name = "#{check.sensor}:#{check.name}"
      debug "#{chalk.grey @name} Running check #{name}..."
      sensor = require "./sensor/#{check.sensor}"
      # run sensor
      sensor.run "#{@name}:#{name}", check.config, (err, res) =>
        return cb err if err
        # keep results
#        console.log res
        # status info
        debugSensor "#{chalk.grey @name} Check #{name} => #{colorStatus res.status}"
        # store results
        cb()
    , ->
      # calculate controller status
      #@emit 'result', this
      cb()

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

# Helper to colorize output
# -------------------------------------------------
colorStatus = (status, text) ->
  text = status unless text?
  switch status
    when 'ok'
      chalk.green text
    when 'warn'
      chalk.yellow text
    when 'fail'
      chalk.red text
    when 'disabled'
      chalk.grey text
    else
      text

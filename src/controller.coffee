# Controller for specific element
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:controller')
debugSensor = require('debug')('monitor:sensor')
chalk = require 'chalk'
util = require 'util'
EventEmitter = require('events').EventEmitter
# include alinex modules
async = require 'alinex-async'
{string} = require 'alinex-util'
validator = require 'alinex-validator'
# include classes and helpers
sensor = require './sensor'

# Controller class
# -------------------------------------------------
class Controller extends EventEmitter

  # ### Create instance
  constructor: (@name, @conf, @mode) ->

  # ### Initialize
  init: (cb) ->
    async.mapOf @conf.check, (check, num, cb) =>
      try
        sensorInstance = require "./sensor/#{check.sensor}"
      catch err
        debug chalk.red "Failed to load '#{check.sensor}' lib because of: #{err}"
        return cb new Error "Check '#{check.sensor}' not supported"
      validator.check
        name: "#{@name}:#{num}"
        value: check.config
        schema: sensorInstance.schema
      , (err, result) =>
        return cb err if err
        @conf.check[num].config = result
        cb()
    , (err) =>
      debug "#{chalk.grey @name} Initialized controller"
      cb err

  # ### Data storage with last results
  #
  # Last status
  status: 'disabled'
  # Check results containing:
  #
  # - date
  # - status
  # - values
  checks: []
  # controller status
  controller: []

  # ### Run once
  run: (cb) ->
    # for each sensor in parallel
    async.mapOf @conf.check, (check, num, cb) =>
      debug "#{chalk.grey @name} Running check #{name}..."
      sensorInstance = require "./sensor/#{check.sensor}"
      name = "#{check.sensor}:#{sensorInstance.name check.config}"
      # run sensor
      sensorInstance.run check.config, (err, res) =>
        return cb err if err
        # status info
        debugSensor "#{chalk.grey @name} Check #{name} => #{@colorStatus res.status}#{
          if res.message then ' (' + res.message + ')' else ''
          }"
        if @mode?.verbose
          msg = "Check #{chalk.white @name + ' ' + name} => #{@colorStatus res.status}"
          msg += " (#{res.message})" if res.message
          if @mode.verbose > 1
            msg += '\n' + util.inspect res.values
          console.log chalk.grey msg
        # check for status change -> analysis
        return cb null, res if res.status in ['disabled', @status]
        res._sensor = sensorInstance
        res._config = check.config
        # run analysis
        sensorInstance.analysis check.config, res, (err, report) ->
          return cb err if err
          res.analysis = report
          cb null, res
    , (err, res) =>
      return cb err if err
      res = Object.keys(res).map (k) -> # convert to array
        delete res[k]._analysis
        res[k]
      # store sensor results
      @checks.pop() if @checks.length > 5
      @checks.unshift res
      # calculate controller status
      @status = calcStatus @conf.combine, @conf.check, res
      debug "#{chalk.grey @name} Controller => #{@colorStatus()}"
      # make report
      report = """
      Controller #{@name} (#{@conf.name})
      =============================================================================
      #{@conf.description}

      > __STATUS: #{@status}__ at #{new Date()}
      \n
      """
#      console.log res
      for entry in res
        report += sensor.report
          sensor: entry._sensor
          config: entry._config
          result: entry

      console.log report
      @emit 'result', this
      cb()

    # analysis on state change
    # run analyzer
    # keep report

    # action
    # create full report
    # store  report
    # send email

  # Helper to colorize output
  # -------------------------------------------------
  colorStatus: (status, text) ->
    status ?= @status
    text ?= status
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


# Export class
# -------------------------------------------------

module.exports =  Controller

# Calculating Controller Status
# -------------------------------------------------
#
# The three methods are:
#
# - max - the one with the highest failure value is used
# - min - the lowest failure value is used
# - average - the average status (arithmetic round) is used
#
# With the `weight` settings on the different entries single group entries may
# be rated specific not like the others. Use a number in `average` to make the
# weight higher (1 is normal). Also the weight 'up' and 'down' changes the error
# level for one step before using in calculation.
calcStatus = (combine, check, result) ->
  # translate name to number
  values =
    'disabled': 0
    'ok': 1
    'warn': 2
    'fail': 3
  # calculate values
  switch combine
    when 'max'
      status = 0
      for num, setup of check
        continue if setup.weight is 0
        val = values[result[num].status]
        val-- if setup.weight is 'down' and val > 0
        val++ if setup.weight is 'up' and val < 2
        status = val if val > status
    when 'min'
      status = 9
      num = 0
      for num, setup of check
        continue if setup.weight is 0
        val = values[result[num].status]
        val-- if setup.weight is 'down' and val > 0
        val++ if setup.weight is 'up' and val < 2
        status = val if val < status
        num++
      status = 0 unless num
    when 'average'
      status = 0
      num = 0
      for num, setup of check
        continue if setup.weight is 0
        val = values[result[num].status]
        val-- if setup.weight is 'down' and val > 0
        val++ if setup.weight is 'up' and val < 2
        status += val * setup.weight
        num += setup.weight
      status = Math.round status/num
  # translate status number to name
  for name, val of values
    return name if status is val
  return 'ok'

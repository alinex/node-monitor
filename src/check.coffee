# Run a check
# =================================================
# This will call the sensor and work with it. A sensor is not usable standalone
# and needs a check which defines it's environment.
#
# The sensor should have the following API:
#
# - schema - validator compatible definition
# - meta - some meta informations
# - init() - setup of the sensor for this check
# - run() - run the sensor for the check
# - calc() - check the results
#
# The sensor will use the check instance for storing it's data.


# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:check')
chalk = require 'chalk'
util = require 'util'
EventEmitter = require('events').EventEmitter
vm = require 'vm'
# include alinex modules
async = require 'alinex-async'
{string} = require 'alinex-util'
validator = require 'alinex-validator'
# include classes and helpers
storage = require './storage'


# Initialized Data
# -------------------------------------------------
# This will be set on init
monitor = null  # require './index'


# Controller class
# -------------------------------------------------
class Check extends EventEmitter

  # ### Create instance
  constructor: (setup, @controller) ->
    @type = setup.sensor
    @conf = setup.config ? {}
    # will be set after initialization
    @sensor = null
    @name = null
    @databaseID = null
    @base = null

    @history = []

    @result = null
    @status = 'disabled'
    @err = null
    @date = []
    @values = {}
    @changed = 0

  # ### Initialize check and sensor
  init: (cb) ->
    return cb() if @sensor?
    monitor ?= require './index'
    monitor.getSensor @type, (err, @sensor) =>
      return cb err if err
      @sensor.init.call this, (err) =>
        return cb err if err
        @sensor.debug "#{chalk.grey @name} Initialized"
        # check config
        validator.check
          name: "#{@type}:#{@name}"
          value: @conf
          schema: @sensor.schema
        , (err) =>
          return cb err if err
          return cb() unless @controller?
          # only add database entry if run below controller
          storage.check @controller.databaseID, @type, @name, @sensor.meta.category
          , (err, checkID) ->
            return cb err if err
            @databaseID = checkID
            cb()

  # ### Run one sensor check
  run: (cb) ->
    @sensor.debug "#{chalk.grey @name} start check"
    @status = 'running'
    @err = null
    @date = [new Date()]
    @values = {}
    @changed = 0
    @sensor.run.call this, (@err, res) =>
      @sensor.debug "#{chalk.grey @name} ended check"
      @date[1] = new Date()
      return cb err, @setStatus() if @err
      @sensor.calc.call this, res, (err) =>
        cb null, @setStatus()

  setStatus: ->
    @calcStatus()
    @sensor.debug "#{chalk.grey @name} result status:
    #{@status}#{if @err then ' (' + @err.message + ')' else ''}"
    for n, v of work.result.values
      @sensor.debug "#{chalk.grey @name} result #{n}: #{v}"
    @status

  calcStatus: ->
    return @status = 'fail' if @err
    # check for values
    unless Object.keys @values
      @err = new Error 'no data'
      return @status = 'fail'
    # calculate from values
    for status in ['fail', 'warn']
      continue unless @conf[status]
      rule = @conf[status]
      @sensor.debug chalk.grey "#{@name} check #{status} rule: #{rule}"
      # replace data values
      for name, value of @values
        if Array.isArray value
          for i, val in value
            re = new RegExp "\\b#{name}\\[#{i}\\]\\b", 'g'
            rule = rule.replace re, (str, name) ->
              "'#{value[i]?.toString()}'"
          re = new RegExp "\\b#{name}\\b", 'g'
          rule = rule.replace re, (str, name) ->
            "'#{value.toString()}'"
        else if typeof value is 'object'
          for i, val of value
            re = new RegExp "\\b#{name}\\.#{i}\\b", 'g'
            rule = rule.replace re, (str, name) ->
              "'#{value[i]?.toString()}'"
          re = new RegExp "\\b#{name}\\b", 'g'
          rule = rule.replace re, (str, name) ->
            "'#{value.toString()}'"
        else
          re = new RegExp "\\b#{name}\\b", 'g'
          rule = rule.replace re, (str, name) ->
            value
      # replace not existing data values
      if meta?.values?
        for name of meta.values
          re = new RegExp "\\b#{name}(\\.\\w+|\\[\\d+\\])?\\b", 'g'
          rule = rule.replace re, 'null'
      # replace percent values
      rule = rule.replace /\b(\d+(\.\d+)?)%/g, (str, value) ->
        value / 100
      # replace binary values
      rule = rule.replace /\b(\d+(\.\d+)?)([kMGTPEYZ]?B)/g, (str) ->
        math.unit(str).toNumber('B')
      # replace interval values
      rule = rule.replace /\b(\d+(\.\d+)?)(ms|s|m|h|d)/g, (str) ->
        number.parseMSeconds str
      # replace operators
      for name, value of {and: '&&', or: '||', is: '==', isnt: '!=', not: '!'}
        re = new RegExp "\\b#{name}\\b", 'g'
        rule = rule.replace re, value
      @sensor.debug chalk.grey "#{@name} optimized: #{rule}"
      # run the code in sandbox
      sandbox = {}
      vm.runInNewContext "result = #{rule}", sandbox, {filename: 'monitor-sensor-rule.vm'}
      @sensor.debug chalk.grey "#{@name} rule result: #{status} = #{sandbox.result}"
      if sandbox.result
        @err = new Error @conf[status]
        return @status = status
    @status = 'ok'



# Export class
# -------------------------------------------------

module.exports =  Check

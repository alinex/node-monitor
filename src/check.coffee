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
# The sensor will use the check instance for storing it's data and is called in
# the context of the check.


# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:check')
chalk = require 'chalk'
util = require 'util'
EventEmitter = require('events').EventEmitter
vm = require 'vm'
math = require 'mathjs'
named = require('named-regexp').named
# include alinex modules
async = require 'alinex-async'
{string} = require 'alinex-util'
validator = require 'alinex-validator'
Report = require 'alinex-report'
# include classes and helpers
storage = require './storage'


# Configuration
# -------------------------------------------------
HISTORY_LENGTH = 5


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
    # will be filled on run
    @result = null
    @status = 'disabled'
    @err = null
    @date = []
    @values = {}
    # last results
    @history = []
    @changed = 0

  # ### Initialize check and sensor
  init: (cb) ->
    return cb() if @sensor?
    monitor ?= require './index'
    monitor.getSensor @type, (err, @sensor) =>
      return cb err if err
      # check config
      validator.check
        name: "#{@type}:#{@name}"
        value: @conf
        schema: @sensor.schema
      , (err) =>
        return cb err if err
        @sensor.init.call this, (err) =>
          return cb err if err
          @sensor.debug "#{chalk.grey @name} Initialized"
          return cb() unless @controller?
          # only add database entry if run below controller
          storage.check @controller.databaseID, @type, @name, @sensor.meta.category
          , (err, checkID) =>
            return cb err if err
            @databaseID = checkID
            cb()

  # ### Run one sensor check
  run: (cb) ->
    # stop if already running
    if @status is 'running'
      @date[1] = new Date()
      @err = new Error "Skipped test because it is called again while running."
      @setStatus()
      return cb @err, @status unless @databaseID
      # store in database
      return storage.results @databaseID, @type, @sensor.meta.values
      , @date[0], @values, (err) =>
        return cb err if err
        cb @err, @status
    @sensor.debug "#{chalk.grey @name} start check"
    @status = 'running'
    return @runNow null, cb unless @sensor.prerun?
    # call prerun first
    @sensor.prerun.call this, (@err, res) => @runNow res, cb


  # ### Really run (after optional prerun call)
  runNow: (opt, cb) ->
    @err = null
    @date = [new Date()]
    @values = {}
    @changed = 0
    # run the sensor
    fn = (@err, res) =>
      @sensor.debug "#{chalk.grey @name} ended check"
      @date[1] = new Date()
      # calculate results
      @sensor.calc.call this, res, (err) =>
        @err = err if not @err and err
        @setStatus()
        return cb @err, @status unless @databaseID
        # store in database
        storage.results @databaseID, @type, @sensor.meta.values
        , @date[0], @values, (err) =>
          return cb err if err
          cb @err, @status
    if opt?
      started = @date[0]
      @sensor.run.call this, opt, (err, res) =>
        fn err, res if started = @date[0]
    else
      started = @date[0]
      @sensor.run.call this, (err, res) =>
        fn err, res if started = @date[0]

  # set status from rules
  setStatus: ->
    @calcStatus()
    @sensor.debug "#{chalk.grey @name} result status:
    #{@status}#{if @err then ' (' + @err.message + ')' else ''}"
    for n, v of @values
      @sensor.debug "#{chalk.grey @name} result #{n}: #{v}"
    # add to history
    @history.unshift
      status: @status
      date: @date
      values: @values
      err: @err
    @history.pop() while @history.length > HISTORY_LENGTH
    # return status
    @status

  # calculate status
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

  # ### create text report
  report: (cb) ->
    last = @history[@history.length - 1]
    report = new Report()
    report.h2 "#{@sensor.meta.title} #{@name}"
    report.p @sensor.meta.description
    report.p "Last check results from #{last.date[0]} are:"
    # table with max. last 3 values
    data = []
    for key, conf of @sensor.meta.values
      continue unless value = last.values[key]
      if typeof value is 'object' and not Array.isArray value
        for k of value
          row = ["#{conf.title ? key}.#{k}"]
          row.push formatValue e.values[key][k], conf for e in @history[..2]
          data.push row
      else
        row = [conf.title ? key]
        row.push formatValue e.values[key], conf for e in @history[..2]
        data.push row
    col =
      0:
        title: 'LABEL'
      1:
        title: 'VALUE'
        align: 'right'
    if @history.length > 1
      for e, num in @history[1..2]
        col[num] = {title: 'PREVIOUS', align: 'right'}
    report.table data, col
    if @sensor.meta.hint
      report.quote @sensor.meta.hint
    cb null, report

  # Helper methods for sensor
  # -------------------------------------------------

  # ### Check expression against string
  #
  # It will will try to match the given expression once and return the matched
  # groups or false if not matched. The groups are an array with the full match as
  # first element or in case of named regexp an object with key 'match' containing
  # the full match.
  match: (text, re) ->
    return false unless re?
    unless re instanceof RegExp
      return if Boolean ~text.indexOf re then [re] else false
    # it's an regular expression
    useNamed = ~re.toString().indexOf '(:<'
    re = named re if useNamed
    return false unless match = re.exec text
    if useNamed
      matches = {}
      matches[name] = match.capture name for name of match.captures
    else
      matches = match[0..match.length]
    return matches



# Export class
# -------------------------------------------------

module.exports =  Check

# ### Format a value for better human readable display
formatValue = (value, config) ->
  # format with autodetect
  unless config
    return switch
      when typeof value is 'number'
        parts = (Math.round(value * 100) / 100).toString().split '.'
        parts[0] = parts[0].replace /\B(?=(\d{3})+(?!\d))/g, ","
        parts.join '.'
      else
        value
  # format using config setting
  switch config.type
    when 'percent'
      math.format(value*100, 2) + ' %'
    when 'byte'
      byte = math.unit value, 'B'
      byte.format 3
    when 'interval'
      long =
        d: 'day'
        m: 'minute'
      unit = long[config.unit] ? config.unit
      interval = math.unit value, unit
      interval = interval.to 'm' if interval.toNumber('s') > 120
      interval.format 2
    when 'float', 'integer'
      if config.unit?
        math.unit(value, config.unit).format 3
      else
        math.format value, 3
    when 'array'
      val = value[0..9].join ', '
      val += '...' if value.length > 10
      val
    when 'object'
      switch typeof value
        when 'string', 'number'
          value
        else
          if Array.isArray value
            val = value[0..9].join ', '
            val += '...' if value.length > 10
            val
          else
            util.inspect(value).replace /\n/g, ' '
    else
      val = value
      val += " #{config.unit}" if value and config.unit
      val

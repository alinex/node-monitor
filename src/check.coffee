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
# - prerun() - run some initialization which have to be done before each run
# - run() - run the sensor for the check
# - calc() - check the results
# - report() - generate a report after run
#
# The sensor will use the storage instance for storing it's data and is called in
# the context of the check.


# Node Modules
# -------------------------------------------------

# include base modules
chalk = require 'chalk'
util = require 'util'
EventEmitter = require('events').EventEmitter
vm = require 'vm'
math = require 'mathjs'
named = require('named-regexp').named
moment = require 'moment'
# include alinex modules
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
mode = {}

# Controller class
# -------------------------------------------------
class Check extends EventEmitter

  # ### General initialization
  @init: (setup, cb) ->
    mode = setup
    cb()

  # ### Create instance
  constructor: (setup, @controller) ->
    @type = setup.sensor
    @name = setup.name
    @depend = setup.depend
    @conf = setup.config ? {}
    @weight = setup.weight
    @hint = setup.hint
    # will be set after initialization
    @num = 0 # number of check in config
    @sensor = null
    @databaseID = null
    @base = null
    @rule = null
    # will be filled on run
    @err = null
    @date = []
    @result = {}
    @values = {}
    @status = 'disabled'
    # last results
    @history = []
    @changed = 0

  # ### Initialize check and sensor
  init: (cb) ->
    return cb() if @sensor?
    @rule =
      warn: @conf.warn
      fail: @conf.fail
    monitor ?= require './index'
    monitor.getSensor @type, (err, @sensor) =>
      return cb err if err
      # check config
      validator.check
        name: if @controller then "/controller/#{@controller.name}/check/#{@num}:#{@type}"
        else "/sensor:#{@type}"
        value: @conf
        schema: @sensor.schema
      , (err) =>
        return cb err if err
        @sensor.init.call this, (err) =>
          return cb err if err
          @sensor.debug "#{chalk.grey @name} Initialized"
          return cb() unless @controller?
          # only add database entry if run below controller
          storage.check @controller.databaseID, @type, @name, @sensor.meta
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
    return @runNow cb unless @sensor.prerun?
    # call prerun first
    @sensor.prerun.call this, (@err) =>
      return cb @err if @err
      @runNow cb


  # ### Really run (after optional prerun call)
  runNow: (cb) ->
    @err = null
    @date = [new Date()]
    @values = {}
    @changed = 0
    # run the sensor
    started = @date[0]
    @sensor.run.call this, (err, res) =>
      return unless started is @date[0]
      @err = err if not @err and err
      @result.data = res
      @sensor.debug "#{chalk.grey @name} ended check"
      @date[1] = new Date()
      # calculate results
      @sensor.calc.call this, (err) =>
        @err = err if not @err and err
        @setStatus()
        return cb null, @status unless @databaseID
        # store in database
        storage.results @databaseID, @type, @sensor.meta.values
        , @date[0], @values, (err) =>
          @err = err if not @err and err
          cb null, @status

  # set status from rules
  setStatus: ->
    for n, v of @values
      @sensor.debug "#{chalk.grey @name} result #{n}: #{util.inspect v}"
    @calcStatus()
    @sensor.debug "#{chalk.grey @name} result status:
    #{@status}#{if @err then ' (' + @err.message + ')' else ''}"
    # verbose output
    if mode.verbose > 1
      console.log chalk.grey "#{moment().format("YYYY-MM-DD HH:mm:ss")}
      Check #{chalk.white @type+':'+@name} => #{@controller.colorStatus @status}"
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
      continue unless @rule[status]
      rule = @rule[status]
      @sensor.debug chalk.grey "#{@name} check #{status} rule: #{@conf[status]}"
      # replace data values
      for name, value of @values
        if Array.isArray value
          for i, val in value
            re = new RegExp "\\b#{name}\\[#{i}\\]\\b", 'g'
            rule = rule.replace re, "'#{value[i]?.toString()}'"
          re = new RegExp "\\b#{name}\\b", 'g'
          rule = rule.replace re, "'#{value.toString()}'"
        else if typeof value is 'object'
          for i, val of value
            re = new RegExp "\\b#{name}\\.#{i}\\b", 'g'
            rule = rule.replace re, "'#{value[i]?.toString()}'"
          re = new RegExp "\\b#{name}\\b", 'g'
          rule = rule.replace re, "'#{value.toString()}'"
        else
          re = new RegExp "\\b#{name}\\b", 'g'
          rule = rule.replace re, value
      # replace not existing data values
      if @sensor.meta?.values?
        for name of @sensor.meta.values
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
        Number.parseMSeconds str
      # replace operators
      for name, value of {and: '&&', or: '||', is: '==', isnt: '!=', not: '!'}
        re = new RegExp "\\b#{name}\\b", 'g'
        rule = rule.replace re, value
      @sensor.debug chalk.grey "#{@name} optimized: #{rule}"
      # run the code in sandbox
      sandbox = {}
      vm.runInNewContext "result = #{rule}", sandbox, {filename: "sensor-#{@type}:#{@name}.vm"}
      @sensor.debug chalk.grey "#{@name} rule result: #{status} = #{sandbox.result}"
      if sandbox.result
        @err = new Error @conf[status]
        return @status = status
    @status = 'ok'

  # ### create text report
  report: ->
    last = @history[@history.length - 1]
    report = new Report()
    report.h2 "#{@sensor.meta.title} #{@name}"
    report.p @sensor.meta.description
    # status box
    boxtype =
      warn: 'warning'
      fail: 'alert'
    if @history.length
      list = Report.ul @history.map (e) ->
        "__STATUS #{e.status}__ at #{e.date[0]}
        #{if e.err then '\\\nBecause ' + e.err.message else ''}"
      report.box list, boxtype[@status] ? 'info'
    # table with max. last 3 values
    if @date.length
      report.p "Last check results from #{last.date[0]} are:"
      data = []
      for key, conf of @sensor.meta.values
        continue unless value = last.values[key]
        # support mappings from database sensor
        if @sensor.mapping?
          nconf = @sensor.mapping.call this, key
          conf = nconf if nconf
        # add rows
        if typeof value is 'object' and not Array.isArray value
          for k of value
            row = [key, "#{conf.title ? key}.#{k}"]
            row.push formatValue e.values[key][k], conf for e in @history[..2]
            data.push row
        else
          row = [conf.name ? key, conf.title ? key]
          for e in @history[..2]
            row.push formatValue e.values[key], conf
            console.log e.values[key], e.values, util.inspect formatValue e.values[key], conf
          data.push row
      col =
        0:
          title: 'NAME'
        1:
          title: 'LABEL'
        2:
          title: 'VALUE'
          align: 'right'
      if @history.length > 1
        num = 2
        for e in @history[1..2]
          col[++num] = {title: 'PREVIOUS', align: 'right'}
      report.table data, col
    # special report details
    if @sensor.report?
      report.add @sensor.report.call this
    # additional hints
    if @sensor.meta.hint
      report.quote @sensor.meta.hint
    if @hint
      report.quote @hint
    # configuration
    report.h3 'Configuration'
    report.p "The #{@type} sensor is configured with:"
    c = {}
    for key of @sensor.schema.keys
      c[key] = @conf[key] ? '---'
    report.table c, ['CONFIGURATION SETTING', 'VALUE']
    return report

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
      value = Number value if typeof value is 'string'
      if config.unit?
        math.unit(value, config.unit).format 3
      else
        math.format Number(value), 3
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

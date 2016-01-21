# Run an actor
# =================================================
# This will call the actor and work with it. A actor is not usable standalone
# and needs a action which defines it's environment.
#
# The actor should have the following API:
#
# - schema - validator compatible definition
# - meta - some meta informations
# - init() - setup of the actor for this check
# - run() - run the actor for the check
# - calc() - check the results
#
# The actoz will use the check instance for storing it's data and is called in
# the context of the action.


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
class Action extends EventEmitter

  # ### General initialization
  @init: (setup, cb) ->
    mode = setup
    cb()

  # ### Create instance
  constructor: (setup, @controller) ->
    @type = setup.actor
    @name = setup.name
    @conf = setup.config ? {}
    @hint = setup.hint
    # will be set after initialization
    @num = 0 # number of actor in config
    @actor = null
    @databaseID = null
    @base = null
    # will be filled on run
    @err = null
    @date = []
    @result = {}
    @values = {}
    @status = 'disabled'

  # ### Initialize check and actor
  init: (cb) ->
    return cb() if @actor?
    monitor ?= require './index'
    monitor.getActor @type, (err, @actor) =>
      return cb err if err
      # check config
      validator.check
        name: if @controller then "/controller/#{@controller.name}/action/#{@type}:#{@name}"
        else "/actor:#{@type}"
        value: @conf
        schema: @actor.schema
      , (err) =>
        return cb err if err
        @actor.init.call this, (err) =>
          return cb err if err
          @actor.debug "#{chalk.grey @name} Initialized"
          return cb() unless @controller?
          # only add database entry if run below controller
          storage.check @controller.databaseID, @type, @name, @actor.meta.category
          , (err, checkID) =>
            return cb err if err
            @databaseID = checkID
            cb()

  # ### Run one actor check
  run: (cb) ->
    # stop if already running
    if @status is 'running'
      @date[1] = new Date()
      @err = new Error "Skipped test because it is called again while running."
      @setStatus()
      return cb @err, @status unless @databaseID
      # store in database
      return storage.results @databaseID, @type, @actor.meta.values
      , @date[0], @values, (err) =>
        return cb err if err
        cb @err, @status
    @actor.debug "#{chalk.grey @name} start check"
    @status = 'running'
    return @runNow cb unless @actor.prerun?
    # call prerun first
    @actor.prerun.call this, (@err) =>
      return cb @err if @err
      @runNow cb


  # ### Really run (after optional prerun call)
  runNow: (cb) ->
    @err = null
    @date = [new Date()]
    @values = {}
    @changed = 0
    # run the actor
    started = @date[0]
    @actor.run.call this, (err, res) =>
      return unless started = @date[0]
      @err = err if not @err and err
      @result.data = res
      @actor.debug "#{chalk.grey @name} ended check"
      @date[1] = new Date()
      # calculate results
      @actor.calc.call this, (err) =>
        @err = err if not @err and err
        @setStatus()
        return cb null, @status unless @databaseID
        # store in database
        storage.results @databaseID, @type, @actor.meta.values
        , @date[0], @values, (err) =>
          @err = err if not @err and err
          cb null, @status

  # set status from rules
  setStatus: ->
    for n, v of @values
      @actor.debug "#{chalk.grey @name} result #{n}: #{util.inspect v}"
    @calcStatus()
    @actor.debug "#{chalk.grey @name} result status:
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
      continue unless @conf[status]
      rule = @conf[status]
      @actor.debug chalk.grey "#{@name} check #{status} rule: #{rule}"
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
      @actor.debug chalk.grey "#{@name} optimized: #{rule}"
      # run the code in sandbox
      sandbox = {}
      vm.runInNewContext "result = #{rule}", sandbox, {filename: "actor-#{@type}:#{@name}.vm"}
      @actor.debug chalk.grey "#{@name} rule result: #{status} = #{sandbox.result}"
      if sandbox.result
        @err = new Error @conf[status]
        return @status = status
    @status = 'ok'

  # ### create text report
  report: ->
    last = @history[@history.length - 1]
    report = new Report()
    report.h2 "#{@actor.meta.title} #{@name}"
    report.p @actor.meta.description
    # status box
    boxtype =
      warn: 'warning'
      fail: 'alert'
    if @history.length
      list = Report.ul @history.map (e) ->
        "__STATUS: #{e.status}__ at #{e.date[0]}
        #{if e.err then '\\\n' + e.err else ''}"
      report.box list, boxtype[@status] ? 'info'
    # table with max. last 3 values
    if @date.length
      report.p "Last check results from #{last.date[0]} are:"
      data = []
      for key, conf of @actor.meta.values
        continue unless value = last.values[key]
        # support mappings from database actor
        if @actor.mapping?
          nconf =  @actor.mapping.call this, key
          conf = nconf if nconf
        # add rows
        if typeof value is 'object' and not Array.isArray value
          for k of value
            row = [key, "#{conf.title ? key}.#{k}"]
            row.push formatValue e.values[key][k], conf for e in @history[..2]
            data.push row
        else
          row = [key, conf.title ? key]
          row.push formatValue e.values[key], conf for e in @history[..2]
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
    if @actor.report?
      report.add @actor.report.call this
    # additional hints
    if @actor.meta.hint
      report.quote @actor.meta.hint
    if @hint
      report.quote @hint
    # configuration
    report.h3 'Configuration'
    report.p "The #{@type} actor is configured with:"
    c = {}
    for key of @actor.schema.keys
      c[key] = @conf[key] ? '---'
    report.table c, ['CONFIGURATION SETTING', 'VALUE']
    return report

  # Helper methods for actor
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

module.exports =  Action

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

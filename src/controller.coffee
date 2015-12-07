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
config = require 'alinex-config'
# include classes and helpers
storage = require './storage'

# Initialized Data
# -------------------------------------------------
# This will be set on init
monitor = null  # require './index'


# Controller class
# -------------------------------------------------
class Controller extends EventEmitter

  # ### Create instance
  constructor: (@name, @conf, @mode) ->
    # ### Data storage with last results
    @status = 'disabled' # Last status
    @check = [] # Instances
    @timeout = null # timer for next run


  # ### Initialize
  init: (cb) ->
    monitor ?= require './index'
    async.parallel [
      (cb) =>
        # create base data in storage
        storage.controller @name, (err, @databaseID) =>
          return cb err if err
          async.each @conf.check, (setup, cb) =>
            check = new Check setup
            @check.push check
            check.init cb
          , cb
      (cb) =>
        # Validate configuration
        async.mapOf @conf.check, (setup, num, cb) =>
          monitor.getSensor setup.sensor, (err, sensor) =>
            if err
              debug chalk.red "Failed to load '#{setup.sensor}' lib because of: #{err}"
              return cb new Error "Check '#{setup.sensor}' not supported"
            validator.check
              name: "#{@name}:#{num}"
              value: setup.config
              schema: sensor.schema
            , (err, result) =>
              return cb err if err
              @conf.check[num].config = result
              cb()
        , cb
    ], (err) =>
      debug "#{chalk.grey @name} Initialized controller"
      cb()

  start: ->
    @run()
    @timeout = setTimeout =>
      @start()
    , @conf.interval * 1000


  stop: ->
    debug "#{chalk.grey @name} Stopped daemon mode"

  # ### Run once
  run: (cb =  ->) ->
    # for each sensor in parallel
    async.mapOf @check, (check, num, cb) =>
      check.run (err, res) =>
        return cb err if err


    # for each sensor in parallel
    async.mapOf @conf.check, (check, num, cb) =>
      # load sensor
      monitor = require './index'
      monitor.getSensor check.sensor, (err, sensorInstance) =>
        if err
          return cb new Error "Could not find sensor #{check.sensor}"
        name = "#{check.sensor}:#{sensorInstance.name check.config}"
        debug "#{chalk.grey @name} Running check #{name}..."
        # run sensor
        sensorInstance.run check.config, (err, res) =>
          return cb err if err
          res =
            sensor: sensorInstance
            config: check.config
            result: res
            hint: check.hint
          # check for status change and store it
          storage.statusCheck check.databaseID, res.result.date[1]
          , res.result.status, res.result.message, (err, changed) =>
            return cb err if err
            changed ?= @checks.length and res.result.status isnt @checks[0][num].status
            res.result.changed = changed
            # status info
            debugSensor "#{chalk.grey @name} Check #{name} => #{@colorStatus res.result.status}#{
              if res.result.message then ' (' + res.result.message + ')' else ''
              }#{if changed then ' CHANGED' else ''}"
            if @mode?.verbose
              msg = "Check #{chalk.white @name + ' ' + name} => #{@colorStatus res.result.status}"
              msg += " (#{res.result.message})" if res.result.message
              msg += " CHANGED" if changed
              if @mode.verbose > 1
                msg += '\n' + util.inspect res.result.values
              console.log chalk.grey msg
            # store results in storage
            storage.results check.databaseID, check.sensor, sensorInstance.meta.values
            , res.result.date[1], res.result.values, (err) =>
              return cb err if err
              # run analysis
              if changed or @mode?.verbose > 2
                sensorInstance.analysis check.config, res.result, (err, report) ->
                  return cb err if err
                  res.result.analysis = report
              cb null, res
    , (err, results) =>
#      console.log err, results
      return cb err if err
      res = Object.keys(results).map (k) -> # convert to array
        results[k].result
      # store all sensor results locally
      @checks.pop() if @checks.length > 5
      @checks.unshift res
      # calculate controller status
      status = calcStatus @conf.combine, @conf.check, res
      # check for status change and store it
      storage.statusController @databaseID, new Date(), status, (err, changed) =>
        return cb err if err
        changed ?= status isnt @status
        @status = status
        # info
        debug "#{chalk.grey @name} Controller => #{@colorStatus()}
        #{if changed then ' CHANGED' else ''}"
        # make report
        report = @report results
        if @mode?.verbose > 2
          console.error report
  #      console.log report
        @emit 'result', this
        cb()

  # ### Create a report
  report: (results) ->
    # make report
    context =
      name: @name
      config: @conf
      sensor: results
    report = """
    Controller #{@name} (#{@conf.name})
    ==============================================================================
    #{string.wordwrap @conf.description, 78}\n
    """
    if @conf.info
      report += "\n#{string.wordwrap @conf.info, 78}"
    report += "\n> __STATUS: #{@status}__ at #{new Date()}\n"
    if @conf.hint and @status isnt 'ok'
      report += "\n> #{string.wordwrap @conf.hint(context), 76, '\n> '}\n"
    if @conf.contact
      report += "\nContact Persons:\n\n"
      for group, glist of @conf.contact
        report += "* __#{string.ucFirst group}__\n"
        for entry in glist
          list = config.get "/monitor/contact/#{entry}"
          for contact in list
            contact = config.get "/monitor/contact/#{contact}"
            report += '  -'
            report += " #{contact.name}" if contact.name
            report += " <#{contact.email}>" if contact.email
#            report += "Phone: #{contact.phone.join ', '}" if contact.phone
            report += "\n"
    if @conf.ref
      report += "\nFor further assistance check the following links:\n\n"
      for name, list of @conf.ref
        report += "- #{name} " + list.map (e) ->
          name = e.replace(/^.*?\/\//, '').replace /(\/.*?)\/.*$/, '$1'
          "(#{name})[#{e}]"
        .join ', '
        report += '\n'
    report += "\nDetails of the individual sensor runs with their measurement
    values and maynbe some extended analysis will follow:\n"
    for num, entry of results
      report += sensor.report entry

    # keep report
    # action
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
#  console.log combine, check, result
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

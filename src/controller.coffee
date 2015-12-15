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
moment = require 'moment'
# include alinex modules
async = require 'alinex-async'
{string} = require 'alinex-util'
config = require 'alinex-config'
Report = require 'alinex-report'
# include classes and helpers
storage = require './storage'
Check = require './check'


# Configuration
# -------------------------------------------------
HISTORY_LENGTH = 5


# Initialized Data
# -------------------------------------------------
# This will be set on init
monitor = null  # require './index'


# Controller class
# -------------------------------------------------
class Controller extends EventEmitter

  # ### Create instance
  constructor: (@name, @conf, @mode) ->
    @check = [] # Instances added on initialization
    @timeout = null # timer for next run
    # Data storage with last results
    @status = 'disabled' # Last status
    @date = null # last run
    @err = null
    # last results
    @history = []
    @changed = 0


  # ### Initialize
  init: (cb) ->
    debug "#{chalk.grey @name} Initialize controller..."
    monitor ?= require './index'
    # create base data in storage
    storage.controller @name, (err, @databaseID) =>
      return cb err if err
      async.each @conf.check, (setup, cb) =>
        check = new Check setup, this
        @check.push check
        check.init cb
      , (err) =>
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
    async.map @check, (check, cb) =>
      check.run (err, status) =>
        if @mode?.verbose > 1
          console.log chalk.grey "#{moment().format("YYYY-MM-DD HH:mm:ss")}
          Check #{chalk.white check.type+':'+check.name} => #{@colorStatus status}"
        cb err, status
    , (err, res) =>
      return cb err if err
      @date = new Date()
      # calculate controller status
      status = calcStatus @conf.combine, @conf.check, res
      # check for status change and store it
      storage.statusController @databaseID, new Date(), status, (err, changed) =>
        return cb err if err
        # store new values
        @changed = changed ? status isnt @status
        @status = status
        # add to history
        @history.unshift
          status: @status
          date: @date
          err: @err
        @history.pop() while @history.length > HISTORY_LENGTH
        # info
        debug "#{chalk.grey @name} Controller => #{@colorStatus()}
        #{if changed then ' CHANGED' else ''}"
        # make report
        report = @report()
        if @mode?.verbose > 2
          console.error report.toConsole()
        @emit 'result', this
        if @mode?.verbose or @status isnt 'ok'
          console.log chalk.grey "#{moment().format("YYYY-MM-DD HH:mm:ss")}
          Controller #{chalk.white @name} => #{@colorStatus()}"
        cb()

  # ### Create a report
  report: (results) ->
    return ''
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
        val = values[result[num]]
        val-- if setup.weight is 'down' and val > 0
        val++ if setup.weight is 'up' and val < 2
        status = val if val > status
    when 'min'
      status = 9
      num = 0
      for num, setup of check
        continue if setup.weight is 0
        val = values[result[num]]
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
        val = values[result[num]]
        val-- if setup.weight is 'down' and val > 0
        val++ if setup.weight is 'up' and val < 2
        status += val * setup.weight
        num += setup.weight
      status = Math.round status/num
  # translate status number to name
  for name, val of values
    return name if status is val
  return 'ok'

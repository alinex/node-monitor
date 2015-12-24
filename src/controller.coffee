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
mode = {}

# Controller class
# -------------------------------------------------
class Controller extends EventEmitter

  # ### General initialization
  @init: (setup, cb) ->
    mode = setup
    cb()

  # ### Create instance
  constructor: (@name, @conf) ->
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





        # create a work queue
        queue = {}
        for num in [0..@check.length-1]
          if @check[num].depend
            args = @check[num].depend.slice()
            args-push (check, cb) =>
                check.run (err, status) =>
                  if mode.verbose > 1
                    console.log chalk.grey "#{moment().format("YYYY-MM-DD HH:mm:ss")}
                    Check #{chalk.white check.type+':'+check.name} => #{@colorStatus status}"
                  cb err, status
            queue[@check[num].conf.name ? num] = args
          else
            queue[@check[num].conf.name ? num] = (check, cb) =>
              check.run (err, status) =>
                if mode.verbose > 1
                  console.log chalk.grey "#{moment().format("YYYY-MM-DD HH:mm:ss")}
                  Check #{chalk.white check.type+':'+check.name} => #{@colorStatus status}"
                cb err, status
#        console.log @name, queue






        debug "#{chalk.grey @name} Initialized controller"
        cb()

  start: ->
    if @conf.disabled
      console.log chalk.grey "Controller #{@name} is disabled!"
      return
    @run()
    @timeout = setTimeout =>
      @start()
    , @conf.interval * 1000

  stop: ->
    debug "#{chalk.grey @name} Stopped daemon mode"


  # ### Run once
  run: (cb = ->) ->
    # for each sensor in parallel
    @status = 'running'
#    # makes problems in live environment
#    async.map @check, (check, cb) =>
    async.mapLimit @check, @conf.parallel, (check, cb) =>
      check.run (err, status) =>
        if mode.verbose > 1
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
        if mode.verbose or @status isnt 'ok'
          console.log chalk.grey "#{moment().format("YYYY-MM-DD HH:mm:ss")}
          Controller #{chalk.white @name} => #{@colorStatus()}"
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
        if mode.verbose > 2
          console.error "\n#{report.toConsole()}\n"
        @emit 'result', this
        cb null, @status

  # ### Create a report
  report: ->
    # make report
    context =
      name: @name
      config: @conf
    report = new Report()
    report.toc()
    report.h1 "Controller #{@name} (#{@conf.name})"
    report.p @conf.description if @conf.description
    report.p @conf.info if @conf.info
    # status box
    boxtype =
      warn: 'warning'
      fail: 'alert'
    list = Report.ul @history.map (e) ->
      "__STATUS: #{e.status}__ at #{e.date}"
    report.box list, boxtype[@status] ? 'info'
    # more info
    if @conf.hint and @status isnt 'ok'
      report.quote @conf.hint context
    # overview of checks
    report.h2 "Check Overview"
    report.p "The following checks will run but max. #{@conf.parallel} checks in
    parallel.:"
    report.ul @check.map (e) ->
      text = "#{e.type} #{e.name}"
      text += " (weight #{e.weight})" if e.weight
      text += " (depend on #{e.depend.join ', '})" if e.depend
      text
    combine =
      max: "The most critical status type of the checks is used for the controller."
      min: "The least critical status type of the checks is used for the controller."
      average: "The average status type of the checks is used for the controller."
    report.p combine[@conf.combine]
    report.p "See the last results of all of this checks below!"
    # contact
    report.h2 "More Information"
    if @conf.contact
      report.p Report.b "Contact Persons:"
      formatContact = (name) ->
        contact = config.get "/monitor/contact/#{name}"
        if Array.isArray contact
          return contact.map (e) -> formatContact(e)
        text = ''
        text += " #{contact.name}" if contact.name
        text += " <#{contact.email}>" if contact.email
        [text.trim()]
      ul = []
      for group, glist of @conf.contact
        ul.push "__#{string.ucFirst group}__"
        for e in glist
          ul = ul.concat formatContact e
      report.ul ul
    # references
    if @conf.ref
      report.p Report.b "For further assistance check the following links:"
      ul = []
      for name, list of @conf.ref
        ul.push "#{string.rpad name, 15} " + list.join ', '
      report.ul ul
    # add check results
    report.p "Details of the individual sensor runs with their measurement
    values and maybe some extended analysis will follow."
    report.add check.report() for check in @check
    # return result
    report

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

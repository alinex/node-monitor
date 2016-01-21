# Run an action rules
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
# The actors will use the check instance for storing it's data and is called in
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
config = require 'alinex-config'
# include classes and helpers
storage = require './storage'


# Initialized Data
# -------------------------------------------------
# This will be set on init
monitor = null  # require './index'
mode = {}
actors = []


# Controller class
# -------------------------------------------------
class Action extends EventEmitter


  # Initialize rule data
  # -------------------------------------------------
  # This will be called after controller is initialized.
  @init: (setup, cb) ->
    mode = setup
    monitor ?= require './index'
    @actions =
      list: {}
      count: 0
      date: new Date()
    # setup actors
    actors = monitor.listActor()
    # set specific one
    for name, setup in @conf.rule
      try
        if setup.email
          @actions.list.push new Action name, setup, this
        else
          @actions.list.unshift new Action name, setup, this
      catch err
        return cb err
    cb()


  # Run the action rules
  # -------------------------------------------------
  @run: (cb) ->
    if @changed
      @actions.count = 0
      @actions.date = @date
    @actions.count++
    debug "#{chalk.grey @controller.name} check rules"
    async.each @actions.list (action, cb) ->
      action.run cb
    , cb

  # ### Create instance
  constructor: (@name, @setup, @controller) ->
    # will be set on init
    @rule = null # current rule
    @type = null # list actor
    @base = null # template
    # and later before first action
    @actor = null # list actor
    @init()

  # ### Initialize check and actor
  init: ->
    # resolve rules
    rules = config.get '/monitor/rule'
    # check that rule is defined
    unless @rule = rules[name]
      throw new Error "No definition for rule #{@name}"
    # set actor list
    for type of actors
      continue unless @rule[type]
      @type = type
      @base = @rule[type]
    debug "#{chalk.grey @controller.name} initialized #{@name} rule"

  run: (cb) ->
    # no actor defined
    return cb() unless @actor
    # only work on specific status
    return cb() unless @rule.status is @controller.status
    # number of minimum attempts (controller runs) before informing.
    return cb() if @rule.attempt and @actions.count < @rule.attempt
    # time (in seconds) to wait before informing.
    if @rule.latency
      return cb() if new Date() < moment(@actions.date).add(@rule.latency, 'seconds').toDate()
    # if already done and not in redo time
    if @actions.list[name]?
      # Timeout (in seconds) without status change before informing again.
      if @rule.redo
        return cb() if new Date() < moment(@actions.list[name]).add(@rule.redo, 'seconds').toDate()
    # if ok, not changed and action is empty
# ###############################################################################################
# ###### TODO disabled for testing only ##############################################################
#      continue if not @changed and @status is 'ok' and Object.keys(@ruledata.action).length is 0
    # run actor
    @actions.action[name] = new Date()
    @runNow cb if @actor
    # initialize actor
    monitor.getActor @type, (err, @actor) =>
      @actor.init (err) =>
        return cb err if err
        @runNow cb if @actor

runNow: (cb) ->
  @actor.debug "#{chalk.grey @controller.name} run #{@name} actor"
  @actor.run (err) ->
    return cb err if err

    cb()







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
          # TODO enable storage
          cb()
#          storage.action @controller.databaseID, @type, @name
#          , (err, actionID) =>
#            return cb err if err
#            @databaseID = checkID
#            cb()

  # ### Run one actor check
  run: (cb) ->
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


# Export class
# -------------------------------------------------
module.exports =  Action

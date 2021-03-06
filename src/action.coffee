# Run an action rules
# =================================================
# This will call the actor and work with it. A actor is not usable standalone
# and needs a action which defines it's environment.
#
# The static class methods will be called in the controller context.
#
# The actor should have the following API:
#
# - schema - validator compatible definition
# - meta - some meta informations
# - init() - setup of the actor for this check
# - prerun() - run some initialization which have to be done before each run
# - run() - run the actor for the check
# - report() - generate a report after run
#
# The actors will use the storage instance for storing it's data and is called in
# the context of the action.


# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:action')
chalk = require 'chalk'
EventEmitter = require('events').EventEmitter
moment = require 'moment'
# include alinex modules
validator = require 'alinex-validator'
config = require 'alinex-config'
async = require 'alinex-async'
{object} = require 'alinex-util'
# include classes and helpers
storage = require './storage'


# Initialized Data
# -------------------------------------------------
# This will be set on init
monitor = null  # require './index'
mode = {}
actors = null


# Controller class
# -------------------------------------------------
class Action extends EventEmitter


  # Initialize rule data
  # -------------------------------------------------
  # This will be called after controller is initialized.
  @init: (setup, cb) ->
    mode = setup
    # set actions object in the controller
    @actions = []
    # setup actors
    monitor ?= require './index'
    actors = monitor.listActor()
    # resolve rules
    rules = config.get '/monitor/rule'
    # set specific one
    for rule, num in @conf.rule
      # use base settings
      while rule.base
        unless base = rules[rule.base]
          return cb new Error "No base rule with name #{rule.base} defined, like used
          in #{rule.name} rule of #{@controller?.name} controller"
        delete rule.base
        rule = object.extend {}, base, rule
      rule.name ?= "##{num}"
#      rule = rules[name]
      try
        if rule.email
          @actions.push new Action rule, this
        else
          @actions.unshift new Action rule, this
      catch error
        return cb new Error "#{error.message} #{error.stack.split(/\n/)[1].trim()}
        in #{rule.name} rule of #{@controller?.name} controller"
    cb()


  # Run all action rules
  # -------------------------------------------------
  @run: (cb) ->
    async.each @actions, (action, cb) ->
      action.run cb
    , cb

  # ### Create instance
  constructor: (@conf, @controller) ->
    @count = 0 # number of calls in current status
    @date = @controller?.date # last change of status
    @status = @controller?.status # last status
    # will be set on init
    @type = null # list actor
    @base = null # template
    # actor specific
    @actor = null # list actor
    @lastrun = null # date of last actor run
    @err = null # last error
    @values = {} # last results
    @init()

  # ### Initialize check and actor
  init: ->
    # check that rule is defined
    unless @conf
      throw new Error "No definition for rule #{@conf.name}"
    # set actor list
    monitor ?= require './index'
    for type in actors
      continue unless @conf[type]
      @type = type
      @base = @conf[type]
    debug "#{chalk.grey @controller?.name} initialized #{@conf.name} rule"

  # ### Check the Rules and run Actor
  run: (cb) ->
    if not @controller? or @controller.changed
      @count = 0
      @date = @controller?.date ? new Date()
    debug chalk.grey "#{@controller?.name} check #{@conf.name} rule"
    @count++
    # only work on specific status
    return cb() unless @conf.status is @controller?.status
# TODO reenable if not testing
#    # number of minimum attempts (controller runs) before informing.
#    return cb() if @conf.attempt and @count < @conf.attempt
    # time (in seconds) to wait before informing.
    now = new Date()
    if @conf.latency
      return cb() if now < moment(@date).add(@conf.latency, 'seconds').toDate()
    # if already done and not in redo time
    if @lastrun?
      # Timeout (in seconds) without status change before informing again.
      if @conf.redo
        return cb() if now < moment(@lastrun).add(@conf.redo, 'seconds').toDate()
      # don't run if no redo defined
      else
        return cb()
# TODO reenable if not testing
#    else if @controller?.status is 'ok' and not @controller?.cahnged
#      return cb()
    # run actor
    return @prerun cb if @actor
    # initialize actor first
    monitor.getActor @type, (err, @actor) =>
      if err
        return cb new Error "#{err.message} in #{@conf.name} rule
        of #{@controller?.name} controller"
      # check config
      validator.check
        name: if @controller then "/controller/#{@controller?.name}/action/#{@conf.name}/#{@type}"
        else "/actor:#{@type}"
        value: @conf[@type]
        schema: @actor.schema
        , (err) =>
          return cb err if err
          @actor.init.call this, (err) =>
            return cb err if err
            @prerun cb

  # ### Prerun
  prerun: (cb) ->
    return @runNow cb unless @actor.prerun?
    # call prerun first
    @actor.prerun.call this, (@err) =>
      return cb @err if @err
      @runNow cb

  # ### Run Actor
  runNow: (cb) ->
    @actor.debug "#{chalk.grey @controller?.name} run #{@conf.name} actor"
    @err = null
    @values = {}
    @lastrun = [new Date()]
    @actor.run.call this, (err) =>
      @lastrun.push new Date()
      @err = err if not @err and err
      @actor.debug "#{chalk.grey @controller?.name} finished #{@conf.name} actor"
      return cb() unless @controller?
      # add database entry if run below controller
      storage.action @databaseID, @type, @actor.meta.values
      , @date, @values, cb


# Export class
# -------------------------------------------------
module.exports =  Action

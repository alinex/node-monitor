# Run a check
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:check')
chalk = require 'chalk'
util = require 'util'
EventEmitter = require('events').EventEmitter
# include alinex modules
async = require 'alinex-async'
{string} = require 'alinex-util'
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
    @name = null # will be set after initialization
    @conf = setup.config

    @history = []
    @databaseID = null # set after storage init

    @status = 'disabled'
    @err = null
    @date = []
    @values = {}
    @changed = 0

  # ### Initialize
  init: (cb) ->
    return cb() if @sensor?
    monitor ?= require './index'
    monitor.getSensor @type, (err, @sensor) =>
      return cb err if err
      @name = @sensor.name @conf
      debug "#{chalk.grey @type + ':' + @name} Initialized"
      storage.check controller.databaseID, @type, @name, @sensor.meta.category
      , (err, checkID) ->
        return cb err if err
        @databaseID = checkID
        cb()

  # ### Run one sensor check
  run: (cb) ->
    @sensor.debug "#{chalk.grey work.sensor.name work.config} start check"
    @status = 'running'
    @err = null
    @date = [new Date()]
    @values = {}
    @changed = 0
    @sensor.run this, (@err, res) ->
      @sensor.debug "#{chalk.grey work.sensor.name work.config} ended check"
      @date[1] = new Date()
      @sensor.check this, res, (err, @values) ->
        cb null, @calcStatus()




# Export class
# -------------------------------------------------

module.exports =  Check

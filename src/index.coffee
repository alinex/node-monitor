# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor')
chalk = require 'chalk'
fspath = require 'path'
EventEmitter = require('events').EventEmitter
# include alinex modules
config = require 'alinex-config'
async = require 'alinex-async'
# include classes and helpers
schema = require './configSchema'
Controller = require './controller'


class Monitor extends EventEmitter

  # Setup
  # -------------------------------------------------

  setup: (selection = null) ->
    # add schema for module's configuration
    config.setSchema '/monitor', schema
    # set module search path
    config.register 'monitor', fspath.dirname __dirname

    # register selected controllers from /etc/monitor-controller
    if selection?.length
      # specific controllers only
      for ctrl in selection
        config.register 'monitor', fspath.dirname(__dirname),
          uri: "#{ctrl}*"
          folder: 'controller'
          path: 'monitor/controller'
    else
      # read all controllers
      config.register 'monitor-controller', fspath.dirname(__dirname),
        folder: 'controller'
        path: 'monitor/controller'

  init: (cb) ->
    debug "Loading configuration..."
    config.init (err) =>
      return cb err if err
      @conf = config.get '/monitor'
      cb()

  # Controller Setup
  # -------------------------------------------------

  instantiate: (cb) ->
    return cb() if @controller
    debug "Instantiate controllers..."
    @controller = {}
    for name, def of @conf.controller
      @controller[name] = new Controller name, def
    # parallel instantiation
    async.each @controller, (ctrl, cb) =>
      ctrl.init cb
    , cb

  # Run Controller
  # -------------------------------------------------

  onetime: (cb = ->) ->
    @instantiate (err) =>
      return cb err if err
      async.mapOf @controller, (ctrl, name, cb) ->
        ctrl.run cb
      , cb
      this

  start: ->
    @instantiate() unless @controller
    this

  stop: ->
    console.log 1111
    this


# Export Singleton
# -------------------------------------------------

module.exports = new Monitor()

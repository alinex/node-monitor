# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor')
chalk = require 'chalk'
fspath = require 'path'
EventEmitter = require('events').EventEmitter
math = require 'mathjs'
# include alinex modules
config = require 'alinex-config'
async = require 'alinex-async'
Exec = require 'alinex-exec'
database = require 'alinex-database'
{string} = require 'alinex-util'
fs = require 'alinex-fs'
# include classes and helpers
schema = require './configSchema'
Controller = require './controller'
storage = require './storage'

# Initialized Data
# -------------------------------------------------
# This will be set on init
cache = {} # object of controller, sensors, ...

# Monitor class
# -------------------------------------------------
# This module is defined as a class exporting a singleton instance to have events
# possible within it.
class Monitor extends EventEmitter

  # Setup
  # -------------------------------------------------
  setup: (selection = null) ->
    # setup module configs first
    async.each [Exec, database], (mod, cb) ->
      mod.setup cb
    , (err) ->
      return cb err if err

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

  init: (setup, cb) ->
    debug "Loading configuration..."
    async.series [
      (cb) -> config.init cb
      (cb) => @initPlugins cb
      (cb) -> storage.init cb
      (cb) => @initController setup, cb
    ], cb

  initPlugins: (cb) ->
    # find sensor plugins
    debug "Loading plugins..."
    debug "load base plugin into system"
    fs.find "#{__dirname}/sensor",
      type: 'f'
      maxdepth: 1
    , (err, list) ->
      cache.sensors = list.map (e) -> fspath.basename e, fspath.extname e
      # try to load sensor from plugins
      plugins = config.get "/monitor/plugins"
      return cb() unless plugins
      async.each plugins, (plugin, cb) ->
        debug "load #{plugin} into system"
        try
          lib = require plugin
        catch err
          return cb new Error "Could not load plugin #{plugin}: #{err.message}"
        async.parallel [
          # sensors
          (cb) ->
            return cb() unless lib.listSensor?
            lib.listSensor (err, list) ->
              return cb err if err
              cache.sensors = cache.sensor.concat list
        ], cb
      , cb

  initController: (setup, cb) ->
    debug "Instantiate controllers..."
    @controller = {}
    for name, def of config.get "/monitor/controller"
      @controller[name] = new Controller name, def, setup
      @controller[name].on 'result', (ctrl) => @emit 'result', ctrl
    # parallel instantiation
    async.each @controller, (ctrl, cb) ->
      ctrl.init cb
    , cb


  # Control daemon mode
  # -------------------------------------------------

  start: ->
    @instantiate() unless @controller
    this

  stop: ->
    console.log 1111
    this

  # Controller
  # -------------------------------------------------
  listController: ->
    Object.keys @controller

  getController: (name, cb) ->
    cb null, @controller[name]

  showController: (name, cb) ->
    conf = @controller[name].conf
    context =
      name: name
      config: conf
    info = chalk.bold """
    #{name}: #{conf.name}
    ===========================================================================\n
    """
    info += """
    #{string.wordwrap conf.description, 78}\n
    """
    if conf.info
      info += "\n#{string.wordwrap conf.info, 78}"
    if conf.hint
      info += "\n> #{string.wordwrap conf.hint(context).trim(), 76, '\n> '}\n"
    # checks
    interval = math.unit conf.interval, 'seconds'
    interval = interval.to switch
      when conf.interval >= 14400 then 'hours'
      when conf.interval >= 300 then 'minutes'
      else 'seconds'
    info += "\nThe following checks will run every #{interval.format()}:\n\n"
    async.map conf.check, (check, cb) =>
      @getSensor check.sensor, (err, sensorInstance) ->
        return cb err if err
        cb null, "* #{check.sensor} #{sensorInstance.name check.config}\n"
    , (err, results) ->
      return cb err if err
      info += results.join '\n'

      # actor rules

      # contact
      if conf.contact
        info += "\nContact Persons:\n\n"
        for group, glist of conf.contact
          info += "* __#{string.ucFirst group}__\n"
          for entry in glist
            list = config.get "/monitor/contact/#{entry}"
            for contact in list
              contact = config.get "/monitor/contact/#{contact}"
              info += '  -'
              info += " #{contact.name}" if contact.name
              info += " <#{contact.email}>" if contact.email
  #            info += "Phone: #{contact.phone.join ', '}" if contact.phone
              info += "\n"
      # references
      if conf.ref
        info += "\nFor further assistance check the following links:\n"
        for name, list of conf.ref
          info += "\n- #{string.rpad name, 15} " + list.join ', '
      cb null, info

  runController: (name, cb) ->
    list = if name then {name: @getController[name]} else @controller
    async.mapOf list, (ctrl, name, cb) ->
      ctrl.run cb
    , (err) ->
      cb err


  # Sensor Info
  # -------------------------------------------------
  listSensor: ->
    return cache.sensors

  getSensor: (name, cb) ->
    sensor = null
    # try to load sensor from main
    try
      return cb null, require "./sensor/#{name}"
    # try to load sensor from plugins
    plugins = config.get "/monitor/plugins"
    return cb new Error "Could not find sensor #{name}" unless plugins
    async.map plugins, (plugin, cb) ->
      try
        lib = require plugin
      catch err
        return cb err
      lib.getSensor name, (err, sensor) ->
        cb() if err
        cb null, sensor
    , (err, list) ->
      for sensor in list
        return cb null, sensor if sensor
      # sensor not found
      cb new Error "Could not find sensor #{name}" unless plugins

  showSensor: (name) ->
    "xxxxx"


# Export Singleton
# -------------------------------------------------

module.exports = new Monitor()

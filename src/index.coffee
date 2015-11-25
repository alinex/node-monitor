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
Exec = require 'alinex-exec'
database = require 'alinex-database'
{string} = require 'alinex-util'
fs = require 'alinex-fs'
# include classes and helpers
schema = require './configSchema'
Controller = require './controller'
storage = require './storage'


allSensors = null

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

  init: (cb) ->
    debug "Loading configuration..."
    config.init (err) =>
      return cb err if err
      @conf = config.get '/monitor'
      if @conf.plugins?
        for plugin in @conf.plugins
          try
            require plugin
          catch err
            cb new Error "Could not load plugin #{plugin}: #{err.message}"
      cb()

  # Controller Setup
  # -------------------------------------------------

  instantiate: (setup, cb) ->
    return cb() if @controller
    debug "Instantiate controllers..."
    @controller = {}
    for name, def of @conf.controller
      @controller[name] = new Controller name, def, setup
      @controller[name].on 'result', (ctrl) => @emit 'result', ctrl
    # parallel instantiation
    async.each @controller, (ctrl, cb) ->
      ctrl.init cb
    , cb

  # Run Controller
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
    Object.keys config.get '/monitor/controller'

  showController: (name, conf) ->
    conf ?= config.get "/monitor/controller/#{name}"
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
      info += "\n> #{string.wordwrap conf.hint(context), 76, '\n> '}\n"
    # interval

    # sensors

    # actor rules

    # contact
    if conf.contact
      info += "Contact Persons:\n\n"
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
    info

  runController: (setup, cb) ->
    unless cb
      cb = setup
      setup = null
      unless cb
        cb = ->
    async.series [
      (cb) -> storage.init cb
      (cb) => @instantiate setup, cb
    ], (err) =>
      return cb err if err
      async.mapOf @controller, (ctrl, name, cb) ->
        ctrl.run cb
      , (err) ->
        Exec.close()
        cb err
    this

  # Sensor Info
  # -------------------------------------------------
  listSensors: (cb) ->
    return cb null, allSensors if allSensors?
    fs.find "#{__dirname}/sensor",
      type: 'f'
      maxdepth: 1
    , (err, list) ->
      allSensors = list.map (e) -> fspath.basename e, fspath.extname e
      # try to load sensor from plugins
      plugins = config.get "/monitor/plugins"
      return cb null, allSensors unless plugins
      async.map plugins, (plugin, cb) ->
        try
          lib = require plugin
        catch err
          return cb err
        lib.listSensors cb
      , (err, results) ->
        allSensors = allSensors.concat.apply this, results
        cb null, allSensors

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

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
      cache.sensor = {}
      for e in list
        name = fspath.basename e, fspath.extname e
        cache.sensor[name] = "./sensor/#{name}"
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
              for name, path of list
                cache.sensor[name] = "#{plugin}/#{path}"
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


  # List Elements
  # -------------------------------------------------
  listController: -> Object.keys @controller
  listSensor: -> list 'sensor'
  listActor: -> list 'actor'
  listExplorer: -> list 'explorer'


  # Get specified Element
  # -------------------------------------------------
  getController: (name, cb) -> cb null, @controller[name]
  getSensor: (name, cb) -> get 'sensor', name, cb
  getActor: (name, cb) -> get 'actor', name, cb
  getExplorer: (name, cb) -> get 'explorer', name, cb

  # Show information about specified Element
  # -------------------------------------------------
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

  showSensor: (name) ->
    "xxxxx"


  # Run specified Element
  # -------------------------------------------------
  runController: (name, cb) ->
    list = if name then {name: @controller[name]} else @controller
    async.mapOf list, (ctrl, name, cb) ->
      ctrl.run cb
    , (err) ->
      cb err


# Export Singleton
# -------------------------------------------------

module.exports = new Monitor()


# Element Management
# -------------------------------------------------
# This methods are used to work with the cached elements which are setup on
# initialization phase by initPlugin().

cache = {} # object of sensors, actors and explorers with require path

# ### list elements
list = (element) ->
  Object.keys cache[element]

# ### get specified element module
get = (element, name, cb) ->
  return cb new Error "Could not find #{element} #{name}" unless cache[element][name]?
  # try to load sensor from plugins
  try
    cb null, require cache[element][name]
  catch err
    return cb err

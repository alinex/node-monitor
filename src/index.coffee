# Main controlling class
# =================================================
# This is the real main class which can be called using it's API. Other modules
# like the cli may be used as bridges to this.


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
Report = require 'alinex-report'
# include classes and helpers
schema = require './configSchema'
Controller = require './controller'
storage = require './storage'


# Initialized Data
# -------------------------------------------------
# This will be set on init

# ### General Mode
# This is a collection of base settings which may alter the runtime of the system
# without changing anything in the general configuration. This values may also
# be changed at any time.
mode =
  verbose: 0 # verbosity level
  try: false # Is this a try run that won't change anything?


# Monitor class
# -------------------------------------------------
# This module is defined as a class exporting a singleton instance to have events
# possible within it.
#
# T
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

  init: (@mode, cb) ->
    mode = @mode
    debug "Loading configuration..."
    async.series [
      (cb) -> config.init cb
      (cb) => @initPlugins cb
      (cb) -> storage.init mode, cb
      (cb) => @initController cb
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

  initController: (cb) ->
    debug "Instantiate controllers..."
    Controller.init mode, (err) =>
      return cb err if err
      @controller = {}
      for name, def of config.get "/monitor/controller"
        @controller[name] = new Controller name, def
        @controller[name].on 'result', (ctrl) => @emit 'result', ctrl
      # parallel instantiation
      async.each @controller, (ctrl, cb) ->
        ctrl.init cb
      , cb


  # Control daemon mode
  # -------------------------------------------------

  start: ->
    @instantiate() unless @controller
    debug "start daemon"
    for name, ctrl of @controller
      ctrl.start()
    this

  stop: ->
    debug "stop daemon"


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
    ctrl = @controller[name]
    conf = ctrl.conf
    context =
      name: name
      config: conf
    report = new Report()
    report.h1 "#{name}: #{conf.name}"
    report.p conf.description
    report.p conf.info if conf.info
    report.quote conf.hint context if conf.hint
    # checks
    interval = math.unit conf.interval, 'seconds'
    interval = interval.to switch
      when conf.interval >= 14400 then 'hours'
      when conf.interval >= 300 then 'minutes'
      else 'seconds'
    report.p "The following checks will run every #{interval.format()}:"
    report.ul ctrl.check.map (e) -> "#{e.type} - #{e.name}"
#    async.map conf.check, (check, cb) =>
#      @getSensor check.sensor, (err, sensorInstance) ->
#        return cb err if err
#        cb null, "* #{check.sensor} #{sensorInstance.name}\n"
#    , (err, results) ->
#      return cb err if err
###################################      info += results.join '\n'
#      for add in results
#        console.log add
#        report.add add
      # actor rules

    # contact
    if conf.contact
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
      for group, glist of conf.contact
        ul.push "__#{string.ucFirst group}__"
        for e in glist
          ul = ul.concat formatContact e
      report.ul ul
    # references
    if conf.ref
      report.p Report.b "For further assistance check the following links:"
      ul = []
      for name, list of conf.ref
        ul.push "#{string.rpad name, 15} " + list.join ', '
      report.ul ul
    cb null, report

  showSensor: (name) ->
    "xxxxx"


  # Run specified Element
  # -------------------------------------------------
  runController: (name, cb) ->
    if name
      list = {}
      list[name] = @controller[name]
    list ?= @controller
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

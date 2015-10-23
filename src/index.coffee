# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
fspath = require 'path'
# include alinex modules
config = require 'alinex-config'
# include classes and helpers
schema = require './configSchema'

# Setup
# -------------------------------------------------

exports.setup = (selection = null) ->
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

exports.init = config.init



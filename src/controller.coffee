# Controller for specific element
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:controller')
chalk = require 'chalk'
EventEmitter = require('events').EventEmitter
# include alinex modules
async = require 'alinex-async'
{string} = require 'alinex-util'
# include classes and helpers


# Controller class
# -------------------------------------------------
class Controller extends EventEmitter

  # ### Create instance
  constructor: (@name, @conf) ->
    debug "#{@name} Initialized controller"

  run: ->
    debug "#{@name} Start analyzation..."


# Export class
# -------------------------------------------------

module.exports =  Controller

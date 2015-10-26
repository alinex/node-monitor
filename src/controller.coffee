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
    debug "#{chalk.grey @name} Initialized controller"

  run: (cb = -> ) ->
    debug "#{chalk.grey @name} Start analyzation..."
    # for each sensor in parallel

    # check
    # run sensor
    # keep results
    # output status line on console
    # store results

    # analysis on state change
    # run analyzer
    # keep report

    # action
    # create full report
    # store  report
    # send email

    cb()


# Export class
# -------------------------------------------------

module.exports =  Controller

# Ping test class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
EventEmitter = require('events').EventEmitter
object = require('alinex-util').object
colors = require 'colors'

# Sensor class
# -------------------------------------------------
class Sensor extends EventEmitter

  # ### Default Configuration
  @config =
    verbose: false

  # ### Create instance
  constructor: (config) ->
    @config = object.extend {}, @constructor.config, config
    unless config
      throw new Error "Could not initialize sensor without configuration."

  _start: (title) ->
    @result =
      date: new Date
      status: 'running'
    @emit 'start'
    if @config.verbose
      console.log "#{title}..."

  _end: (status, message) ->
    @result.status = status
    @result.message = message if message
    if @config.verbose and status isnt 'ok'
      if status is 'fail' and message
        console.log "#{@constructor.meta.name} #{status}: #{message}".red
      else if status is 'fail'
        console.log "#{@constructor.meta.name} #{status}!".red
      else
        console.log "#{@constructor.meta.name} #{status}!".magenta
      console.log @result.value
    @emit status
    @emit 'end'

# Export class
# -------------------------------------------------
module.exports = Sensor

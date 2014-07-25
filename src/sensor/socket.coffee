# Socket test class
# =================================================
# This may be used to check the connection to different ports.

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:sensor:socket')
colors = require 'colors'
EventEmitter = require('events').EventEmitter
object = require('alinex-util').object
Sensor = require './base'
# specific modules for this check
net = require 'net'

# Sensor class
# -------------------------------------------------
class SocketSensor extends Sensor

  # ### General information
  # This information may be used later for display and explanation.
  @meta =
    name: 'Socket'
    description: "Use TCP sockets to check for the availability of a service
    behind a given port."
    category: 'net'
    level: 1

  # ### Value Definition
  # This will define the values measured and their specifics, used to display
  # results.
  @values = [
    name: 'success'
    description: "true if connection is possible"
    type: 'bool'
  ,
    name: 'responsetime'
    description: "time till connection could be established"
    type: 'int'
    unit: 'ms'
  ]

  # ### Default Configuration
  # The values starting with underscore are general help messages.
  @config =
    _host: "hostname or ip address to test"
    _port: "portnumber to connect to"
    timeout: 2
    _timeout: "timeout in seconds"
    responsetime: 1000
    _responsetime: "maximum time in ms till connection is established"

  # ### Create instance
  constructor: (config) ->
    super object.extend {}, @constructor.config, config
    unless config
      throw new Error "Could not initialize sensor without configuration."

  # ### Run the check
  run: (cb = ->) ->

    # run the ping test
    @_start "Connect #{@config.host}:#{@config.port}"
    @result.data = ''

    socket = new net.Socket()
    debug "connect to #{@config.host}:#{@config.port}"
    start = new Date().getTime()
    socket.setTimeout @config.timeout*1000
    socket.connect @config.port, @config.host, =>
      debug "connection established"
      end = new Date().getTime()
      socket.destroy()

      # get the values
      @result.value = value = {}
      value.success = true
      value.responsetime = end-start
      debug value

      # evaluate to check status
      status = switch
        when not value.success
          'fail'
        when  @config.responsetime? and value.responsetime > @config.responsetime
          'warn'
        else
          'ok'
      message = switch status
        when 'fail'
          "#{@constructor.meta.name} exited with status #{status}"
      @_end status, message
      return cb new Error message if status is 'fail'
      cb()

    socket.on 'timeout', =>
      message = "server not responding, timeout occurred"
      debug message.red
      @_end 'fail', message
      cb new Error message

    socket.on 'error', (err) =>
      debug err.toString().red
      @_end 'fail', err
      cb err

# Export class
# -------------------------------------------------
module.exports = SocketSensor

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
    timeout: 1
    _timeout: "timeout in seconds"
    responsetime: 1000
    _responsetime: "maximum time till connection is established"

  # ### Create instance
  constructor: (config) ->
    super object.extend {}, @constructor.config, config
    unless config
      throw new Error "Could not initialize sensor without configuration."

  # ### Run the check
  run: (cb = ->) ->

    # run the ping test
    @_start "Connect #{@config.host}:#{@config.port}..."
    @result.data = ''







    debug "exec> #{ping.cmd} #{ping.args.join ' '}"
    proc = spawn ping.cmd, ping.args

    # collect results
    stdout = stderr = ''
    proc.stdout.on 'data', (data) ->
      stdout += (text = data.toString())
      for line in text.trim().split /\n/
        debug line.grey
    proc.stderr.on 'data', (data) ->
      stderr += (text = data.toString())
      for line in text.trim().split /\n/
        debug line.magenta
    store = (code) =>
      @result.data = ''
      @result.data += "STDOUT:\n#{stdout}\n" if stdout
      @result.data += "STDERR:\n#{stderr}\n" if stderr
      @result.data += "RETURN CODE: #{code}" if code?

    # Error management
    proc.on 'error', (err) ->
      store()
      @_end 'fail', err
      cb err

    # process finished
    proc.on 'exit', (code) =>
      store code
      # get the values
      @result.value = value = {}
      value.success = code is 0
      num = 0
      sum = 0
      re = /time=(\d+.?\d*) ms/g
      while match = re.exec stdout
        time = parseFloat match[1]
        num++
        sum += time
        if not value.responsemin? or time < value.responsemin
          value.responsemin = time
        if not value.responsemax? or time > value.responsemax
          value.responsemax = time
      value.responsetime = Math.round(sum/num*10)/10.0
      match = /\s(\d+)% packet loss/.exec stdout
      value.quality = 100-match?[1]
      debug value
      # evaluate to check status
      status = switch
        when not value.success or value.quality < 100
          'fail'
        when  @config.responsetime? and value.responsetime > @config.responsetime
        ,  @config.responsemax? and value.responsemax > @config.responsemax
          'warn'
        else
          'ok'
      message = switch status
        when 'fail'
          "#{@constructor.meta.name} exited with code #{status}"
      @_end status, message
      return cb new Error message if status is 'fail'
      cb()

# Export class
# -------------------------------------------------
module.exports = SocketSensor

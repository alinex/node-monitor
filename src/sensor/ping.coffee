# Ping test class
# =================================================
# This is a basic test to check if connection to a specific server is possible.
# Keep in mind that some servers mare blocked through firewall settings.

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:sensor:ping')
colors = require 'colors'
EventEmitter = require('events').EventEmitter
object = require('alinex-util').object
Sensor = require './base'
# specific modules for this check
os = require 'os'
{spawn} = require 'child_process'

# Sensor class
# -------------------------------------------------
class PingSensor extends Sensor

  # ### General information
  # This information may be used later for display and explanation.
  @meta =
    name: 'Ping'
    description: "Test the reachability of a host on a IP network and measure the
    round-trip time for the messages send."
    category: 'net'
    level: 1

  # ### Value Definition
  # This will define the values measured and their specifics, used to display
  # results.
  @values = [
    name: 'success'
    description: "true if packets were echoed back"
    type: 'bool'
  ,
    name: 'responsetime'
    description: "round-trip time of the first packet"
    type: 'int'
    unit: 'ms'
  ,
    name: 'quality'
    description: "quality of response (packets succeeded)"
    type: 'percent'
  ]

  # ### Default Configuration
  # The values starting with underscore are general help messages.
  @config =
    _host: "hostname or ip address to test"
    count: 1
    _count: "number of packets to send"
    timeout: 1
    _timeout: "timeout in seconds for response"

  # ### Create instance
  constructor: (config) ->
    super object.extend {}, @constructor.config, config
    unless config
      throw new Error "Could not initialize sensor without configuration."

  run: (cb = ->) ->

    # comand syntax, os dependent
    p = os.platform()
    ping = switch
      when p is 'linux'
        cmd: '/bin/ping'
        args: ['-c', @config.count, '-W', @config.timeout]
      when p.match /^win/
        cmd: 'C:/windows/system32/ping.exe'
        args: ['-n', @config.count, '-w', @config.timeout*1000]
      when p is 'darwin'
        cmd: '/sbin/ping'
        args: ['-c', @config.count, '-t', @config.timeout]
      else
        throw new Error "Operating system #{p} is not supported in ping."
    ping.args.push @config.host

    # run the ping test
    @_start "Ping #{@config.host}..."
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
      @result.value = {}
      @result.value.success = code is 0
      num = 0
      value = 0
      re = /time=(\d+.?\d*) ms/g
      while match = re.exec stdout
        num++
        value += parseFloat match[1]
      @result.value.responsetime = Math.round(value/num*10)/10.0
      match = /\s(\d+)% packet loss/.exec stdout
      @result.value.quality = 100-match?[1]
      debug @result.value
      # evaluate to check status
      status = switch
        when not @result.value.success
          'fail'
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
module.exports = PingSensor

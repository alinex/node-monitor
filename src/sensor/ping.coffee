# Ping test class
# =================================================
# This is a basic test to check if connection to a specific server is possible.
# Keep in mind that some servers mare blocked through firewall settings.
#
# The warning level is based upon the round-trip time of packets which are
# typically:
#
#     1 ms        100BaseT-Ethernet
#     10 ms       WLAN 802.11b
#     40 ms       DSL-6000 without fastpath
#     < 50 ms     internet regional
#     55 ms       DSL-2000 without fastpath
#     100–150 ms  internet europe to usa
#     200 ms      ISDN
#     300 ms      internet europe to asia
#     300-400 ms  UMTS
#     700–1000 ms GPRS


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
  # results. Explanation in the code.
  @values = [
    name: 'success'
    description: "true if packets were echoed back"
    type: 'bool'
  ,
    name: 'responsetime'
    description: "average round-trip time of packets"
    type: 'int'
    unit: 'ms'
  ,
    name: 'responsemin'
    description: "minimum round-trip time of packets"
    type: 'int'
    unit: 'ms'
  ,
    name: 'responsemax'
    description: "maximum round-trip time of packets"
    type: 'int'
    unit: 'ms'
  ,
    name: 'quality'
    description: "quality of response (packets succeeded)"
    type: 'percent'
  ]

  # ### Default Configuration
  # The values starting with underscore are general help messages.
  # Explanation in the code.
  @config =
    _host: "hostname or ip address to test"
    count: 1
    _count: "number of packets to send"
    timeout: 1
    _timeout: "timeout in seconds for response"
    responsetime: 500
    _responsetime: "maximum average round-trip time in ms (else warning state)"
    responsemax: 1000
    _responsemax: "maximum round-trip time in ms of any packet (else warning state)"

  # ### Create instance
  constructor: (config) ->
    super object.extend {}, @constructor.config, config
    unless config
      throw new Error "Could not initialize sensor without configuration."

  # ### Run the check
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
    @_start "Ping #{@config.host}"
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
    proc.on 'error', (err) =>
      store()
      debug err.toString().red
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
          "#{@constructor.meta.name} exited with status #{status}"
      @_end status, message
      return cb new Error message if status is 'fail'
      cb()

# Export class
# -------------------------------------------------
module.exports = PingSensor

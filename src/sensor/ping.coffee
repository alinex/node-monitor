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

# Find the description of the possible configuration values and the returned
# values in the code below.

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:sensor:ping')
# include alinex packages
{object,number} = require 'alinex-util'
# include classes and helper
Sensor = require '../base'
# specific modules for this check
os = require 'os'

# Sensor class
# -------------------------------------------------
class PingSensor extends Sensor

  # ### General information
  #
  # This information may be used later for display and explanation.
  @meta =
    name: 'Ping'
    description: "Test the reachability of a host on a IP network and measure the
    round-trip time for the messages send."
    category: 'net'
    level: 1
    hint: "Check the network card configuration if local ping won't work or the
    network connection for external pings. "

    # ### Configuration
    #
    # Definition of all possible configuration settings (defaults included).
    # It's a n[alinex-validator](http://alinex.githhub.io/node-validator)
    # compatible schema definition:
    config:
      title: "Ping test"
      type: 'object'
      allowedKeys: true
      entries:
        host:
          title: "Hostname or IP"
          description: "the server hostname or ip address to be called for ping"
          type: 'string'
        count:
          title: "Number of Packets"
          description: "the number of ping packets to send, each after the other"
          type: 'integer'
          default: 1
          min: 1
          max: 10000
        interval:
          title: "Wait Interval"
          description: "the time to wait between sending each packet"
          type: 'interval'
          unit: 'ms'
          default: 1000
          min: 200
        size:
          title: "Packetsize"
          description: "the number of bytes to be send, keep in mind that 8 bytes
          for the ICMP header are added"
          type: 'byte'
          unit: 'B'
          default: 56
          min: 24
          max: 65507
        timeout:
          title: "Overall Timeout"
          description: "the time in milliseconds the whole test may take before
            stopping and failing it"
          type: 'interval'
          unit: 'ms'
          default: 1000
          min: 500
        warn: object.extend { default: 'quality < 100%' }, @check.warn
        fail: object.extend { default: 'quality is 0' }, @check.fail

    # ### Result values
    #
    # This are possible values which may be given if the check runs normally.
    # You may use any of these in your warn/fail expressions.
    values:
      responsetime:
        title: 'Avg. Response Time'
        description: "average round-trip time of packets"
        type: 'integer'
        unit: 'ms'
      responsemin:
        title: 'Min. Respons Time'
        description: "minimum round-trip time of packets"
        type: 'integer'
        unit: 'ms'
      responsemax:
        title: 'Max. Response Time'
        description: "maximum round-trip time of packets"
        type: 'integer'
        unit: 'ms'
      quality:
        title: 'Quality'
        description: "quality of response (packets succeeded)"
        type: 'percent'

  # ### Create instance
  constructor: (config) -> super config, debug

  # ### Run the check
  run: (cb = ->) ->
    @_start()
    # comand syntax, os dependent
    p = os.platform()
    ping = switch
      when p is 'linux'
        cmd: '/bin/ping'
        args: [
          '-c', @config.count
          '-W', Math.ceil @config.timeout/1000
          '-i', @config.interval/1000
          '-s', @config.size
        ]
      when p.match /^win/
        cmd: 'C:/windows/system32/ping.exe'
        args: [
          '-n', @config.count
          '-w', @config.timeout
          '-l', @config.size
        ]
      when p is 'darwin'
        cmd: '/sbin/ping'
        args: [
          '-c', @config.count
          '-t', Math.ceil @config.timeout/1000
          '-i', @config.interval/1000
          '-s', @config.size
        ]
      else
        throw new Error "Operating system #{p} is not supported in ping."
    ping.args.push @config.host
    # run the ping test
    @result.range = [ new Date ]
    @_spawn ping.cmd, ping.args, null, (err, stdout, stderr, code) =>
      @result.range.push new Date
      return @_end 'fail', err, cb if err
      # parse results
      val = @result.values
      num = 0
      sum = 0
      re = /time=(\d+.?\d*) ms/g
      while match = re.exec stdout
        time = parseFloat match[1]
        num++
        sum += time
        if not val.responsemin? or time < val.responsemin
          val.responsemin = time
        if not val.responsemax? or time > val.responsemax
          val.responsemax = time
      val.responsetime = Math.round(sum/num*10)/10.0
      match = /\s(\d+)% packet loss/.exec stdout
      val.quality = 100-match?[1]
      val.quality = val.quality/100 if val.quality
      # evaluate to check status
      status = @rules()
      message = @config[status] unless status is 'ok'
      @_end status, message, cb

# Export class
# -------------------------------------------------
module.exports = PingSensor

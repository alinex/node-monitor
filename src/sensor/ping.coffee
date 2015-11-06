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
exports.debug = debug = require('debug')('monitor:sensor:ping')
chalk = require 'chalk'
# include alinex modules
async = require 'alinex-async'
Exec = require 'alinex-exec'
{object, string} = require 'alinex-util'
# include classes and helpers
sensor = require '../sensor'

# Schema Definition
# -------------------------------------------------
# This is used as configuration specification and to add the default values for
# specific setting.
#
# It's a n[alinex-validator](http://alinex.githhub.io/node-validator)
# compatible schema definition:
exports.schema =
  title: "Ping test"
  description: "the configuration to make a ping to another server"
  type: 'object'
  default:
    warn: 'quality < 100%'
    fail: 'quality is 0'
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on this to run the command"
      type: 'string'
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
    warn: object.extend {}, sensor.schema.warn,
      default: 'quality < 100%'
    fail: object.extend {}, sensor.schema.fail,
      default: 'quality is 0'

# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Ping'
  description: "Test the reachability of a host in an IP network and measure the
  round-trip time for the messages send."
  category: 'net'
  hint: "Check the network card configuration if local ping won't work or the
  network connection for external pings. Problems can also be that the firewall
  will block the ping port. "

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    responseTime:
      title: 'Avg. Response Time'
      description: "average round-trip time of packets"
      type: 'integer'
      unit: 'ms'
    responseMin:
      title: 'Min. Respons Time'
      description: "minimum round-trip time of packets"
      type: 'integer'
      unit: 'ms'
    responseMax:
      title: 'Max. Response Time'
      description: "maximum round-trip time of packets"
      type: 'integer'
      unit: 'ms'
    quality:
      title: 'Quality'
      description: "quality of response (packets succeeded)"
      type: 'percent'

# Get content specific name
# -------------------------------------------------
exports.name = (config) -> "#{config.remote ? ''}->#{config.host}"

# Run the Sensor
# -------------------------------------------------
exports.run = (config, res, cb = ->) ->
  work =
    sensor: this
    config: config
    result: {}
  sensor.start work
  # run check
  Exec.run
    remote: config.remote
    cmd: '/bin/ping'
    args: [
      '-c', config.count
      '-W', Math.ceil config.timeout/1000
      '-i', config.interval/1000
      '-s', config.size
      config.host
    ]
    priority: 'immediately'
  , (err, proc) ->
    work.err = err
    sensor.end work
    val = work.result.values
    # calculate values
    num = 0
    sum = 0
    re = /time=(\d+.?\d*) ms/g
    while match = re.exec proc.stdout()
      time = parseFloat match[1]
      num++
      sum += time
      if not val.responseMin? or time < val.responseMin
        val.responseMin = time
      if not val.responseMax? or time > val.responseMax
        val.responseMax = time
    val.responseTime = Math.round(sum/num*10)/10.0
    match = /\s(\d+)% packet loss/.exec proc.stdout()
    val.quality = 100-match?[1]
    val.quality = val.quality/100 if val.quality
    sensor.result work
    cb null, work.result

# Run additional analysis
# -------------------------------------------------
exports.analysis = (config, cb = ->) ->
  cb()

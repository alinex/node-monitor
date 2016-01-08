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
# include alinex modules
config = require 'alinex-config'
Exec = require 'alinex-exec'
Report = require 'alinex-report'


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
      description: "the remote server on which to run the command"
      type: 'string'
      values: Object.keys config.get('/exec/remote/server') ? {}
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
    warn:
      title: "Warn if"
      description: "the javascript code to check to set status to warn"
      type: 'string'
      default: 'quality < 100%'
    fail:
      title: "Fail if"
      description: "the javascript code to check to set status to fail"
      type: 'string'
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
      type: 'float'
      unit: 'ms'
    responseMin:
      title: 'Min. Respons Time'
      description: "minimum round-trip time of packets"
      type: 'float'
      unit: 'ms'
    responseMax:
      title: 'Max. Response Time'
      description: "maximum round-trip time of packets"
      type: 'float'
      unit: 'ms'
    quality:
      title: 'Quality'
      description: "quality of response (packets succeeded)"
      type: 'percent'


# Initialize check
# -------------------------------------------------
# This method is used for some precalculations or analyzations and should set:
#
# - check.name = <string> # mandatory
# - check.base = <object> # optionally
exports.init = (cb) ->
  @name ?= "#{@conf.remote ? 'localhost'}->#{@conf.host}"
  cb()


# Run the Sensor
# -------------------------------------------------
exports.run = (cb) ->
  # run check
  Exec.run
    remote: @conf.remote
    cmd: '/bin/ping'
    args: [
      '-c', @conf.count
      '-W', Math.ceil @conf.timeout/1000
      '-i', @conf.interval/1000
      '-s', @conf.size
      @conf.host
    ]
    priority: 'immediately'
  , cb


# Get the results
# -------------------------------------------------
exports.calc = (cb) ->
  return cb() if @err
  res = @result.data
  # calculate values
  num = 0
  sum = 0
  re = /time=(\d+.?\d*) ms/g
  while match = re.exec res.stdout()
    time = parseFloat match[1]
    num++
    sum += time
    if not @values.responseMin? or time < @values.responseMin
      @values.responseMin = time
    if not @values.responseMax? or time > @values.responseMax
      @values.responseMax = time
  @values.responseTime = Math.round(sum/num*10)/10.0
  match = /\s(\d+)% packet loss/.exec res.stdout()
  @values.quality = 100-match?[1]
  @values.quality = @values.quality/100 if @values.quality
  cb()


# Get special report elements
# -------------------------------------------------
exports.report = ->
  report = new Report()
  if data = @result.data
    report.p Report.b "Result:"
    report.code data.stdout(), 'text'
  report

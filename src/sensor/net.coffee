# Network analyzation
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
#
# This methods will be called in the context of the corresponding check()
# instance.
#
# The analysis part currently is based on debian linux.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:net')
# include alinex modules
config = require 'alinex-config'
async = require 'alinex-async'
Exec = require 'alinex-exec'


# Schema Definition
# -------------------------------------------------
# This is used as configuration specification and to add the default values for
# specific setting.
#
# It's a n[alinex-validator](http://alinex.githhub.io/node-validator)
# compatible schema definition:
exports.schema =
  title: "Network Traffic Test"
  description: "the network traffic over a specified interface"
  type: 'object'
  default:
    warn: 'errors > 50%'
    fail: 'errors > 99%'
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on which to run the command"
      type: 'string'
      values: Object.keys config.get '/exec/remote/server'
    interface:
      title: "Interface Name"
      description: "the name of the interface to analyze"
      type: 'string'
      default: 'eth0'
    time:
      title: "Measurement Time"
      description: "the time for the measurement"
      type: 'interval'
      unit: 's'
      default: 10
      min: 1
    warn:
      title: "Warn if"
      description: "the javascript code to check to set status to warn"
      type: 'string'
      default: 'errors > 50%'
    fail:
      title: "Fail if"
      description: "the javascript code to check to set status to fail"
      type: 'string'
      default: 'errors > 99%'


# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Network Traffic'
  description: "Check the network traffic."
  category: 'sys'
  hint: "If you see a high volume it may be overloaded or a attack is
  running."

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    receivedBytes:
      title: "Receive Transfer"
      description: "the number of received bytes of data transmitted or received
      by the interface"
      type: 'byte'
      unit: 'B'
    receivedPackets:
      title: "Received Packets"
      description: "the number of received packets of data transmitted or received
      by the interface"
      type: 'integer'
    receivedErrors:
      title: "Receive Errors"
      description: "the percentage received of transmit or receive errors detected
      by the device driver"
      type: 'percent'
    receivedDrop:
      title: "Received Drops"
      description: "the percentage received of packets dropped by the device driver"
      type: 'percent'
    receivedFifo:
      title: "Received FIFO Errors"
      description: "the percentage received of FIFO buffer errors"
      type: 'percent'
    receivedFrames:
      title: "Received Frame Errors"
      description: "the percentage of receiving packet frame errors"
      type: 'percent'
    transmitBytes:
      title: "Transmit Transfer"
      description: "the number of transmitted bytes of data transmitted or received
      by the interface"
      type: 'byte'
      unit: 'B'
    transmitPackets:
      title: "Transmitted Packets"
      description: "the number of transmitted packets of data transmitted or received
      by the interface"
      type: 'integer'
    transmitErrors:
      title: "Transmit Errors"
      description: "the percentage transmitted of transmit or receive errors detected
      by the device driver"
      type: 'percent'
    transmitDrop:
      title: "Transmitted Drops"
      description: "the percentage transmitted of packets dropped by the device driver"
      type: 'percent'
    transmitFifo:
      title: "Transmit FIFO Errors"
      description: "the percentage transmitted of FIFO buffer errors"
      type: 'percent'
    transmitFrames:
      title: "Transmitted Frames"
      description: "the percentage of transmitting packet frame errors"
      type: 'percent'
    bytes:
      title: "Total Transfer"
      description: "the number of bytes of data transmitted or received by the interface"
      type: 'byte'
      unit: 'B'
    packets:
      title: "Total Packets"
      description: "the number of packets of data transmitted or received by the interface"
      type: 'integer'
    errors:
      title: "Total Errors"
      description: "the percentage of transmit or receive errors detected by the device driver"
      type: 'percent'
    drop:
      title: "Total Drops"
      description: "the percentage of packets dropped by the device driver"
      type: 'percent'
    fifo:
      title: "Total FIFO Errors"
      description: "the percentage of FIFO buffer errors"
      type: 'percent'
    frames:
      title: "Total Frame Errors"
      description: "the percentage of packet framing errors"
      type: 'percent'
    state:
      title: "Interface State"
      description: "the state of the interface this may be UP, DOWN or UNKNOWN"
      type: 'string'
    mac:
      title: "Mac Address"
      description: "the mac address of the network card"
      type: 'string'
    ipv4:
      title: "IP Address"
      description: "the configured ip address"
      type: 'string'
    ipv6:
      title: "IPv6 Address"
      description: "the configured ip version 6 address"
      type: 'string'


# Initialize check
# -------------------------------------------------
# This method is used for some precalculations or analyzations and should set:
#
# - check.name = <string> # mandatory
# - check.base = <object> # optionally
exports.init = (cb) ->
  @name ?= "#{@conf.remote ? 'localhost'}:#{@conf.interface}"
  cb()


# Run the Sensor
# -------------------------------------------------
exports.run = (cb) ->
  # run check
  async.map [
    remote: @conf.remote
    cmd: 'sh'
    args: ['-c', "grep #{@conf.interface} /proc/net/dev"]
    priority: 'immediately'
  ,
    remote: @conf.remote
    cmd: 'sh'
    args: ['-c', "sleep #{@conf.time} && grep #{@conf.interface} /proc/net/dev"]
    priority: 'immediately'
  ,
    remote: @conf.remote
    cmd: 'ip'
    args: ['addr', 'show', @conf.interface]
    priority: 'immediately'
  ], (setup, cb) ->
    Exec.run setup, cb
  , cb


# Get the results
# -------------------------------------------------
exports.calc = (cb) ->
  return cb() if @err
  res = @result.data
  # calculate and store the results
  l1 = res[0].stdout().trim().split /\s+/
  l2 = res[1].stdout().trim().split /\s+/
  diff = (col) -> l2[col] - l1[col]
  percent = (col, max) -> (l2[col] - l1[col]) / max
  @values.receivedBytes = diff 1
  @values.receivedPackets = diff 2
  @values.receivedErrors = percent 3, @values.receivedPackets
  @values.receivedDrop = percent 4, @values.receivedPackets
  @values.receivedFifo = percent 5, @values.receivedPackets
  @values.receivedFrames = percent 6, @values.receivedPackets
  @values.transmitBytes = diff 9
  @values.transmitPackets = diff 10
  @values.transmitErrors = percent 11, @values.transmitPackets
  @values.transmitDrop = percent 12, @values.transmitPackets
  @values.transmitFifo = percent 13, @values.transmitPackets
  @values.transmitFrames = percent 14, @values.transmitPackets
  @values.bytes = @values.receivedBytes + @values.transmitBytes
  @values.packets = @values.receivedPackets + @values.transmitPackets
  percent = (col1, col2, max) -> (l2[col1] - l1[col1] + l2[col2] - l1[col2]) / max
  @values.errors = percent 3, 11, @values.packets
  @values.drop = percent 4, 12, @values.packets
  @values.fifo = percent 5, 13, @values.packets
  @values.frames = percent 6, 14, @values.packets
  # get additional interface settings
  lines = res[2].stdout().split /\n\s*/
  match = /state ([A-Z]+)/.exec lines[0]
  @values.state = match[1]
  match = /(([0-9a-f]{2}:){5}[0-9a-f]{2})/.exec lines[1]
  @values.mac = match[1]
  if lines.length > 1
    for line in lines[2..]
      if match = /^inet ((\d{1,3}.){3}\d{1,3})/.exec line
        @values.ipv4 = match[1]
      else if match = /^inet6 (([0-9a-f]{0,4}:){5}[0-9a-f]{0,4})/.exec line
        @values.ipv6 = match[1]
  cb()

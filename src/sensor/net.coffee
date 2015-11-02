# Network analyzation
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
# But the analysis part currently only works on linux.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:net')
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
  title: "Network Traffic Test"
  description: "the network traffic over a specified interface"
  type: 'object'
  default:
    warn: 'errors > 50%'
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on this to run the command"
      type: 'string'
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
    warn: object.extend {}, sensor.schema.warn,
      default: 'errors > 50%'
    fail: sensor.schema.fail

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
      title: "Received Transfer"
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
      title: "Received Errors"
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
    transmitBytes:
      title: "Transmit Transfer"
      description: "the number of transmitted bytes of data transmitted or received
      by the interface"
      type: 'byte'
      unit: 'B'
    transmitPackets:
      title: "Transmit Packets"
      description: "the number of transmitted packets of data transmitted or received
      by the interface"
      type: 'integer'
    transmitErrors:
      title: "Transmit Errors"
      description: "the percentage transmitted of transmit or receive errors detected
      by the device driver"
      type: 'percent'
    transmitDrop:
      title: "Transmit Drops"
      description: "the percentage transmitted of packets dropped by the device driver"
      type: 'percent'
    transmitFifo:
      title: "Transmit FIFO Errors"
      description: "the percentage transmitted of FIFO buffer errors"
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
    frame:
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

# Run the Sensor
# -------------------------------------------------
exports.run = (name, config, cb = ->) ->
  work =
    sensor: this
    name: name
    config: config
    result: {}
  sensor.start work
  # run check
  async.map [
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "grep #{config.interface} /proc/net/dev"]
    priority: 'immediately'
  ,
    remote: config.remote
    cmd: 'sh'
    args: ['-c', "sleep #{config.time} && grep #{config.interface} /proc/net/dev"]
    priority: 'immediately'
  ,
    remote: config.remote
    cmd: 'ip'
    args: ['addr', 'show', config.interface]
    priority: 'immediately'
  ], (setup, cb) ->
    Exec.run setup, cb
  , (err, proc) ->
    sensor.end work
    # analyse results
    if err
      work.err = err
    else
      val = work.result.values
      # calculate and store the results
      l1 = proc[0].stdout().trim().split /\s+/
      l2 = proc[1].stdout().trim().split /\s+/
      diff = (col) -> l2[col] - l1[col]
      percent = (col) ->
        return 0 unless val.packets
        (l2[col] - l1[col]) / val.packets
      val.receivedBytes = diff 1
      val.receivedPackets = diff 2
      val.receivedErrors = percent 3
      val.receivedDrop = percent 4
      val.receivedFifo = percent 5
      val.receivedFrame = percent 6
      val.transmitBytes = diff 9
      val.transmitPackets = diff 10
      val.transmitErrors = percent 11
      val.transmitDrop = percent 12
      val.transmitFifo = percent 13
      val.transmitFrame = percent 14
      val.bytes = val.receivedBytes + val.transmitBytes
      val.packets = val.receivedPackets + val.transmitPackets
      val.errors = val.receivedErrors + val.transmitErrors
      val.drop = val.receivedDrop + val.transmitDrop
      val.fifo = val.receivedFifo + val.transmitFifo
      val.frame = val.receivedFrame + val.transmitFrame
      # get additional interface settings
      lines = proc[2].stdout().split /\n\s*/
      match = /state ([A-Z]+)/.exec lines[0]
      val.state = match[1]
      match = /(([0-9a-f]{2}:){5}[0-9a-f]{2})/.exec lines[1]
      val.mac = match[1]
      if lines.length > 1
        for line in lines[2..]
          if match = /^inet ((\d{1,3}.){3}\d{1,3})/.exec line
            val.ipv4 = match[1]
          else if match = /^inet6 (([0-9a-f]{0,4}:){5}[0-9a-f]{0,4})/.exec line
            val.ipv6 = match[1]
      sensor.result work
      cb err, work.result

# Run additional analysis
# -------------------------------------------------
exports.analysis = (name, config, cb = ->) ->
  # get additional information
  Exec.run
    remote: config.remote
    cmd: 'netstat'
    args: ['-plnta']
    priority: 'immediately'
  , (err, proc) ->
    return cb err if err
    # 0 Protocol
    # 1 Recv-Q
    # 2 Send-Q
    # 3 Local Address, Port
    # 4 Foreign Address, Port
    # 5 State
    # 6 PID, Program name
    server = ''
    conn = ''
    head = true
    for line in proc.stdout().trim().split /\n/
      cols = line.split /\s+/
      continue if cols[0] isnt 'Proto' and head
      if cols[0] is 'Proto'
        head = false
        continue
      if cols[5] is 'LISTEN'
        split = cols[3].lastIndexOf ':'
        ip = cols[3].substring 0, split
        port = cols[3].substring split+1
        server += "| #{string.rpad cols[0] , 5}
          | #{string.rpad ip, 20}
          | #{string.rpad port, 5} |\n"
      else
        split = cols[4].lastIndexOf ':'
        ip = cols[4].substring 0, split
        port = cols[4].substring split+1
        continue if not cols[6] or cols[6] is '-'
        [pid, cmd] = cols[6].split '/', 2
        conn += "| #{string.rpad cols[0] , 5}
          | #{string.rpad ip, 20}
          | #{string.rpad port, 5}
          | #{string.lpad pid, 6}
          | #{string.rpad (cmd ? ''), 14} |\n"
    report = ''
    if server
      report += """
        Listening servers:

        | PROTO | LOCAL IP             | PORT  |
        | :---- | :------------------- | :---- |
        #{server}\n"""
    if conn
      report += """
        Active internet connections:

        | PROTO | FOREIGN IP           | PORT  |   PID  |     PROGRAM    |
        | :---- | :------------------- | ----: | -----: | :------------- |
        #{conn}\n"""
    cb null, report

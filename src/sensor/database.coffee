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
exports.debug = debug = require('debug')('monitor:sensor:database')
chalk = require 'chalk'
# include alinex modules
async = require 'alinex-async'
Exec = require 'alinex-exec'
{object, string} = require 'alinex-util'
database = require 'alinex-database'
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
  title: "Database Query Test"
  description: "the configuration for a database query check"
  type: 'object'
#  default:
#    warn: 'quality < 100%'
#    fail: 'quality is 0'
  allowedKeys: true
  keys:
    database:
      title: "Database"
      description: "the reference to the database setting in config/database"
      type: 'string'
    query:
      title: "Query"
      description: "the query to run to retrieve the measurement result"
      type: 'string'
    timeout:
      title: "Timeout"
      description: "the time in milliseconds the whole test may take before
        stopping and failing it"
      type: 'interval'
      unit: 'ms'
      default: 10000
      min: 500
    warn: sensor.schema.warn
    fail: sensor.schema.fail
    analysis:
      title: "Additional Analysis"
      description: "the additional query to run if something went wrong"
      type: 'object'
      allowedKeys: true
      keys:
        query:
          title: "Query"
          description: "the query to run to retrieve additional information"
          type: 'string'
        timeout:
          title: "Timeout"
          description: "the time in milliseconds the whole test may take before
            stopping it"
          type: 'interval'
          unit: 'ms'
          default: 20000
          min: 500

# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Database'
  description: "Run a query on the database to chech a value like count of entries
  in the database."
  category: 'data'
#  hint: "Check the network card configuration if local ping won't work or the
#  network connection for external pings. Problems can also be that the firewall
#  will block the ping port. "

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    name:
      title: 'Name'
      description: "the name of the value retrieved"
      type: 'string'
    value:
      title: 'Value'
      description: "the concrete value for the query"
      type: 'float'
    comment:
      title: 'Comment'
      description: "additional information"
      type: 'string'
    responseTime:
      title: 'Response Time'
      description: "time to retrieve the data"
      type: 'integer'
      unit: 'ms'

# Get content specific name
# -------------------------------------------------
exports.name = (config) -> "#{config.database}: #{string.shorten config.query, 30}"

# Run the Sensor
# -------------------------------------------------
exports.run = (config, cb = ->) ->
  work =
    sensor: this
    config: config
    result: {}
  sensor.start work
  # run check
  #database.instance config.database, (err, db) ->
  #  return cb err if err
  #  # get a new connection from the pool
  database.record config.database, config.query, (err, record) ->
    return cb err if err
#    console.log record
    sensor.end work
    val = work.result.values
    # calculate values
    keys = Object.keys record
    val.responseTime = work.result.date[1] - work.result.date[0]
    val.value = record[keys[0]]
    val.name = keys[0]
    val.comment = record[keys[1]]
    sensor.result work
    cb null, work.result

# Run additional analysis
# -------------------------------------------------
exports.analysis = (config, res, cb = ->) ->
  return cb() unless config.analysis?
  database.list config.database, config.analysis.query, (err, list) ->
    return cb err if err
    report = """
    Maybe the following additional results may help:

    | #{Object.keys(list[0]).join ' | '} |\n"""
    for row in list
      values = Object.keys(row).map (e) -> row[e]
      report += "| #{values.join ' | '} |\n"
    cb null, report

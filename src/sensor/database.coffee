# Database test
# =================================================
# This test will not check the availability and performance of a database server
# but check the database contents.

# Find the description of the possible configuration values and the returned
# values in the code below.
#
# This methods will be called in the context of the corresponding check()
# instance.


# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:database')
# include alinex modules
database = require 'alinex-database'
{string} = require 'alinex-util'


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
    name:
      title: "Name of query"
      description: "the descriptive name of a query, for reporting only"
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
    warn:
      title: "Warn if"
      description: "the javascript code to check to set status to warn"
      type: 'string'
      optional: true
    fail:
      title: "Fail if"
      description: "the javascript code to check to set status to fail"
      type: 'string'
      optional: true


# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Database'
  description: "Run a query on the database to chech a value like count of entries
  in the database."
  category: 'data'
#  hint: "Check the ... "

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    data:
      title: 'Data'
      description: "the concrete values from the query"
      type: 'object'
    responseTime:
      title: 'Response Time'
      description: "time to retrieve the data"
      type: 'integer'
      unit: 'ms'


# Initialize check
# -------------------------------------------------
# This method is used for some precalculations or analyzations and should set:
#
# - check.name = <string> # mandatory
# - check.base = <object> # optionally
exports.init = (cb) ->
  @name = "#{@conf.database}:#{@conf.name ? string.shorten @conf.query, 30}"
  cb()


# Run the Sensor
# -------------------------------------------------
exports.run = (cb) ->
  # run check
  database.record @conf.database, @conf.query, cb


# Get the results
# -------------------------------------------------
exports.calc = (res, cb) ->
  return cb() if @err
  # calculate values
  @values.responseTime = @date[1] - @date[0]
  @values.data = res
  cb()

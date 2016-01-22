# Database test
# =================================================
# This test will not check the availability and performance of a database server
# but check the database contents.
#
# This is a relative free sensor in which you can define your own sql but it needs
# a bit more configuration like the mappings to set up.

# Find the description of the possible configuration values and the returned
# values in the code below.
#
# This methods will be called in the context of the corresponding check()
# instance.


# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = require('debug')('monitor:sensor:database')
# include alinex modules
config = require 'alinex-config'
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
  allowedKeys: true
  keys:
    database:
      title: "Database"
      description: "the reference to the database setting in config/database"
      type: 'string'
      values: Object.keys config.get('/database') ? {}
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
    mapping:
      title: "Data Mappings"
      description: "the mapping for the result data to storage values"
      type: 'object'
      entries: [
        title: "Data Mapping"
        description: "the mapping for one result column to a storage value"
        type: 'object'
        mandatoryKeys: ['storage', 'type']
        keys:
          storage:
            title: "Storage Field"
            description: "the storage field to use"
            type: 'string'
            values: [1..8].map((e) -> "num#{e}")
            .concat [1..4].map((e) -> "text#{e}")
            .concat [1..4].map((e) -> "date#{e}")
          title:
            title: "Title"
            description: "the title to use in reports"
            type: 'string'
          description:
            title: "Description"
            description: "a short description"
            type: 'string'
          type:
            title: "Type"
            description: "the data type for formatting"
            type: 'string'
          unit:
            title: "Unit"
            description: "the unit of the stored value for numbers"
            type: 'string'
      ]
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

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    responseTime:
      title: 'Response Time'
      description: "time to retrieve the data"
      type: 'integer'
      unit: 'ms'
for num in [1..8]
  exports.meta.values["num#{num}"] =
    title: "num-#{num}"
    description: "the numeric value ##{num}"
    type: 'float'
  continue if num > 4
  exports.meta.values["text#{num}"] =
    title: "text-#{num}"
    description: "the text value ##{num}"
    type: 'string'
  exports.meta.values["date#{num}"] =
    title: "date-#{num}"
    description: "the date value ##{num}"
    type: 'date'


# Initialize check
# -------------------------------------------------
# This method is used for some pre calculations or analyzations and should set:
#
# - check.name = <string> # mandatory
# - check.base = <object> # optionally
exports.init = (cb) ->
  @name ?= "#{@conf.database}:#{string.shorten @conf.query, 30}"
  for k, v of @conf.mapping
    re = new RegExp "\\b#{k}\\b", 'g'
    if @conf.warn
      @conf.warn = @conf.warn.replace re, v.storage
    if @conf.fail
      @conf.fail = @conf.warn.replace re, v.storage
  cb()


# Access Mappings (for Report)
# -------------------------------------------------
exports.mapping = (name) ->
  return @conf.mapping[name] if @conf.mapping[name]?
  for k, v of @conf.mapping
    return v if v.storage is name


# Run the Sensor
# -------------------------------------------------
exports.run = (cb) ->
  # run check
  database.record @conf.database, @conf.query, cb


# Get the results
# -------------------------------------------------
exports.calc = (cb) ->
  return cb() if @err
  res = @result.data
  # calculate values
  @values.responseTime = @date[1] - @date[0]
  # use mappings to store values
  for k, v of @conf.mapping
    @values[v.storage] = res[k] if res[k]
  cb()

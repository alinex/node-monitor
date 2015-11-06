# Socket test class
# =================================================
# This may be used to check the connection to different ports using TCP.

# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:http')
chalk = require 'chalk'
request = require 'request'
http = require 'http'
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
  title: "Webserver response check"
  description: "the configuration to make an HTTP or HTTPS connection"
  type: 'object'
  allowedKeys: true
  keys:
    remote:
      title: "Remote Server"
      description: "the remote server on this to run the command"
      type: 'string'
    url:
      title: "URL"
      description: "the URL to request"
      type: 'string'
    timeout:
      title: "Timeout"
      description: "the timeout in milliseconds till the process is stopped
        and be considered as failed"
      type: 'interval'
      unit: 'ms'
      min: 500
      default: 10000
    username:
      title: "Username"
      description: "the name used for basic authentication"
      type: 'string'
      optional: true
    password:
      title: "Password"
      description: "the password used for basic authentication"
      type: 'string'
      optional: true
    match:
      title: "Match body"
      description: "the substring or regular expression which have to match"
      type: 'any'
      optional: true
      entries: [
        type: 'string'
        minLength: 1
      ,
        type: 'object'
        instanceOf: RegExp
      ]
    analysis:
      title: "Analysis Run"
      description: "the configuration for the analysis if it is run"
      type: 'object'
      allowedKeys: true
      keys:
        bodyLength:
          title: "Analysis Length"
          description: "the maximum body display length in analysis report"
          type: 'integer'
          min: 1
          default: 256
    warn: sensor.schema.warn
    fail: object.extend {}, sensor.schema.fail,
      default: 'statusCode < 200 or statusCode >= 400'

# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'HTTP Request'
  description: "Connect to an HTTP or HTTPS server and check the response."
  category: 'net'
  hint: "If the server didn't respond it also may be a network problem. "

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    responseTime:
      title: "Response Time"
      description: "time till connection could be established"
      type: 'interval'
      unit: 'ms'
    statusCode:
      title: "Status Code"
      description: "http status code"
      type: 'integer'
    statusMessage:
      title: "Status Message"
      description: "http status message from server"
      type: 'string'
    server:
      title: "Server"
      description: "application name of the server (if given)"
      type: 'string'
    contentType:
      title: "Content Type"
      description: "the content mimetype"
      type: 'string'
    length:
      title: "Content Length"
      description: "size of the content"
      type: 'byte'
    match:
      title: "Body Match"
      description: "success of check for content with containing results"
      type: 'object'

# Get content specific name
# -------------------------------------------------
exports.name = (config) -> "->#{config.url}"

# Run the Sensor
# -------------------------------------------------
exports.run = (config, cb = ->) ->
  work =
    sensor: this
    config: config
    result: {}
  # configure request
  option =
    url: config.url
  option.timeout = config.timeout if config.timeout?
  if config.username? and config.password?
    option.auth =
      username: config.username
      password: config.password
  # start the request
  sensor.start work
  debug "request #{config.url}"
  request option, (err, response, body) ->
    # request finished
    sensor.end work
    # error checking
    if err
      work.err = err
      debug chalk.red err.message
#    console.log 111111111111111, response
#    throw new Error 'xxx'
    if response
      work.result._analysis =
        request:
          headers: response.request?.headers
        response:
          headers: response.headers
          body: response.body
#    console.log 222222222222222222222222222, work.result.analysis
    # get the values
    val = work.result.values
    val.responseTime = work.result.date[1] - work.result.date[0]
    if response?
      val.statusCode = response.statusCode
      val.statusMessage = http.STATUS_CODES[response.statusCode]
      val.server = response.headers.server
      val.contentType = response.headers['content-type']
      val.length = response.connection.bytesRead
      val.match = sensor.match body, config.match
    # evaluate to check status
    sensor.result work
    cb null, work.result

# Run additional analysis
# -------------------------------------------------
exports.analysis = (config, res, cb = ->) ->
  return cb() unless config.analysis
  request = res._analysis.request
  response = res._analysis.response
  # get additional information (top processes)
  report = """
  See the following details of the check which may give you a hint there the
  problem is.

  __GET #{config.url}__\n
  """
  if request?.headers?
    report += '\n'
    for key, value of request.headers
      report += "    #{key}: #{value}\n"
  report += "\nResponse:\n\n"
  if response?.headers?
    for key, value of response.headers
      report += "    #{key}: #{value}\n"
  if response?.body?
    body = response.body
    if body.length > config.analysis.bodyLength
      body = body.substr(0, config.analysis.bodyLength) + '...'
    body = body.replace /\n/g, '\n    '
    report += "\nContent:\n\n"
    report += '    ' + body.replace /\n/g, '\n    '
#    report += string.wordwrap "    #{body}\n", 80, '\n    '
  cb null, report

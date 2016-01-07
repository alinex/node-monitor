# Html request
# =================================================
# This may be used to check the connection to different ports using TCP.

# Find the description of the possible configuration values and the returned
# values in the code below.
#
# This methods will be called in the context of the corresponding check()
# instance.


# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:sensor:http')
request = require 'request'
http = require 'http'
util = require 'util'
# include alinex modules
Exec = require 'alinex-exec'
config = require 'alinex-config'
{string} = require 'alinex-util'
Report = require 'alinex-report'

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
      description: "the remote server on which to run the command"
      type: 'string'
      values: Object.keys config.get '/exec/remote/server'
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
    warn:
      title: "Warn if"
      description: "the javascript code to check to set status to warn"
      type: 'string'
      optional: true
    fail:
      title: "Fail if"
      description: "the javascript code to check to set status to fail"
      type: 'string'
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
      description: "success of check for content with containing result strings"
      type: 'object'


# Initialize check
# -------------------------------------------------
# This method is used for some precalculations or analyzations and should set:
#
# - check.name = <string> # mandatory
# - check.base = <object> # optionally
exports.init = (cb) ->
  @name ?= "->#{string.shorten @conf.url, 30}"
  cb()


# Preset this run
# -------------------------------------------------
exports.prerun = (cb) ->
  # configure request
  option =
    url: @conf.url
    headers:
      'User-Agent': "Alinex Monitor through request.js"
  option.timeout = @conf.timeout if @conf.timeout?
  remote @conf, option, =>
    if @conf.username? and @conf.password?
      option.auth =
        username: @conf.username
        password: @conf.password
    @result.request = option
    cb null, option


# Run the Sensor
# -------------------------------------------------
# The result object will have:
#
# - request - object (from prerun)
# - response - object
# - body - string
exports.run = (cb) ->
  request @result.request, (err, response, body) =>
    @result.response = response
    @result.body = body
    cb err


# Get the results
# -------------------------------------------------
exports.calc = (cb) ->
  return cb() if @err
  @values.responseTime = @date[1] - @date[0]
  return cb() unless @result.response?
  # get the values
  @values.statusCode = @result.response.statusCode
  @values.statusMessage = http.STATUS_CODES[@result.response.statusCode]
  @values.server = @result.response.headers.server
  @values.contentType = @result.response.headers['content-type']
  @values.length = @result.response.connection.bytesRead
  @values.match = @match @result.body, @conf.match
  cb()


# Get special report elements
# -------------------------------------------------
exports.report = ->
  report = new Report()
  if req = @result.request
    report.p Report.b "Request:"
    text = "#{req.method ? 'GET'} #{req.url}"
    if req.headers
      text += "\n\n" + Object.keys(req.headers).map (e) ->
        "#{e}: #{req.headers[e]}"
      .join '\n'
    report.code text, 'text'
  bodyType = 'text'
  if headers = @result.response?.headers
    report.p Report.b "Response:"
    text = Object.keys(headers).map (e) ->
      "#{e}: #{headers[e]}"
    .join '\n'
    report.code text, 'text'
    bodyType = 'html' if ~headers['content-type'].indexOf 'text/html'
  if @result.body?
    report.p Report.b "Body:"
    report.code string.shorten(@result.body, 400), bodyType
  report


# Helper methods
# -------------------------------------------------

# get remote tunnel

remote = (conf, option, cb) ->
  return cb() unless conf.remote
  # open tunnel
  sshtunnel = require 'alinex-sshtunnel'
  sshtunnel
    ssl: config.get "/exec/remote/server/#{conf.remote}"
    tunnel:
      localHost: '127.0.0.1'
  , (err, tunnel) ->
    # use tunnel
    if string.starts url, 'https:'
      option.agentClass = require 'socks5-https-client/lib/Agent'
      option.strictSSL = true
    else
      option.agentClass = require 'socks5-http-client/lib/Agent'
    option.agentOptions =
      socksPort: '7000'
    cb()

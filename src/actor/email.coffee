# Send an email
# =================================================

# Find the description of the possible configuration values and the returned
# values in the code below.
#
# This methods will be called in the context of the corresponding action()
# instance.


# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:actor:email')
chalk = require 'chalk'
nodemailer = require 'nodemailer'
inlineBase64 = require 'nodemailer-plugin-inline-base64'
util = require 'util'
# include alinex modules
{object, array} = require 'alinex-util'
config = require 'alinex-config'
Report = require 'alinex-report'


# Schema Definition
# -------------------------------------------------
# This is used as configuration specification and to add the default values for
# specific setting.
#
# It's an [alinex-validator](http://alinex.githhub.io/node-validator)
# compatible schema definition:
exports.schema =
  title: "Email Configuration"
  description: "the configuration to send an email"
  type: 'object'
  default:
    warn: 'active >= 100%'
  allowedKeys: true
  keys:
    base:
      title: "Base Settings"
      description: "a reference to the base under /monitor/email"
      type: 'string'
      optional: true
    transport:
      title: "Server Setup"
      description: "the transport settings for the server"
      type: 'or'
      or: [
        type: 'string'
      ,
        type: 'object'
      ]
      optional: true
    from:
      title: "Sender's Address"
      description: "the address of the sender"
      type: 'string'
      optional: true
    to:
      title: "Receipient"
      description: "the address to send email to"
      type: 'array'
      toArray: true
      entries:
        type: 'string'
      optional: true
    cc:
      title: "Carbon Copy"
      description: "the carbon copy address to send email to"
      type: 'array'
      toArray: true
      entries:
        type: 'string'
      optional: true
    bcc:
      title: "Blind Carbon Copy"
      description: "the blind carbon copy address to send email to"
      type: 'array'
      toArray: true
      entries:
        type: 'string'
      optional: true
    subject:
      title: "Subject"
      description: "the title of the message, defaults to body title text"
      type: 'or'
      or: [
        type: 'string'
      ,
        type: 'handlebars'
      ]
      optional: true
    text:
      title: "Text Content"
      description: "the plain text content to be send"
      type: 'or'
      or: [
        type: 'string'
      ,
        type: 'handlebars'
      ]
      optional: true
    html:
      title: "HTML Content"
      description: "the html content to be send"
      type: 'or'
      or: [
        type: 'string'
      ,
        type: 'handlebars'
      ]
      optional: true
    report:
      title: "Report"
      description: "the report to send as content (appended to text and html)"
      type: 'object'
      instanceOf: Report
      optional: true
    context:
      title: "Context"
      description: "the context to use for potentional handlebar templates"
      type: 'object'
      optional: true
    priority:
      title: "Priority"
      description: "the importance of the mail set in the header"
      type: 'string'
      values: ['high', 'normal', 'low']
      optional: true


# General information
# -------------------------------------------------
# This information may be used later for display and explanation.
exports.meta =
  title: 'Email'
  description: "Send an @setup."
  hint: "Check the error response and your spam folder if the email won't be
  delivered correctly."

  # ### Result values
  #
  # This are possible values which may be given if the check runs normally.
  # You may use any of these in your warn/fail expressions.
  values:
    accepted:
      title: "Accepted"
      description: "list of accepted email addresses"
      type: 'array'
    rejected:
      title: "Rejected"
      description: "list of rejected email addresses"
      type: 'array'
    message:
      title: "Server Response"
      description: "message from the mail server"
      type: 'string'
    code:
      title: "Code"
      description: "smtp response code"
      type: 'integer'


# Initialization
# -------------------------------------------------
exports.init = (cb) ->
  @name ?= @conf.subject ? '<Unnamed>'
  cb()


# Run the actor
# -------------------------------------------------
exports.run = (cb) ->
  # configure email
  @setup = object.clone @conf.email
  # use base settings
  console.log @setup
  while @setup.base
    base = config.get "/monitor/email/#{@setup.base}"
    delete @setup.base
    @setup = object.extend {}, base, @setup
  # resolve contacts
  resolve = (list) ->
    return null unless list
    list = [list] if typeof list is 'string'
    list = array.unique(list).map (e) ->
      contact = config.get "/monitor/contact/#{e}"
      return e unless contact
      return resolve switch
        when Array.isArray contact then contact
        when contact.email and contact.name
          "\"#{contact.name}\" <#{contact.email}>"
        when contact.email then contact.email
        else null
    return list unless Array.isArray list[0]
    # make a shallow list
    shallow = []
    for e in list
      shallow = shallow.concat e
    array.unique shallow
  # run resolve for all address fields
  for f in ['from', 'to', 'cc', 'bcc']
    @setup[f] = resolve @setup[f]
    delete @setup[f] unless @setup[f]?
  # single address fields
  @setup[f] = @setup[f]?[0] for f in ['from']
  mails = @setup.to?.map (e) -> e.replace /".*?" <(.*?)>/g, '$1'
  debug "sending email to #{mails?.join ', '}..."
  # support handlebars
  @setup.subject = @setup.subject @controller if typeof @setup.subject is 'function'
  @setup.text = @setup.text @controller if typeof @setup.text is 'function'
  @setup.html = @setup.html @controller if typeof @setup.html is 'function'
  if @setup.body
    report = new Report
      source: @setup.body @controller if typeof @setup.body is 'function'
    @setup.text ?= report.toText()
    @setup.html ?= report.toHtml()
    delete @setup.body
  else if @controller.report
    @setup.text ?= @controller.report.toText()
    @setup.html ?= @controller.report.toHtml()
  if @setup.html
    @setup.subject ?= @setup.html.match(/<title>([\s\S]*?)<\/title>/)[1]
#  console.log @setup
  # setup transporter
  transporter = nodemailer.createTransport @setup.transport ? 'direct:?name=hostname'
  transporter.use 'compile', inlineBase64
  debug chalk.grey "using #{transporter.transporter.name}"
  # try to send email
  transporter.sendMail @setup, (err, info) =>
    if err
      if err.errors
        debug chalk.red e.message for e in err.errors
      else
        debug chalk.red err.message
      debug chalk.grey "send through " + util.inspect @setup.transport
    if info
      debug "message send to"
      debug chalk.grey util.inspect(info).replace /\s+/, ''
      for e in ['accepted', 'rejected']
        @values[e] = info[e] if info[e]?.length
      @values.message = info.response
      code = info.response?.match(/\d+/)?[0]
      @values.code = Number code if code
      debug chalk.grey util.inspect(@values).replace /\s+/g, ' '
      return cb new Error "Some messages were rejected: #{info.response}" if info.rejected?.length
    cb err?.errors?[0] ? err ? null

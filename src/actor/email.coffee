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
      title: ""
      description: ""
      type: 'or'
      or: [
        type: 'string'
      ,
        type: 'handlebars'
      ]
      optional: true
    html:
      title: ""
      description: ""
      type: 'or'
      or: [
        type: 'string'
      ,
        type: 'handlebars'
      ]
      optional: true
    report:
      title: ""
      description: ""
      type: 'object'
      instanceOf: Report
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
    cpus:
      title: "CPU Cores"
      description: "number of cpu cores"
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
  while @setup.base
    base = config.get "/monitor/email/#{@setup.base}"
    delete @setup.base
    @setup = object.extend base, @setup
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
  @setup[f] = @setup[f][0] for f in ['from']
  mails = @setup.to?.map (e) -> e.replace /".*?" <(.*?)>/g, '$1'
  debug "sending email to #{mails?.join ', '}..."
  # setup transporter
  transporter = nodemailer.createTransport @setup.transport ? 'direct:?name=hostname'
  transporter.use 'compile', inlineBase64
  debug chalk.grey "using #{transporter.transporter.name}"
  if @setup.report
    @setup.text = @setup.report.toText()
    @setup.html = @setup.report.toHtml()
    @setup.subject ?= @setup.html.match(/<title>([\s\S]*?)<\/title>/)[1]
    delete @setup.report
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
      # TODO @values = accepted, rejected, response
    cb err?.errors?[0] ? err ? null

# priority
# report
# html

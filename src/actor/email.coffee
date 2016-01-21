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
# include alinex modules
{object, array} = require 'alinex-util'
config = require 'alinex-config'

util = require 'util'

# General setup
# -------------------------------------------------
# will setup on init
#transporter = null


# Initialization
# -------------------------------------------------
#exports.init = (cb) ->
#  debug "init email actor"
#
#  transporter = nodemailer.createTransport 'smtp://alexander.schilling%40divibib.com:12errors@\
#    mail.divibib.com'
#  return cb()
#
#  # create new mail transport
#  if setup = config.get '/monitor/email/transport'
#
#    setup.debug = true
#    setup.logger = true
#    if setup.type is 'smtp'
#      smtpTransport = require 'nodemailer-smtp-transport'
#      transporter = nodemailer.createTransport smtpTransport setup
#    else
#      transporter = null
#  else
#    transporter = nodemailer.createTransport()
#  cb()


# Run the actor
# -------------------------------------------------
exports.run = (setup, data, cb) ->
  # configure email
  email = object.clone setup
  # use base settings
  while email.base
    base = config.get "/monitor/email/#{email.base}"
    delete email.base
    email = object.extend base, email
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
    email[f] = resolve email[f]
    delete email[f] unless email[f]?
  # single address fields
  email[f] = email[f][0] for f in ['from']
  console.log email
  debug "sending email to #{email.to?.join ', '}..."
  # setup transporter
  transporter = nodemailer.createTransport setup.transport ? 'direct:?name=hostname'
  transporter.use 'compile', inlineBase64
  delete email.transport if email.transport?
  if email.report
    email.text = email.report.toText()
    email.html = email.report.toHtml()
    email.subject ?= email.html.match(/<title>([\s\S]*?)<\/title>/)[1]
    delete email.report
  # try to send email
  ################################################################################
  # PREVENT EMAIL sending
  ################################################################################
  return cb()
  transporter.sendMail email, (err, info) ->
    if err
      if err.errors
        debug chalk.red e.message for e in err.errors
      else
        debug chalk.red err.message
    if info
      debug "message send to"
      debug chalk.grey util.inspect(info).replace /\s+/, ''
    cb err?.errors?[0] ? err ? null

# priority
# report
# html

# Send an email
# =================================================


# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:actor:email')
chalk = require 'chalk'
nodemailer = require 'nodemailer'
inlineBase64 = require 'nodemailer-plugin-inline-base64'
# include alinex modules
config = require 'alinex-config'
{string} = require 'alinex-util'

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
exports.run = (setup, cb) ->
  debug "sending email to..."
  # setup transporter
  transporter = nodemailer.createTransport setup.transport ? 'direct:?name=hostname'
  transporter.use 'compile', inlineBase64
  # configure email
  email = object.clone setup
  delete email.transport if email.transport?
  for f in ['to', 'cc', 'bcc']
    email[f] = email[f].join ', ' if Array.isArray email[f]
  if email.report
    email.text = report.toText()
    email.html = report.toHtml()
    email.subject ?= email.html.match(/<title>([\s\S]*?)</title>/)[1]
    delete email.report
  # try to send email
  transporter.sendMail
    email
  , (err, info) ->
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

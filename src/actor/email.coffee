# Send an email
# =================================================


# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:actor:email')
chalk = require 'chalk'
nodemailer = require 'nodemailer'
# include alinex modules
config = require 'alinex-config'
{string} = require 'alinex-util'

util = require 'util'

# General setup
# -------------------------------------------------
# will setup on init
transporter = null


# Initialization
# -------------------------------------------------
exports.init = (cb) ->
  debug "init email actor"

  transporter = nodemailer.createTransport 'smtp://alexander.schilling%40divibib.com:12errors@\
    mail.divibib.com'
  return cb()

  # create new mail transport
  if setup = config.get '/monitor/email/transport'

    setup.debug = true
    setup.logger = true
    if setup.type is 'smtp'
      smtpTransport = require 'nodemailer-smtp-transport'
      transporter = nodemailer.createTransport smtpTransport setup
    else
      transporter = null
  else
    transporter = nodemailer.createTransport()
  cb()


# Run the actor
# -------------------------------------------------
exports.run = (cb) ->
  debug "sending email to..."
#  transporter = nodemailer.createTransport ''
  transporter.sendMail
    from: 'alexander.schilling@divibib.com'
    to: 'alexander.schilling@divibib.com'
    # cc
    # bcc
    # replyTo
    subject: 'Testmail from Alinex Monitor'
    text: 'Hello World'
  , (err, info) ->
    if err
      if err.errors
        debug chalk.red e.message for e in err.errors
      else
        debug chalk.red err.message
    if info
      debug info
    cb err?.errors?[0] ? err ? null

# priority
# report
# html

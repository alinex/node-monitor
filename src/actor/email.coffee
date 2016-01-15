# Send an email
# =================================================


# Node Modules
# -------------------------------------------------

# include base modules
exports.debug = debug = require('debug')('monitor:actor:email')
chalk = require 'chalk'
nodemailer = require 'nodemailer'
smtpTransport = require 'nodemailer-smtp-transport'
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
  # create new mail transport
  transporter = if setup = config.get '/monitor/email/transport'
    nodemailer.createTransport smtpTransport setup
  else
    nodemailer.createTransport()
  cb()


# Run the actor
# -------------------------------------------------
exports.run = (cb) ->
  debug "sending email to..."
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
      debug chalk.red e.message for e in err.errors
    cb err.errors[0]

# priority
# report
# html

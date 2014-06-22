# EMain class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
fs = require 'fs'
ping = require 'net-ping'

# Controller class
# -------------------------------------------------

controller =
  list: {}
  create: (config) ->
    obj = new Ping config
    list[obj.id] = obj
    obj

class BaseController
  constructor: (@config) ->
  id: -> this.toString()
  check: (cb) ->
    cb new Error "check method not implemented in #{this}"
  title: ->
  message: (data) ->


class Ping extends BaseController
  check: (cb) ->
    session = ping.createSession()
    session.pingHost @config.ip, (err, target) ->
    if err
      if err instanceof ping.RequestTimedOutError
        console.log target + ": Not alive"
      else
        console.log target + ": " + error.toString()
    else
      console.log target + ": Alive"
    cb 'OK', 'data'

# Main
# ------------------------------------------------

config = readConfig()
# create controller objects
controller = []
for entry in config.controller
  controller.push Controller.create entry

# Checkall
# ------------------------------------------------
for obj in controller
  obj.check (status, data) ->
  console.log obj.title() + ': ' + status

# Collector
# ------------------------------------------------

# Dependency usage
# ------------------------------------------------


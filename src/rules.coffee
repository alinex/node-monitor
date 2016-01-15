# Run controller rules
# =================================================
# This will be called within the controller context.


# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:rule')
chalk = require 'chalk'
moment = require 'moment'
# include alinex modules
{object, string} = require 'alinex-util'
config = require 'alinex-config'
# include classes and helpers


# Configuration
# -------------------------------------------------
HISTORY_LENGTH = 5


# Initialized Data
# -------------------------------------------------
# This will be set on init
monitor = null  # require './index'


# Initialize rule data
# -------------------------------------------------
exports.init = ->
  monitor ?= require './index'
  @ruledata =
    count: 0
    date: new Date()
    action: {}


# Run rules
# -------------------------------------------------
exports.run = ->
  if @changed
    @ruledata =
      count: 0
      date: @date
      action: {}
  @ruledata.count++
  rules = config.get '/monitor/rule'
  for name in @conf.rule
    # check that rule is defined
    continue unless rule = rules[name]
    # only work on specific status
    continue unless rule.status is @status
    # number of minimum attempts (controller runs) before informing.
    continue if rule.attempt and @ruledata.count < rule.attempt
    # time (in seconds) to wait before informing.
    if rule.latency
      continue if new Date() < moment(@ruledata.date).add(rule.latency, 'seconds').toDate()
    # if already done and not in redo time
    if @ruledata.action[name]?
      # Timeout (in seconds) without status change before informing again.
      if rule.redo
        continue if new Date() < moment(@ruledata.action[name]).add(rule.redo, 'seconds').toDate()
    # if ok, not changed and action is empty
# ###############################################################################################
# ###### disabled for testing only ##############################################################
#      continue if not @changed and @status is 'ok' and Object.keys(@ruledata.action).length is 0
    # run rules
    @ruledata.action[name] = new Date()
    actors[type]? name, rule for type of actors


# Run specific actor for rule
# -------------------------------------------------
actors =
  email: (name, rule) ->
    console.log '==> email =>', name, rule
    # call actor with all data


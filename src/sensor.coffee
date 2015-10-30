# Helper for the sensor modules
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
chalk = require 'chalk'
vm = require 'vm'
math = require 'mathjs'
util = require 'util'
# include alinex modules
# include classes and helpers


# Validation rules
# -------------------------------------------------
#
# They are used in the concrete classes to add some common used checks to the
# individual rules.
exports.schema =
  fail:
    title: "Fail if"
    description: "the javascript code to check to set status to fail"
    type: 'string'
    optional: true
  warn:
    title: "Warn if"
    description: "the javascript code to check to set status to warn"
    type: 'string'
    optional: true

# Start a new Run
# -------------------------------------------------
exports.start = (work) ->
  work.sensor.debug "#{chalk.grey work.name} start check"
  work.result.date = [new Date()]
  work.result.status = 'running'
  work.result.values = {}

# End a Run
# -------------------------------------------------
exports.end = (work) ->
  work.sensor.debug "#{chalk.grey work.name} ended check"
  work.result.date[1] = new Date()

# Analysis
# -------------------------------------------------
exports.result = (work) ->
  result work
  work.sensor.debug "#{chalk.grey work.name} result status: #{work.result.status}"
  for n, v of work.result.values
    work.sensor.debug "#{chalk.grey work.name} result #{n}: #{v}"

result = (work) ->
  if work.err
    return work.result.status = 'fail'
  unless Object.keys work.result
    return work.result.status = 'fail'
#    meta = work.sensor.meta
  for status in ['fail', 'warn']
    continue unless work.config[status]
    rule = work.config[status]
    work.sensor.debug chalk.grey "#{work.name} check #{status} rule: #{rule}"
    # replace data values
    for name, value of work.result.values
      if Array.isArray value
        for i, val in value
          re = new RegExp "\\b#{name}\\[#{i}\\]\\b", 'g'
          rule = rule.replace re, (str, name) ->
            "'#{value[i]?.toString()}'"
        re = new RegExp "\\b#{name}\\b", 'g'
        rule = rule.replace re, (str, name) ->
          "'#{value.toString()}'"
      else if typeof value is 'object'
        for i, val of value
          re = new RegExp "\\b#{name}\\.#{i}\\b", 'g'
          rule = rule.replace re, (str, name) ->
            "'#{value[i]?.toString()}'"
        re = new RegExp "\\b#{name}\\b", 'g'
        rule = rule.replace re, (str, name) ->
          "'#{value.toString()}'"
      else
        re = new RegExp "\\b#{name}\\b", 'g'
        rule = rule.replace re, (str, name) ->
          value
    # replace not existing data values
    if meta?.values?
      for name of meta.values
        re = new RegExp "\\b#{name}(\\.\\w+|\\[\\d+\\])?\\b", 'g'
        rule = rule.replace re, 'null'
    # replace percent values
    rule = rule.replace /\b(\d+(\.\d+)?)%/g, (str, value) ->
      value / 100
    # replace binary values
    rule = rule.replace /\b(\d+(\.\d+)?)([kMGTPEYZ]?B)/g, (str) ->
      math.unit(str).toNumber('B')
    # replace interval values
    rule = rule.replace /\b(\d+(\.\d+)?)(ms|s|m|h|d)/g, (str) ->
      number.parseMSeconds str
    # replace operators
    for name, value of {and: '&&', or: '||', is: '==', isnt: '!=', not: '!'}
      re = new RegExp "\\b#{name}\\b", 'g'
      rule = rule.replace re, value
    work.sensor.debug chalk.grey "#{work.name} optimized: #{rule}"
    # run the code in sandbox
    sandbox = {}
    vm.runInNewContext "result = #{rule}", sandbox, {filename: 'monitor-sensor-rule.vm'}
    work.sensor.debug chalk.grey "#{work.name} rule result: #{status} = #{sandbox.result}"
    if sandbox.result
      return work.result.status = status
  work.result.status = 'ok'

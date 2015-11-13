# Helper for the sensor modules
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
chalk = require 'chalk'
vm = require 'vm'
math = require 'mathjs'
util = require 'util'
named = require('named-regexp').named
# include alinex modules
{string} = require 'alinex-util'
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
  work.sensor.debug "#{chalk.grey work.sensor.name work.config} start check"
  work.result.date = [new Date()]
  work.result.status = 'running'
  work.result.values = {}

# End a Run
# -------------------------------------------------
exports.end = (work) ->
  work.sensor.debug "#{chalk.grey work.sensor.name work.config} ended check"
  work.result.date[1] = new Date()

# Analysis
# -------------------------------------------------
exports.result = (work) ->
  result work
  work.sensor.debug "#{chalk.grey work.sensor.name work.config} result status:
  #{work.result.status}#{if work.result.message then ' (' + work.result.message + ')' else ''}"
  for n, v of work.result.values
    work.sensor.debug "#{chalk.grey work.sensor.name work.config} result #{n}: #{v}"

result = (work) ->
  if work.err
    work.result.message ?= work.err.message
    return work.result.status = 'fail'
  unless Object.keys work.result
    work.result.message ?= 'no data'
    return work.result.status = 'fail'
#    meta = work.sensor.meta
  for status in ['fail', 'warn']
    continue unless work.config[status]
    rule = work.config[status]
    work.sensor.debug chalk.grey "#{work.sensor.name work.config} check #{status} rule: #{rule}"
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
    work.sensor.debug chalk.grey "#{work.sensor.name work.config} optimized: #{rule}"
    # run the code in sandbox
    sandbox = {}
    vm.runInNewContext "result = #{rule}", sandbox, {filename: 'monitor-sensor-rule.vm'}
    work.sensor.debug chalk.grey "#{work.sensor.name work.config} rule result:
    #{status} = #{sandbox.result}"
    if sandbox.result
      work.result.message = work.config[status]
      return work.result.status = status
  work.result.status = 'ok'

exports.report = (work) ->
  meta = work.sensor.meta
  name = work.sensor.name work.config
  name = "(#{name})" if name
  report = """\n#{meta.title} #{name}
  ------------------------------------------------------------------------------\n
  """
  report += """\n#{string.wordwrap meta.description, 78}

  Last check results from #{work.result.date[0]} are:

  |          LABEL          |                     VALUE                        |
  | ----------------------- | -----------------------------------------------: |\n
  """
  # table of values
  for name, set of meta.values
    val = ''
    if work.result.values[name]?
      val = formatValue work.result.values[name], set
    if typeof val is 'object'
      for n, v of val
        report += "| #{string.rpad (set.title + ': ' + n), 23}
        | #{string.lpad v.toString(), 48} |\n"
    else
      report += "| #{string.rpad set.title, 23} | #{string.lpad val.toString(), 48} |\n"
  if work.sensor.meta.hint
    report += "\n> #{string.wordwrap work.sensor.meta.hint, 76, '\n> '}\n"
  found = false
  for name, set of work.sensor.schema.keys
    continue if name is 'analysis'
    continue unless work.config[name]?
    unless found
      found = true
      report += """\nThis has been checked with the following setup:

      |       CONFIG       |  VALUE                                                |
      | ------------------ | ----------------------------------------------------: |\n
      """
    val = formatValue work.config[name], set
    if name in ['fail', 'warn']
      # replace values
      for vname, value of work.result.values
        re = new RegExp "\\b#{vname}\\b", 'g'
        val = val.replace re, (str) ->
          meta.values[vname]?.title ? vname
    report += "| #{string.rpad set.title, 18}
    | #{string.lpad val.toString(), 53} |\n"
  report += "\n#{work.result.analysis}\n" if work.result.analysis
  report #  string.wordwrap report

# ### Format a value for better human readable display
formatValue = (value, config) ->
  # format with autodetect
  unless config
    return switch
      when typeof value is 'number'
        parts = (Math.round(value * 100) / 100).toString().split '.'
        parts[0] = parts[0].replace /\B(?=(\d{3})+(?!\d))/g, ","
        parts.join '.'
      else
        value
  # format using config setting
  switch config.type
    when 'percent'
      Math.round(value * 100).toString() + ' %'
    when 'byte'
      byte = math.unit value, 'B'
      byte.format 3
    when 'interval'
      long =
        d: 'day'
        m: 'minute'
      unit = long[config.unit] ? config.unit
      interval = math.unit value, unit
      interval = interval.to 'm' if interval.toNumber('s') > 120
      interval.format()
    when 'float'
      parts = (Math.round(value * 100) / 100).toString().split '.'
      parts[0] = parts[0].replace /\B(?=(\d{3})+(?!\d))/g, ","
      parts.join '.'
    else
      val = value
      val += " #{config.unit}" if val and config.unit
      val

# ### Convert object to markdown table
formatTable = (obj) ->
  result = ''
  unless Array.isArray obj
    # single object
    keys = Object.keys obj
    # get length of heading
    maxlen = []
    for n in keys
      maxlen[0] = n.length if maxlen[0] < n.length
      maxlen[1] = obj[n].length if maxlen[1] < obj[n].length
    # create table
    result = "| #{string.rpad 'Name', maxlen[0]} | #{string.lpad 'Value', maxlen[1]} |\n"
    result = "| #{string.repeat '-', maxlen[0]} | #{string.repeat '-', maxlen[1]} |\n"
    for n, v in obj
    result = "| #{string.rpad n, maxlen[0]} | #{string.lpad formatValue(v), maxlen[1]} |\n"
  else if obj.length
    # List of objects
    keys = Object.keys obj[0]
    # get length of heading
    maxlen = {}
    for n in keys
      maxlen[n] = n.length
    for e in obj
      for n in keys
        maxlen[n] = obj[e][n].length if maxlen[n] < obj[e][n].length
    # create table
    row = keys.map (n) ->
      string.lpad n, maxlen[n]
    result = "| #{row.join ' | '} |\n"
    row = keys.map (n) ->
      string.repeat '-', maxlen[n]
    result = "| #{row.join ' | '} |\n"
    for e in obj
      row = keys.map (n) ->
        string.lpad formatValue(e[n]), maxlen[n]
      result = "| #{row.join ' | '} |\n"
  # return result
  result

# ### Check expression against string
#
# It will will try to match the given expression once and return the matched
# groups or false if not matched. The groups are a array with the full match as
# first element or in case of named regexp an object with key 'match' containing
# the full match.
exports.match = (text, re) ->
  return false unless re?
  unless re instanceof RegExp
    return if Boolean ~text.indexOf re then [re] else false
  # it's an regular expression
  useNamed = ~re.toString().indexOf '(:<'
  re = named re if useNamed
  return false unless match = re.exec text
  if useNamed
    matches = {}
    matches[name] = match.capture name for name of match.captures
  else
    matches = match[0..match.length]
  return matches

# Base sensor
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
chalk = require 'chalk'
{spawn} = require 'child_process'
util = require 'util'
math = require 'mathjs'
vm = require 'vm'
named = require('named-regexp').named
# include other alinex modules
object = require('alinex-util').object
string = require('alinex-util').string
number = require('alinex-util').number

# Sensor class
# -------------------------------------------------
# This class contains all the basics for each sensor.
class Sensor

  # ### Validation rules
  #
  # They are used in the concrete classes to add some common used checks to the
  # individual rules.
  @check =
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
    verbose:
      title: "Always Verbose"
      description: "a flag to always get the analysis details else only in
      warning or fail state"
      type: 'boolean'
      default: false
      optional: true

  # ### Create instance
  #
  # Instance properties:
  #
  # - config (object) - configuration setting
  # - debug (function)
  # - result (object) - resulting data
  constructor: (@config, @debug) ->
    unless @debug
      @debug = require('debug')('monitor:sensor')
    unless @config
      throw new Error "Could not initialize sensor without configuration."

  # ### Protocol new start
  _start: ->
    @debug 'start check'
    @result =
      date: new Date
      status: 'running'
      values: {}

  # ### Protocol end of sensor run
  _end: (status, message, cb) ->
    return if cbCalled
    cbCalled = true
    # store overall status
    @result.status = status
    @result.message = message if message
    # report results
    out = {}
    for key, val of @config
      out[key] = val if val?
    @debug 'used config', chalk.grey util.inspect(out).replace(/\s+/g, ' ')
    @debug 'result values', chalk.grey util.inspect(@result.values).replace(/\s+/g, ' ')
    # return
    cb null, @

  # ### Helper to work with local commands
  _spawn: (cmd, args = [], options = {}, cb) ->
    # create new subprocess
    @debug "exec> #{cmd} #{args.join ' '}"
    proc = spawn cmd, args, options
    # collect output
    stdout = stderr = ''
    proc.stdout.setEncoding "utf8"
    proc.stdout.on 'data', (data) =>
      stdout += (text = data.toString())
      for line in text.trim().split /\n/
        @debug chalk.grey line
    proc.stderr.setEncoding "utf8"
    proc.stderr.on 'data', (data) =>
      stderr += (text = data.toString())
      for line in text.trim().split /\n/
        @debug chalk.magenta line
    # error management
    error = null
    proc.on 'error', (err) =>
      @debug chalk.red err.toString()
      error = err
    # process finished
    proc.on 'close', (code) =>
      # get the success for the command
      @result.values.success = code is 0
      cb error, stdout, stderr, code

  # ### Check expression against string
  #
  # It will will try to match the given expression once and return the matched
  # groups or false if not matched. The groups are a array with the full match as
  # first element or in case of named regexp an object with key 'match' containing
  # the full match.
  match: (text, re) ->
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

  # ### Check the rules and return status
  rules: ->
    return 'fail' unless @result
    meta = @constructor.meta
    for status in ['fail', 'warn']
      continue unless @config[status]
      rule = @config[status]
      @debug "check rule: #{rule}"
      # replace data values
      for name, value of @result.values
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
      for name, value of { and: '&&', or: '||', is: '==', isnt: '!=', not: '!' }
        re = new RegExp "\\b#{name}\\b", 'g'
        rule = rule.replace re, value
      @debug "optimized: #{rule}"
      # run the code in sandbox
      sandbox = {}
      vm.runInNewContext "result = #{rule}", sandbox, 'monitor-sensor-rule.vm'
      @debug "result: #{sandbox.result}"
      return status if sandbox.result
    return 'ok'

  # ### Format last result
  format: ->
    meta = @constructor.meta
    text = """
      #{meta.description}\n\nLast check results are:

      |       RESULT       |  VALUE                                                |
      | ------------------ | ----------------------------------------------------: |\n"""
    # table of values
    for name, set of meta.values
      val = ''
      if @result.values[name]?
        val = formatValue @result.values[name], set
      text += "| #{string.rpad set.title, 18}
      | #{string.lpad val.toString(), 53} |\n"
    # configuration settings
    text += """
      \nAnd the following configuration was used:

      |       CONFIG       |  VALUE                                                |
      | ------------------ | ----------------------------------------------------: |\n"""
    for name, set of meta.config.entries
      continue unless @config[name]?
      val = formatValue @config[name], set
      if name in ['fail', 'warn']
        # replace values
        for vname, value of @result.values
          re = new RegExp "\\b#{vname}\\b", 'g'
          val = val.replace re, (str) ->
            meta.values[vname]?.title ? vname
      text += "| #{string.rpad set.title, 18}
      | #{string.lpad val.toString(), 53} |\n"
    # hint
    text += "\n#{meta.hint}\n" if meta.hint
    # additional information
    text += "\n#{@result.analysis}" if @result.analysis?
    text

# ### Format a value for better human readable display
formatValue = (value, config) ->
  switch config.type
    when 'percent'
      (Math.round(value * 100) / 100).toString() + ' %'
    when 'byte'
      byte = math.unit value, 'B'
      byte.format 3
    when 'interval'
      long =
        d: 'day'
        m: 'minute'
      unit = long[config.unit] ? config.unit
      interval = math.unit value, unit
      interval.format 3
    else
      val = value
      val += " #{config.unit}" if val and config.unit
      val

# Export class
# -------------------------------------------------
module.exports = Sensor

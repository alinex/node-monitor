# Ping test class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
os = require 'os'
{spawn} = require 'child_process'
debug = require('debug')('monitor:ping')
colors = require 'colors'
EventEmitter = require('events').EventEmitter

object = require('alinex-util').object
Sensor = require './base'

# Sensor class
# -------------------------------------------------
class PingSensor extends Sensor

  # ### Default Configuration
  @config:
    ip: null # given by call
    count: 1
    timeout: 1

  # ### Create instance
  constructor: (config) ->
    super object.extend PingSensor.config, config
    unless config
      throw new Error "Could not initialize sensor without configuration."

  type: 'Ping'

  run: (cb = ->) ->
    # comand syntax, os dependent
    p = os.platform()
    ping = switch
      when p is 'linux'
        cmd: '/bin/ping'
        args: ['-c', @config.count, '-w', @config.timeout]
      when p.match /^win/
        cmd: 'C:/windows/system32/ping.exe'
        args: ['-n', @config.count, '-w', @config.timeout*1000]
      when p is 'darwin'
        cmd: '/sbin/ping'
        args: ['-c', @config.count, '-t', @config.timeout]
      else
        throw new Error "Operating system #{p} is not supported in ping."
    ping.args.push @config.ip
    # run the ping test
    @_start "Ping #{@config.ip}..."
    @result.data = ''
    debug "exec> #{ping.cmd} #{ping.args.join ' '}"
    proc = spawn ping.cmd, ping.args
    proc.stdout.on 'data', (data) =>
      for line in data.toString().trim().split /\n/
        @result.data += line + "\n" if ~line.indexOf "%"
        debug line[if ~line.indexOf "%" then 'yellow' else 'grey'] if line
    proc.stderr.on 'data', (data) ->
      for line in data.toString().trim().split /\n/
        @result.data += "Error: #{line}\n"
        debug line.magenta
    # Error management
    proc.on 'error', (err) ->
      @_end 'fail', err
      cb err
    proc.on 'exit', (status) =>
      if status != 0
        message = "#{@type} exited with code #{status}"
        @_end 'fail', message
        return cb new Error message
      # correct internal links
      @_end 'ok'
      cb()

# Export class
# -------------------------------------------------
module.exports = PingSensor

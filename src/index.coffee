# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
async = require 'async'
Config = require 'alinex-config'

# include classes
Controller = require './controller'


# do parallel config loading
async.parallel
  # read monitor config
  config: (cb) ->
    new Config 'monitor', cb
  # get controller
  controller: (cb) ->
    # find controller configs in folder
    Config.find 'controller', (err, list) ->
      return cb err if err
      async.map list, (name, cb) ->
        # add controller check
        Config.addCheck name, Controller.check, (err) ->
          return cb err if err
          # read in configuration
          new Config name, (err, config) ->
            return cb err if err
            # return new controller instance
            cb null, new Controller config
      , (err, results) ->
        cb null, results
, (err, {config,controller}) ->
  throw err if err
  console.log config
  console.log controller


# init controller

# run controller once




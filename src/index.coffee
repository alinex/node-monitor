# Main class
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
async = require 'async'
Config = require 'alinex-config'



# do parallel config loading
async.parallel
  # read monitor config
  config: (cb) ->
    new Config 'monitor', (err, config) ->
#      console.log config
      cb err, config
  # get controller
  controller: (cb) ->
    # find controller configs in folder
    Config.find 'controller', (err, list) ->
      return cb err if err
      console.log "Found: #{list}"
      ###
      new Config name, (err, config) ->
        throw err if err
        # instantiate them
        controller[path.basename name] = new Controller config
    , ->
      console.log controller
      ###
      cb null, list
, (err, {config,controller}) ->
  throw err if err
  console.log end-start


# init controller

# run controller once




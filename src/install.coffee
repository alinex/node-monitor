# Installation
# =================================================

# Node Modules
# -------------------------------------------------

fs = require 'alinex-fs'
path = require 'path'
{execSync} = require 'child_process'
chalk = require 'chalk'

# Setup configuration directory
# -------------------------------------------------
etc = '/etc/alinex-monitor'
local = path.resolve "#{__dirname}/../var/local"
unless fs.existsSync local
  try
    unless fs.existsSync etc
      console.log "Create configuration directory"
      fs.mkdirsSync etc
    console.log "Creating softlink to #{etc} for configuration..."
    execSync "ln -s #{etc} #{local}"
  catch err
    console.log chalk.magenta "No rights to move configuration to #{etc}."
    etc = local
console.log chalk.bold.yellow "Configure under #{etc}."


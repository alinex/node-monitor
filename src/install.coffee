# Installation
# =================================================

# Node Modules
# -------------------------------------------------

fs = require 'alinex-fs'
path = require 'path'
{execSync} = require 'child_process'
chalk = require 'chalk'


# Output logo
# -------------------------------------------------
stream = process.stdout
logo = """
                           __   ____     __           
           ######  #####  |  | |    \\   |  |   ########### #####       ##### 
          ######## #####  |  | |     \\  |  |  ############  #####     ##### 
         ######### #####  |  | |  |\\  \\ |  |  #####          #####   ##### 
        ########## #####  |  | |  | \\  \\|  |  #####           ##### ##### 
       ##### ##### #####  |  | |  |__\\     |  ############     ######### 
      #####  ##### #####  |  | |     \\\\    |  ############     ######### 
     #####   ##### #####  |__| |______\\\\___|  #####           ##### ##### 
    #####    ##### #####                      #####          #####   ##### 
   ##### ######### ########################## ############  #####     ##### 
  ##### ##########  ########################   ########### #####       ##### 
  ___________________________________________________________________________
  
                   M O N I T O R I N G   A P P L I C A T I O N
  ___________________________________________________________________________  

""".split /\n/
for i in [0..logo.length-1]
  if i < 9
    stream.write chalk.magenta.bold logo[i].substr 0, 23
    stream.write chalk.yellow.bold logo[i].substr 23, 20
    stream.write chalk.magenta.bold logo[i].substr 43
  else if i < 11
    stream.write chalk.magenta.bold logo[i]
  else
    stream.write chalk.yellow.bold logo[i]
  stream.write '\n'

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

console.log()

# Installation
# =================================================
# This logo may easily be loaded and the emblem can be selected by using a
# LOGO environment variable.

# Node Modules
# -------------------------------------------------

chalk = require 'chalk'
{string} = require 'alinex-util'

# Generate specific logo
# -------------------------------------------------
module.exports = (title = 'Application') ->
  # detect emblem
  sign = process.env.LOGO ? 'alinex'
  sign = 'alinex' unless logo[sign]?
  # get the title
  title = title.toUpperCase().split('').join ' '
  title = string.repeat(' ', Math.floor (76 - title.length) / 2) + title
  # return the logo
  return logo[sign] title

 logo =

  # Default Alinex Logo
  # -------------------------------------------------
  alinex: (title) ->
    c1 = chalk.cyan
    c2 = chalk.bold.yellow
    ct = chalk.yellow
    c1 """
                              #{c2 " __   ____     __"}
               ######  #####  #{c2 "|  | |    \\   |  |  "} ########### #####       #####
              ######## #####  #{c2 "|  | |     \\  |  |  "}############  #####     #####
             ######### #####  #{c2 "|  | |  |\\  \\ |  |  "}#####          #####   #####
            ########## #####  #{c2 "|  | |  | \\  \\|  |  "}#####           ##### #####
           ##### ##### #####  #{c2 "|  | |  |__\\     |  "}############     #########
          #####  ##### #####  #{c2 "|  | |     \\\\    |  "}############     #########
         #####   ##### #####  #{c2 "|__| |______\\\\___|  "}#####           ##### #####
        #####    ##### #####                      #####          #####   #####
       ##### ######### ########################## ############  #####     #####
      ##### ##########  ########################   ########### #####       #####
      ___________________________________________________________________________

      #{ct title}
      ___________________________________________________________________________

    """

  # divibib Logo
  # -------------------------------------------------
  divibib: (title) ->
    c1 = chalk.bold.gray
    c2 = chalk.green
    ct = chalk.green
    module.exports = c1 """

                    ###   #                     #   #{c2 "###           #   ###"}
                    ###  ###                   ###  #{c2 "###          ###  ###"}
                    ###   #                     #   #{c2 "###           #   ###"}
                    ###                             #{c2 "###               ###"}
      #{c2 " ##      "}########  ###  ###         ###  ###  #{c2 "#########    ###  #########"}
      #{c2 "####   "}###    ###  ###   ###       ###   ###  #{c2 "###    ###   ###  ###    ###"}
      #{c2 " ##   "}###     ###  ###    ###     ###    ###  #{c2 "###     ###  ###  ###     ###"}
            ###     ###  ###     ###   ###     ###  #{c2 "###     ###  ###  ###     ###"}
      #{c2 " ##   "}###     ###  ###      ### ###      ###  #{c2 "###     ###  ###  ###     ###"}
      #{c2 "####   "}###    ###  ###       #####       ###  #{c2 "###    ###   ###  ###    ###"}
      #{c2 " ##      "}########  ###        ###        ###  #{c2 "#########    ###  #########"}

      ___________________________________________________________________________

      #{ct title}
      ___________________________________________________________________________

    """

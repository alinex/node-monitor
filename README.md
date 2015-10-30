Package: alinex-monitor
=================================================

[![Build Status](https://travis-ci.org/alinex/node-monitor.svg?branch=master)](https://travis-ci.org/alinex/node-monitor)
[![Coverage Status](https://coveralls.io/repos/alinex/node-monitor/badge.png?branch=master)](https://coveralls.io/r/alinex/node-monitor?branch=master)
[![Dependency Status](https://gemnasium.com/alinex/node-monitor.png)](https://gemnasium.com/alinex/node-monitor)

This application will make server management easy and fast. It will check the
whole IT landscape from the host to the application. While most monitoring
tools has it's focus on the server here the focus lies more on the application
side.

> It is one of the modules of the [Alinex Universe](http://alinex.github.io/code.html)
> following the code standards defined in the [General Docs](http://alinex.github.io/node-alinex).


Install
-------------------------------------------------

[![NPM](https://nodei.co/npm/alinex-monitor.png?downloads=true&downloadRank=true&stars=true)
 ![Downloads](https://nodei.co/npm-dl/alinex-monitor.png?months=9&height=3)
](https://www.npmjs.com/package/alinex-monitor)

Install the package globally using npm:

``` sh
sudo npm install -g alinex-monitor --production
```

After global installation you may directly call `monitor` from anywhere.

``` sh
monitor --help
```

Always have a look at the latest [changes](Changelog.md).

kramdown
: A Markdown-superset converter
: makes it easier

Usage
-------------------------------------------------
After the monitor and it's controllers are fully configured it may be run by only calling:

    > monitor

This will start the monitor on the command line and check all controllers. For each
controller a line is printed with it's status.
If a controller got a problem it will give a detailed report on the console.

Alternatively you may give a controller name or pattern to select the controllers
to run:

    > monitor my-develop     # run only this controller
    > monitor my-*           # run all controller with the given name prefix

To run the controller continuously use the `daemon` option and start it in the
background.

    > monitor -b > /var/log/monitor.log 2>&1 &

The remaining options are used for informal use like:

- `list` - get a list of all configured controllers
- `tree` - show the list as tree (controller needs controller)
- `reverse` - show a reverse tree (controller is needed by controller)

### Status

The monitor uses the following status:

__running__ if the sensor is already analyzing, you have to wait

__disabled__ if this controller is currently not checked - this will be used
like ok for further processing

__ok__ if everything is perfect, there nothing have to be done - exit code 0

__warn__ if the sensor reached the warning level, know you have to keep an eye on
it - exit code 1

__fail__ if the sensor failed and there is a problem - exit code 2


Controller
-------------------------------------------------
A controller is an individual part to be checked. It contains some sensors to check
the system and may also depend on other controllers. Each controller is made by a
specific configuration files containing meta information.

See the following example for a full controller configuration:
``` yaml
# Monitoring controller configuration
# =================================================
# This is an example of a complete controller configuration.

name: Development Center
description: Server containing miscellaneous tools to help in the development process.

# Monitor runtime configuration
# -------------------------------------------------

# It may be disabled temporarily, seen as ok without check
disabled: false
# Time (in seconds) in which the value is seen as valid and should not be rechecked.
validity: 1m
# Time (in seconds) to rerun the check.
interval: 5m

# Sensors to run
# -------------------------------------------------
# The list of dependencies are sensors which have to work to make this controller
# fully work.
check:
  - sensor: diskfree
    name: /
    config:
      remote: my-develop
      share: /
  - sensor: diskfree
    name: /run
    config:
      remote: my-develop
      share: /run
    # weight setting specific to value of the following 'combine' setting:
    # With the `weight` settings on the different entries single group entries may
    # be rated specific not like the others. Use a number in `average` to make the
    # weight higher (1 is normal). Also the weight 'up' and 'down' changes the error
    # level for one step before using in calculation on all combine methods.
    #weight: 2

# ### Combine values
# For multiple dependencies this value defines how the individual sensors are
# combined to calculate the overall status:
#
# - max - the one with the highest failure value is used
# - min - the lowest failure value is used
# - average - the average status (arithmetic round) is used
combine: max

rule:
  - fail
  - warn
  - ok

info: |+
  This system is used for software development, building and deployment. An
  outage will have direct effects to the developers so that they can't submit,
  test and deploy their code.

hint: |+
  All necessary parts are on the same machine, so that you only have to bring
  this machine to work. Backups of the data are made on my-backup.

  Keep in mind that the machine is in the test net and you have to use a valid
  VPN connection for accessing.

contact: operations

ref:
  # system access
  subversion: http://192.168.1.6/svn
  nexus: http://192.168.1.6:8081/nexus
  Jenkins: http://192.168.1.6:8080/
  sonarqube: http://192.168.1.6:9000/
  # user/developer help
  doc: https://my-docs/confluence/pages/viewpage.action?pageId=48398554
  #issues:
  #api:
  #code:
  #other:
```

The controller will call the sensors and collect the data. It may also generate
reports or trigger specific actions.


Sensor
-------------------------------------------------
An sensor is a code module which allows to check specific parts of the system. It
will analyze the system and get some measurement values back.

Each use of a sensor in an controller with specific setup data is further called
a __check__.

The sensors contains:

- schema - the definition for the configuration
- meta - some meta informations used to make descriptive reports
- run() - the method to really use this sensor returning a data object
- analysis() - make an analysis run

### Config

Each sensor has its own configuration settings like seen above in the controller
configuration. The common keys are:

- warn - the javascript code to check to set status to warn
- fail - the javascript code to check to set status to fail
- analysis - the configuration for the analysis if it is run

### Meta Data

The following meta data are available:

- title
- description
- category - one of 'sys', 'net', 'srv'
- hint - additional help for problems

### Result

After running a sensor you get a result object containing:

- date - array with start and end date of run
- status - one of: 'ok', 'warn', 'fail' ('running')
- values - object containing specific values

And the analysis will get you a markdown document.


System Sensors
-------------------------------------------------

### Diskfree

This sensor will check the disk usage on a specific block device. The configuration
allows:

- remote - the remote server, there to run the sensor
- share - the disk share's path or mount point to check
- warn - the javascript code to check for warn status
- fail - the javascript code to check for fail status (default: 'free is 0')
- analysis - the configuration for the analysis if it is run
  - dirs - the list of directories to monitor their volume

### CPU

Checking the CPU utilization of all cores together. With the configuration values:

- remote - the remote server, there to run the sensor
- warn - the javascript code to check for warn status (default: 'active >= 100%')
- fail - the javascript code to check for fail status
- analysis - the configuration for the analysis if it is run
  - procNum - number of top processes to list



cores same as cpu but for single cores

cat /proc/loadavg

vmstat



Storage
-------------------------------------------------
The controllers will hold some information in memory but store all values also in
a database for long time analysis. This database may look like:

``` text
    mon_controller
    P controller_id
    U name (string)

    mon_check
    P check_id
    F controller_id
    I category (string)
    I sensor (string)
    I name (string)

    mon_value
    P value_id
    F check_id
    - name (string) # of the value
    - warn (float)
    - fail (float)
    - unit (string)

    mon_value_minute # delete after 1 day
    P value_minute_id
    F value_id
    I timerange (datetime)
    - num (int) # number of measurements
    - min (float)
    - avg (float)
    - max (float)

    mon_value_quarter # delete after 2 days
    mon_value_hour # delete after 1 week
    mon_value_day # delete after 6 months
    mon_value_week # delete after 5 years

    mon_value_report # delete after 6 months
    P value_report_id
    F value_id
    I date (datetime)
    - report (clob)

    mon_status # delete after 1 year
    P status_id
    F controller_id
    F check_id
    I change (datetime)
    - status (enum)

    mon_report # delete after 5 years
    P report_id
    F controller_id
    I date (datetime)
    - report (clob)
```

To keep the data volume low old values will be removed.


Actor
-------------------------------------------------
The controller may do some actions:

- inform on console/log (each analysation)
- inform per email (on state change)
- send web request (on state change)
- try to repair (not implemented, yet)


Display Results
-------------------------------------------------
Additionally to the reports it is possible to visualize the stored data over time
to find patterns.

To do this special views for each report data should be made on the database which
can be visualized using a data analyzation tool like dbVisualizer.


Roadmap
-------------------------------------------------

- controller daemon
- generate reports
- add timeouts for check and analysis
- convert old sensors
- db checks
- store results => db
- create reports
- store reports
- send emails on state change
- add check type: serial: []
- add check type: controller: ....
- disabled controller
- add example reports for each sensor to doc


License
-------------------------------------------------

Copyright 2015 Alexander Schilling

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

>  <http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

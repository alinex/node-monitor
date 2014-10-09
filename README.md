Package: alinex-monitor
=================================================

[![Build Status] (https://travis-ci.org/alinex/node-monitor.svg?branch=master)](https://travis-ci.org/alinex/node-monitor)
[![Coverage Status] (https://coveralls.io/repos/alinex/node-monitor/badge.png?branch=master)](https://coveralls.io/r/alinex/node-monitor?branch=master)
[![Dependency Status] (https://gemnasium.com/alinex/node-monitor.png)](https://gemnasium.com/alinex/node-monitor)

This application will make server management easy and fast. It will check the
whole IT landscape from the host to the application. While most monitoring
tools has it's focus on the server here the focus lies more on the application
side.

It is one of the modules of the [Alinex Universe](http://alinex.github.io/node-alinex)
following the code standards defined there.


Install
-------------------------------------------------

The easiest way to use it is to install it with the node package manager:

	> sudo apt-get install nodejs
    > sudo npm install -g alinex-monitor

This will install the package in `/usr/local` directory.

You may create a symbolic link for the configuration files to `/etc/alinex-monitor` this
enables you to put all the configuration files in a common path.

    > ln -s /etc/alinex-monitor /usr/local/lib/node_modules/alinex-monitor/var/local

Now setup the controller configuration under this path: `/etc/alinex-monitor/config`
(see below).

[![NPM](https://nodei.co/npm/alinex-monitor.png?downloads=true&stars=true)](https://nodei.co/npm/alinex-monitor/)


Usage
-------------------------------------------------
After the monitor and it's controllers are fully configured it may be run by only calling:

	> monitor

This will start the monitor on the command line and check all controllers. For each
controller a line is printed with it's status.
If a controller got a problem it will give a detailed report on the console.


### Status

The monitor and controllers use the following status:

__running__ if the sensor is already analyzing, you have to wait

__disabled__ if this controller is currently not checked - this will be used
like ok for further processing

__ok__ if everything is perfect, there nothing have to be done - exit code 0

__warn__ if the sensor reached the warning level, know you have to keep an eye on it
- exit code 1

__fail__ if the sensor failed and there is a problem - exit code 2


Configuration
-------------------------------------------------
As described above it has may be accessed through /etc/alinex-monitor/config` but it's 
real path is in the application's directory `var/local/config`.


Structure
-------------------------------------------------

### Monitor

The monitor is the main programm running everything.

### Controller

Each element which is individually accessible is an controller. This may be a
reference to a specific sensor check or a group of other controllers. The controller
also specifies how to interpret the sensor status.

- `config` - configuration (given combined with defaults)
- `result` - the results:
  - `date` - start date of last or current run
  - `status` - status of the last or current run (ok, warn, fail)
  - `message` - error message of the last or current run
  - `value` - map of measured values
  - `analysis` - additional analysis data

### Sensor

The sensor retrieves the system information. It is configured and called from the
controller and checks specific parts of the system. It gives a status, the measurement
and some informational data.


Submodules
-------------------------------------------------

Some parts of the monitoring application are provided as separate modules to
be updated independly of the monitor app itself.

- [alinex-monitor-sensor](http://alinex.github.io/node-monitor-sensor) -
  collection of sensors to check systems and services


License
-------------------------------------------------

Copyright 2014 Alexander Schilling

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

>  <http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

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

    > npm install alinex-monitor

This will install the package, in your current directory.

[![NPM](https://nodei.co/npm/alinex-monitor.png?downloads=true&stars=true)](https://nodei.co/npm/alinex-monitor/)


Submodules
-------------------------------------------------

Some parts of the monitoring application are provided as separate modules to
be updated independly of the monitor app itself.

- [alinex-monitor-sensor](http://alinex.github.io/node-monitor-sensor) -
  collection of sensors to check systems and services

In the future there will also be:

- alinex-monitor-action -
  actions to be called from the controler


Development
-------------------------------------------------

Because it is in the development here some thoughts in which direction it may
lead.

#### Sensor

Used with check routines in alinex config.

#### Actor

#### Controller

Config:

- name
- description
- dependency
  - list of other controllers
- sensor
  - type: ping...
  - config:
  - server: local
- check interval
- actor config
- contact
  - name: address or [address]
- rules

Status:

- ok if all sensors are ok
- warn if one sensor has at least warn state
- fail if sensor failed but all dependencies are ok or warn

Rules:

- min. time to react on changed state
- type of action:
  - run actor
  - send email
  - call service
- rerun after time

Storage

- last time ok
- first time of current state

#### REST Interface

POST /monitor/sensor/ping
POST /monitor/actor/cmd
GET /monitor/controller/name
GET /monitor/collector/name

- http (with basic-auth)

#### Commandline Interface

To interactively work with sensors.

#### Collector

#### Frontend

#### System installation

- local sensor
- local controller
- local collector
- remote collector
- remote frontend


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

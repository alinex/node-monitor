Package: alinex-monitor
=================================================

[![Build Status] (https://travis-ci.org/alinex/node-monitor.svg?branch=master)](https://travis-ci.org/alinex/node-monitor)
[![Coverage Status] (https://coveralls.io/repos/alinex/node-monitor/badge.png?branch=master)](https://coveralls.io/r/alinex/node-monitor?branch=master)
[![Dependency Status] (https://gemnasium.com/alinex/node-monitor.png)](https://gemnasium.com/alinex/node-monitor)

This should be an application to make server management easy and fast.

In the moment it is incomplete and not usable. But you may use some of the
submodules directly in your own application.

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

Currently only the following submodules exists:

- [alinex-monitor-sensor](http://alinex.github.io/node-monitor-sensor) -
  collection of sensors to check systems and services

In the future there will also be:

- alinex-monitor-collector -
  a storage for collected data
- alinex-monitor-web -
  a web frontend application
- alinex-monitor-action -
  an alert system with possible auto repair


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

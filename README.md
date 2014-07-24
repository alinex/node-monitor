Package: alinex-monitor
=================================================

[![Build Status] (https://travis-ci.org/alinex/node-monitor.svg?branch=master)](https://travis-ci.org/alinex/node-monitor)
[![Coverage Status] (https://coveralls.io/repos/alinex/node-monitor/badge.png?branch=master)](https://coveralls.io/r/alinex/node-monitor?branch=master)
[![Dependency Status] (https://gemnasium.com/alinex/node-monitor.png)](https://gemnasium.com/alinex/node-monitor)

This should be an application to make server management easy and fast.

In the moment it is an incomplete module only but may be already used to
analyze components in an automatic way.

It is one of the modules of the [Alinex Universe](http://alinex.github.io/node-alinex)
following the code standards defined there.


Install
-------------------------------------------------

The easiest way to use it is to install it with the node package manager:

    > npm install alinex-monitor

This will install the package, in your current directory.

[![NPM](https://nodei.co/npm/alinex-monitor.png?downloads=true&stars=true)](https://nodei.co/npm/alinex-monitor/)


Usage
-------------------------------------------------

The sensors may be used standalone without the complete monitoring application.

### Sensor run

To use any sensor you have to load it (example from a simple ping test):

    var PingSensor = require('alinex-monitor/lib/sensor/ping');

And you have to configure it. This may also be a
[alinex-config](http://alinex.github.io/node-config) object.

    var ping = new PingSensor({
      ip: '193.99.144.80'
    });

Now you can start it using a callback method:

    ping.run(function(err) {
      // do something with result in ping object
      console.log(ping);
    });

Or alternatively you may use an event based call:

    ping.run();
    ping.on 'end', function() {
      // do something with result in ping object
      console.log(ping);
    });

The `ping` object looks like:

    { config: { verbose: false, timeout: 1, ip: '137.168.111.222' },
      result:
      { date: Tue Jul 22 2014 14:08:34 GMT+0200 (CEST),
        status: 'fail',
        data: '1 packets transmitted, 0 received, 100% packet loss, time 0ms',
        message: 'Ping exited with code 1'
      }
    }


API
-------------------------------------------------

### Sensor classes

- [Sensor](src/sensor/base.coffee) - base class
- [PingSensor](src/sensor/ping.coffee) - network ping test

#### Methods

- `run(cb)` - start a new analyzation with optional callback

#### Events

- `error` - then the sensor could not work properly
- `start` - sensor has started
- `end` - sensor ended analysis
- `ok` - no problems found
- `warn` - warning means high load or critical state
- `fail` - not working correctly

#### Static properties

- `meta` - some meta data for this test type
  - `name` - title of the test
  - `description` - short description what will be checked
  - `category` - to group similiar tests together
  - `level` - gives a hint if it is a low level or higher level test
- `values` - meta information for the measurement values
- `config` - the default configuration
  (each entry starting with underscore gives the help text for that value)

#### Properties

- `config` - configuration (given combined with defaults)
- `result` - the results:
  - `date` - start date of last or current run
  - `status` - status of the last or current run
  - `value` - map of measured values
  - `data` - complete data from the last or current run
  - `message` - error message of the last or current run


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

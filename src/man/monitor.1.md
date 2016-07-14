monitor
=================================================

This application will make server management easy and fast. It will check the
whole IT landscape from the host to the application.

While most monitoring tools has it's focus on the server here the focus lies on
the application side, too.

- remote daemon-less analysis
- lots of sensors
- alerting and reporting
- data store for time analysis
- interactive analyzing and exploring

The monitor will analyze your whole environment in deep by connecting to the different
systems in parallel and check them deeply. If a problem occurs an additional analysis
step may be made to get more information. The result values will be stored in the
storage database and a detailed report will be created. Based on additional action
rules the report may be send by email or a web request is made. Out of the stored
values time reports may be created.


Usage
-------------------------------------------------
After the monitor and it's controllers are fully configured it may be run by
only calling:

    > monitor

    Initializing...
    Analyzing systems...
    Finished.

This will start the monitor on the command line and check all controllers. All
of them which make some problems will be printed on the console.

Global options:

    -C, --nocolors  turn of color output
    -v, --verbose   run in verbose mode
    -h, --help      Show help

### Check controller once

You may run the monitor to check the defined controllers once and get their
status:

    > monitor my-develop    # run only this controller
    > monitor my-*          # run controllers with the given name prefix
    > monitor               # run all controllers

You may start a try run in which nothing is stored in the storage and no action
is taken.

    -t --try        do a try run

The verbose mode works here in multiple steps:

    -v    show the controller status on console
    -vv   show also the sensor status on console
    -vvv  also display the result values

If no verbose mode is set only warning and error state of controller will be reported
on console.

The output may look like:

    > monitor -v

    Initializing...
    Analyzing systems...
    2015-12-15 12:55:32 Controller dvb-develop => ok
    Finished.

    > monitor -vvv

    Initializing...
    Analyzing systems...
    2015-12-15 12:55:51 Check load:dvb-develop => ok
    2015-12-15 12:55:51 Check http:->http://192.168.200.106/svn/ => ok
    2015-12-15 12:55:51 Check memory:dvb-develop => ok
    2015-12-15 12:55:51 Check diskfree:dvb-develop:/ => ok
    2015-12-15 12:55:51 Check diskfree:dvb-develop:/var => ok
    2015-12-15 12:55:52 Check ping:localhost->192.168.200.106 => ok
    2015-12-15 12:55:52 Check socket:tcp localhost->192.168.200.106:80 => ok
    2015-12-15 12:55:52 Check time:dvb-develop => ok
    2015-12-15 12:55:52 Check user:dvb-develop => ok
    2015-12-15 12:56:01 Check cpu:dvb-develop => ok
    2015-12-15 12:56:01 Check diskio:dvb-develop:sda1 => ok
    2015-12-15 12:56:02 Check net:dvb-develop:eth0 => ok
    2015-12-15 12:56:02 Controller dvb-develop => ok
    Finished.


### Run as a service

To run the controller continuously use the `daemon` option and start it in the
background.

    > monitor -d -C > /var/log/monitor.log 2>&1 &

This will check all the controllers in the defined timerange, collect measurement
values and send alerts. You may also specify some controllers to run instead of
all.

Like seen above you may send the normal output to a log file but better configure
a log destination through the config files (see below).

### Additional commands

You may run some other commands through the interactive console or directly by
giving everything on the commandline call. See the next section for more details
on this topic.

### Setup

To use the controller you have to setup the whole process using some configuration
files. And maybe a storage database will be used.


Read more
-------------------------------------------------
To get the full documentation including configuration description look into
[Monitor](http://alinex.github.io/node-monitor).


License
-------------------------------------------------

(C) Copyright 2015 Alexander Schilling

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

>  <http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

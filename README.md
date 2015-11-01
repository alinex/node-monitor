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

### CPU

Checking the CPU utilization of all cores together. With the configuration values:

- remote - the remote server, there to run the sensor
- warn - the javascript code to check for warn status (default: 'active >= 100%')
- fail - the javascript code to check for fail status
- analysis - the configuration for the analysis if it is run
  - minCpu - show processes with this CPU usage or above (default: 10%)
  - numProc - number of top processes to list

The resulting report part may look like:

``` text
CPU (test)
-----------------------------------------------------------------------------

Check the current activity in average percent of all cores.

Last check results from Sat Oct 31 2015 22:01:26 GMT+0100 (CET) are:

|          LABEL          |                     VALUE                        |
| ----------------------- | -----------------------------------------------: |
| CPU Cores               |                                                2 |
| CPU Speed               |                                         1000 MHz |
| User Time               |                                           0.11 % |
| Nice User Time          |                                           0.83 % |
| System Time             |                                           0.05 % |
| Idle Time               |                                              0 % |
| Activity                |                                              1 % |
| I/O Wait Time           |                                              0 % |
| Hardware Interrupt Time |                                              0 % |
| Software Interrupt Time |                                              0 % |
| Lowest CPU Core         |                                              1 % |
| Highest CPU Core        |                                              1 % |

A high CPU usage means that the server may not start another task immediately.
If the load is also very high the system is overloaded, check if any application
goes evil.

This has been checked with the following setup:

|       CONFIG       |  VALUE                                                |
| ------------------ | ----------------------------------------------------: |
| Warn if            |                                      Activity >= 100% |

The top CPU consuming processes above 10% are:

| COUNT |  %CPU |  %MEM | COMMAND                                            |
| ----: | ----: | ----: | -------------------------------------------------- |
|     3 |  142% | 19.1% | /opt/sublime_text/sublime_text                     |
|     1 | 48.6% |  2.9% | /usr/bin/nodejs                                    |
|    11 | 26.1% | 25.2% | /opt/google/chrome/chrome                          |
```

### Load

Check the system load in the last time ranges. With the configuration values:

- remote - the remote server, there to run the sensor
- warn - the javascript code to check for warn status
- fail - the javascript code to check for fail status
- analysis - the configuration for the analysis if it is run
  - minCpu - show processes with this CPU usage or above (default: 10%)
  - numProc - number of top processes to list

The resulting report part may look like:

``` text
Load (test)
-----------------------------------------------------------------------------

Check the local processor activity over the last minute to 15 minutes.

Last check results from Sat Oct 31 2015 21:50:07 GMT+0100 (CET) are:

|          LABEL          |                     VALUE                        |
| ----------------------- | -----------------------------------------------: |
| Num Cores               |                                                2 |
| 1min Load               |                                           2.86 % |
| 5min Load               |                                           2.79 % |
| 15min Load              |                                           2.83 % |

A very high system load makes the system irresponsible or really slow. Mostly
this is CPU-bound load, load caused by out of memory issues or I/O-bound load
problems.

The top CPU consuming processes above 10% are:

| COUNT |  %CPU |  %MEM | COMMAND                                            |
| ----: | ----: | ----: | -------------------------------------------------- |
|     3 |   89% | 19.1% | /opt/sublime_text/sublime_text                     |
|     1 | 67.2% |  2.7% | /usr/bin/nodejs                                    |
|    11 | 26.7% | 27.1% | /opt/google/chrome/chrome                          |
```

### Memory

Check the memory usage on the system

- remote - the remote server, there to run the sensor
- warn - the javascript code to check for warn status
- fail - the javascript code to check for fail status
- analysis - the configuration for the analysis if it is run
  - minMem - show processes with this memory usage or above (default: 10%)
  - numProc - number of top processes to list

The resulting report part may look like:

``` text
Memory (test)
-----------------------------------------------------------------------------

Check the free and used memory.

Last check results from Sun Nov 01 2015 17:51:46 GMT+0100 (CET) are:

|          LABEL          |                     VALUE                        |
| ----------------------- | -----------------------------------------------: |
| Total                   |                                          1.85 GB |
| Used                    |                                          1.52 GB |
| Free                    |                                          310 MiB |
| Shared                  |                                           23 MiB |
| Buffers                 |                                          220 MiB |
| Cached                  |                                          400 MiB |
| Swap Total              |                                          1.88 GB |
| Swap Used               |                                          197 MiB |
| Swap Free               |                                          1.67 GB |
| Actual Free             |                                         0.975 GB |
| Percent Free            |                                           0.53 % |
| Swap Percent Free       |                                           0.89 % |

Check which process consumes how much memory, maybe some processes have a memory
 leak.

This has been checked with the following setup:

|       CONFIG       |  VALUE                                                |
| ------------------ | ----------------------------------------------------: |
| Warn if            |                                             Free < 1% |

The top memory consuming processes above 10% are:

| COUNT |  %CPU |  %MEM | COMMAND                                            |
| ----: | ----: | ----: | -------------------------------------------------- |
|     2 | 21.3% |  4.2% | /usr/bin/python2.7                                 |
|     1 |   84% |  2.7% | /usr/bin/nodejs                                    |
```

### Diskfree

This sensor will check the disk usage on a specific block device. The configuration
allows:

- remote - the remote server, there to run the sensor
- share - the disk share's path or mount point to check
- warn - the javascript code to check for warn status
- fail - the javascript code to check for fail status (default: 'free is 0')
- timeout - the time the whole test may take before stopping
- analysis - the configuration for the analysis if it is run
  - dirs - the list of directories to monitor their volume
  - timeout - the time the analysis may take before stopping

The resulting report part may look like:

``` text
Diskfree (test)
-----------------------------------------------------------------------------

Test the free diskspace of one share.

Last check results from Sat Oct 31 2015 22:09:19 GMT+0100 (CET) are:

|          LABEL          |                     VALUE                        |
| ----------------------- | -----------------------------------------------: |
| Share                   |                                        /dev/sda1 |
| Type                    |                                             ext4 |
| Available               |                                          216 GiB |
| Used                    |                                           28 GiB |
| % Used                  |                                           0.13 % |
| Free                    |                                          188 GiB |
| % Free                  |                                           0.87 % |
| Mountpoint              |                                                / |

If a share is full it will make I/O problems in the system or applications in
case of the root partition it may also neither be possible to log errors. Maybe
some old files like temp or logs can be removed or compressed.

This has been checked with the following setup:

|       CONFIG       |  VALUE                                                |
| ------------------ | ----------------------------------------------------: |
| Share or Mount     |                                                     / |
| Measurement Time   |                                                   5 s |
| Fail if            |                                             Free is 0 |

Maybe some files in one of the following directories may be deleted or moved:

| PATH                                |  FILES   |    SIZE    |   OLDEST    |
| ----------------------------------- | -------: | ---------: | :---------- |
| /tmp                                |      14* |   4.37 MB* | 2015-10-30* |
| /var/log                            |     322* |   8.83 MB* | 2014-05-30* |

__(*)__
: The rows marked with a '*' are only assumptions, because not all
files were readable. All the values are minimum values, the real values may
be higher.
```

### IO

### Net

### Time

### Users


Network Sensors
-------------------------------------------------

### Ping

### Socket

### Http

### Ftp

### SFtp


Application Sensors
-------------------------------------------------

### PID

cat /proc/PID/cmdline
cat /proc/PID/status

### Log

### PostgreSQL

### Database

### Apache

### Tomcat


Static Info Sensors
-------------------------------------------------

### Hardware

cat /proc/cpuinfo
lscpu
cat /proc/diskstats

### Software

cat /proc/version

### Network

/proc/sys/kernel/hostname
/proc/sys/kernel/domainname

### Daemons

### ApacheSites

### TomcatApps

### Upgrade


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

- release exec with timeout
- add postgres db support
- db checks
- store results => db
- store reports
- send emails on state change
- add check type: serial: []
- add check type: controller: ....
- disabled controller
- add example reports for each sensor to doc

- generate controller report
- convert old sensors
- controller daemon
- add over time report
- -v verbose show/send always report
- -m send to other email instead of controller contacts


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

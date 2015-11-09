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

Install the package globally using npm on a central server. From there all your
machines may be checked:

``` sh
sudo npm install -g alinex-monitor --production
```

After global installation you may directly call `monitor` from anywhere.

``` sh
monitor --help
```

Because this application works agentless, you don't have to do something special
on your clients but often some simple changes can make the reports more powerful.
If so you will get a hint in the report.

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
    config:
      remote: my-develop
      share: /
  - sensor: diskfree
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
- message - optional, explaining the status
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
- time - measurement time in seconds
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
|     3 |   45% | 19.1% | /opt/sublime_text/sublime_text                     |
|     1 | 34.1% |  2.7% | /usr/bin/nodejs                                    |
|    11 | 13.3% | 27.1% | /opt/google/chrome/chrome                          |
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
|     2 | 10.8% |  4.2% | /usr/bin/python2.7                                 |
|     1 |   42% |  2.7% | /usr/bin/nodejs                                    |
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
| % Used                  |                                             13 % |
| Free                    |                                          188 GiB |
| % Free                  |                                             87 % |
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

### DiskIO

This sensor will check the disk io traffic:

- remote - the remote server, there to run the sensor
- device - the disk device name
- time - measurement time in seconds
- warn - the javascript code to check for warn status
- fail - the javascript code to check for fail status

The resulting report part may look like:

``` text
Disk IO (test)
-----------------------------------------------------------------------------

Check the disk io traffic.

Last check results from Sun Nov 01 2015 23:11:31 GMT+0100 (CET) are:

|          LABEL          |                     VALUE                        |
| ----------------------- | -----------------------------------------------: |
| Read operations/s       |                                                0 |
| Write operation/s       |                                             0.67 |
| Read/s                  |                                              0 B |
| Write/s                 |                                            15 kB |
| Total Read              |                                          8.51 GB |
| Total Write             |                                          6.13 GB |
| Read/s                  |                                             0 ms |
| Write/s                 |                                          6.67 ms |

If there are any problems here check the device for hardware or network
problems.

This has been checked with the following setup:

|       CONFIG       |  VALUE                                                |
| ------------------ | ----------------------------------------------------: |
| Device name        |                                                   sda |
```

### Net

This sensor will check the network traffic on a specified interface:

- remote - the remote server, there to run the sensor
- interface - the interface to analyze
- time - measurement time in seconds
- warn - the javascript code to check for warn status (default: 'errors > 50%')
- fail - the javascript code to check for fail status (default: 'errors > 99%')

The resulting report part may look like:

``` text
Network Traffic (test)
-----------------------------------------------------------------------------

Check the network traffic.

Last check results from Mon Nov 02 2015 20:20:58 GMT+0100 (CET) are:

|          LABEL          |                     VALUE                        |
| ----------------------- | -----------------------------------------------: |
| Received Transfer       |                                             46 B |
| Received Packets        |                                                1 |
| Received Errors         |                                              0 % |
| Received Drops          |                                              0 % |
| Received FIFO Errors    |                                              0 % |
| Transmit Transfer       |                                             66 B |
| Transmit Packets        |                                                1 |
| Transmit Errors         |                                              0 % |
| Transmit Drops          |                                              0 % |
| Transmit FIFO Errors    |                                              0 % |
| Total Transfer          |                                            112 B |
| Total Packets           |                                                2 |
| Total Errors            |                                              0 % |
| Total Drops             |                                              0 % |
| Total FIFO Errors       |                                              0 % |
| Total Frame Errors      |                                              0 % |
| Interface State         |                                               UP |
| Mac Address             |                                00:21:63:da:d5:da |
| IP Address              |                                     192.168.1.18 |
| IPv6 Address            |                         fe80::221:63ff:feda:d5da |

If you see a high volume it may be overloaded or a attack is running.

This has been checked with the following setup:

|       CONFIG       |  VALUE                                                |
| ------------------ | ----------------------------------------------------: |
| Interface Name     |                                                 wlan0 |
| Measurement Time   |                                                  10 s |
| Warn if            |                                    Total Errors > 50% |

Listening servers:

| PROTO | LOCAL IP             | PORT  |
| :---- | :------------------- | :---- |
| tcp   | 0.0.0.0              | 139   |
| tcp   | 0.0.0.0              | 22    |
| tcp   | 0.0.0.0              | 445   |
| tcp   | 127.0.0.1            | 3306  |
| tcp   | 127.0.1.1            | 53    |
| tcp   | 127.0.0.1            | 5939  |
| tcp   | 127.0.0.1            | 631   |
| tcp6  | ::                   | 139   |
| tcp6  | ::                   | 22    |
| tcp6  | ::                   | 445   |
| tcp6  | ::1                  | 631   |

Active internet connections:

| PROTO | FOREIGN IP           | PORT  |   PID  |     PROGRAM    |
| :---- | :------------------- | ----: | -----: | :------------- |
| tcp   | 173.194.113.0        | 443   |   3955 | chrome         |
| tcp   | 173.194.113.2        | 443   |   3955 | chrome         |
| tcp   | 198.252.206.25       | 80    |   3955 | chrome         |
| tcp   | 209.20.75.76         | 80    |  12249 | plugin_host    |
| tcp   | 64.233.167.188       | 443   |   3955 | chrome         |
```

### Time

This sensor will check the network traffic on a specified interface:

- remote - the remote server, there to run the sensor
- host - the name of an NTP server to call (default: pool.ntp.org)
- port - the port to use for NTP calls (default: 123)
- timeout - the time in milliseconds to retrieve time
- warn - the javascript code to check for warn status (default: 'diff > 10000')
- fail - the javascript code to check for fail status

The resulting report part may look like:

``` text
Time Check (test)
-----------------------------------------------------------------------------

Check the system time against the Internet.

Last check results from Mon Nov 02 2015 20:59:55 GMT+0100 (CET) are:

|          LABEL          |                     VALUE                        |
| ----------------------- | -----------------------------------------------: |
| Local Time              |          Mon Nov 02 2015 21:00:00 GMT+0100 (CET) |
| Remote Time             |          Mon Nov 02 2015 20:59:59 GMT+0100 (CET) |
| Difference              |                                           259 ms |

If the time is not correct it may influence some processes which goes over
multiple hosts. Therefore install and configure `ntpd` on the machine.

This has been checked with the following setup:

|       CONFIG       |  VALUE                                                |
| ------------------ | ----------------------------------------------------: |
| NTP Hostname       |                                          pool.ntp.org |
| NTP Port           |                                                   123 |
| Timeout            |                                                  10 s |
| Warn if            |                                    Difference > 10000 |
```

### User

This sensor will analyse processes started from a specific user:

- remote - the remote server, there to run the sensor
- user - the user name to analyze
- warn - the javascript code to check for warn status (default: 'diff > 10000')
- fail - the javascript code to check for fail status
- analysis - the configuration for the analysis if it is run
  - minCpu - show processes with this CPU usage or above (default: 10%)
  - minMem - show processes with this memory usage or above (default: 10%)
  - numProc - number of top processes to list

The resulting report part may look like:

``` text
Active User (alex)
-----------------------------------------------------------------------------

Check what an active user do.

Last check results from Wed Nov 04 2015 19:19:45 GMT+0100 (CET) are:

|          LABEL          |                     VALUE                        |
| ----------------------- | -----------------------------------------------: |
| Processes               |                                               69 |
| % CPU                   |                                             84 % |
| % Memory                |                                             59 % |
| Physical Memory         |                                         21.6 MiB |
| Virtual Memory          |                                          1.13 MB |

This check will give an overview of the activities of an (logged in) user. If
you look at the processes you may find out that some other warnings like high
load are user made and you may contact this person directly.

This has been checked with the following setup:

|       CONFIG       |  VALUE                                                |
| ------------------ | ----------------------------------------------------: |
| Username to check  |                                                  alex |

The top CPU consuming processes above 1% CPU above 1% MEM (max. 5 processes)
are:

|  PID  | %CPU | %MEM |   VSZ   |   RSS  |  TIME |           COMMAND         |
| ----- | ---- | ---- | ------- | ------ | ----- | ------------------------- |
| 30362 | 74.7 |  2.8 |  101212 |  51212 |  0:10 | /usr/bin/nodejs           |
| 30343 |  7.0 |  1.3 |   74424 |  23956 |  0:01 | builder                   |
| 19859 |  1.4 | 20.4 | 1416588 | 368036 | 22:15 |
/opt/sublime_text/sublime_text |

The active logins are:

|   TERM    |    LOGIN     |         IP         |
| --------- | ------------ | ------------------ |
| tty8      | Oct 30 16:45 |                  0 |
| pts/3     | Oct 30 16:46 |                  0 |
| pts/4     | Oct 30 21:32 |                  0 |
| pts/5     | Oct 31 19:28 |                  0 |
```


Network Sensors
-------------------------------------------------

### Ping

Although simple, but important to check if a host is responding to ICMP ping
packets. Thus, it is possible to measure the availability of a server, as well
as the response time and packet loss:

- remote - the remote server, there to run the sensor
- host - the server hostname or ip address to be called for ping
- count - the number of ping packets to send, each after the other (default: 1)
- interval - the time to wait between sending each packet (default: 1s)
- size - the number of bytes to be send, keep in mind that 8 bytes for the ICMP header are added
  (default: 24B)
- timeout - the time in milliseconds the whole test may take before stopping and failing it
  (default: 1s)
- warn - the javascript code to check for warn status (default: 'quality < 100%')
- fail - the javascript code to check for fail status (default: 'quality is 0')

``` text
Ping (->192.168.2.25)
-----------------------------------------------------------------------------

Test the reachability of a host on a IP network and measure the round-trip time
for the messages send.

Last check results from Wed Nov 04 2015 22:52:38 GMT+0100 (CET) are:

|          LABEL          |                     VALUE                        |
| ----------------------- | -----------------------------------------------: |
| Avg. Response Time      |                                          13.4 ms |
| Min. Respons Time       |                                          13.4 ms |
| Max. Response Time      |                                          13.4 ms |
| Quality                 |                                            100 % |

Check the network card configuration if local ping won't work or the network
connection for external pings.

This has been checked with the following setup:

|       CONFIG       |  VALUE                                                |
| ------------------ | ----------------------------------------------------: |
| Number of Packets  |                                                     1 |
| Wait Interval      |                                                   1 s |
| Packetsize         |                                                  56 B |
| Overall Timeout    |                                                   1 s |
| Warn if            |                                        Quality < 100% |
| Fail if            |                                          Quality is 0 |
```

### Socket

This sensor will ping another host:

- remote - the remote server, there to run the sensor
- host - the server hostname or ip address to be called for ping
- port - the port number used to connect to
- transport - the protocol used for internet transport layer (default:tcp)
- warn - the javascript code to check for warn status (default: 'quality < 100%')
- fail - the javascript code to check for fail status (default: 'quality is 0')

``` text
Socket (tcp localhost->193.99.144.80:80)
-----------------------------------------------------------------------------

Use TCP sockets to check for the availability of a service behind a given port.

Last check results from Thu Nov 05 2015 21:42:12 GMT+0100 (CET) are:

|          LABEL          |                     VALUE                        |
| ----------------------- | -----------------------------------------------: |
| Response Time           |                                          3744 ms |

On problems the service may not run or a network problem exists.

This has been checked with the following setup:

|       CONFIG       |  VALUE                                                |
| ------------------ | ----------------------------------------------------: |
| Hostname or IP     |                                         193.99.144.80 |
| Port               |                                                    80 |
| Transport Protocol |                                                   tcp |
| Timeout            |                                                   2 s |
```

### Http

This sensor will ping another host:

- remote - the remote server, there to run the sensor
- url - the URL to request
- timeout - the timeout in milliseconds till the process is stopped
  and be considered as failed
- username - the name used for basic authentication
- password - the password used for basic authentication
- match - the substring or regular expression which have to match
- warn - the javascript code to check for warn status
- fail - the javascript code to check for fail status
  (default: 'statusCode < 200 or statusCode >= 400')
- analysis
  - bodyLength - the maximum body display length in analysis report
    (default: 256)

If a remote server reference is given this will be used for tunneling over ssh
as proxy.

``` text
HTTP Request (->http://heise.de)
-----------------------------------------------------------------------------

Connect to an HTTP or HTTPS server and check the response.

Last check results from Fri Nov 06 2015 22:20:54 GMT+0100 (CET) are:

|          LABEL          |                     VALUE                        |
| ----------------------- | -----------------------------------------------: |
| Response Time           |                                           288 ms |
| Status Code             |                                              200 |
| Status Message          |                                               OK |
| Server                  |                                            nginx |
| Content Type            |                         text/html; charset=utf-8 |
| Content Length          |                                          167 KiB |
| Body Match              |                                            false |

If the server didn't respond it also may be a network problem.

This has been checked with the following setup:

|       CONFIG       |  VALUE                                                |
| ------------------ | ----------------------------------------------------: |
| URL                |                                       http://heise.de |
| Timeout            |                                                  10 s |
| Fail if            |               Status Code < 200 or Status Code >= 400 |

See the following details of the check which may give you a hint there the
problem is.

__GET http://heise.de__

    referer: http://www.heise.de/

Response:

    server: nginx
    content-type: text/html; charset=utf-8
    x-cobbler: octo06.heise.de
    x-clacks-overhead: GNU Terry Pratchett
    last-modified: Fri, 06 Nov 2015 21:20:54 GMT
    expires: Fri, 06 Nov 2015 21:21:26 GMT
    cache-control: public, max-age=32
    transfer-encoding: chunked
    date: Fri, 06 Nov 2015 21:20:55 GMT
    age: 1
    connection: keep-alive
    vary: User-Agent,Accept-Encoding,X-Forwarded-Proto,X-Export-Format,X-Export-Agent

Content:

    <!DOCTYPE html>
        <html lang="de">

        <head>
            <title>heise online - IT-News, Nachrichten und Hintergründe
            </title>
                <meta name="description" content="News und Foren zu Computer, IT, Wissenschaft, Medien und Politik. Preisvergleich von Hardware un...
```

### Ftp

To be written...

- responseTime

### SFtp

To be written...

- responseTime

### SNMP

To be written...

Makes monitoring any network device like printer... possible.

### IPMI

### Certificate

To be written...

- validTime
- keySize


Daemon Sensors
-------------------------------------------------

### PID

To be written...

cat /proc/PID/cmdline
cat /proc/PID/status

### PostgreSQL

To be written...

https://wiki.postgresql.org/wiki/Monitoring

### Apache

To be written...

mod_status:

- The number of worker serving requests
- The number of idle worker
- A total number of accesses and byte count served (*)
- The time the server was started/restarted and the time it has been running for
  Averages giving the number of requests per second, the number of bytes served per second and the average number of bytes per request (*)

analysis

- The current hosts and requests being processed (*)

### Tomcat

To be written...

Maybe use JMX... https://www.npmjs.com/package/jmx

### Wowza

To be written...

Parsing stats page

### VMWare

To be written...

http://searchitchannel.techtarget.com/feature/Monitoring-vSphere-performance-with-command-line-tools


Data Sensors
-------------------------------------------------

### Log

To be written...

- filter
- timerange

- num lines
- filtered lines
- comment

- list of lines

### Database

To be written...

SELECT COUNT(*) AS NUM, LAST(date) AS comment FROM


Simulation Sensors
-------------------------------------------------

### Web Session

To be written...

http://casperjs.org/

### Streaming

To be written...


Info Analyzer Sensors
-------------------------------------------------

This sensors are not build to run continuously but to run once to gather information
about a more unknown system.

### Hardware

1. lshw -json
2. dmidecode
3. lscpu
   lspci
   lsusb

cat /proc/cpuinfo
cat /proc/diskstats

### Software

cat /proc/version
running daemons


### Network Settings

/proc/sys/kernel/domainname
/proc/sys/kernel/hostname

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



    mon_sensor_cpu_all # delete after 3 days
    F check_id
      start (datetime)
      end (datetime)
      status (enum)
      message (text)
      xxx1 (value1 type)
      xxx2

    mon_sensor_cpu_hour # delete after 1 week
    F check_id
      date (string)
      num (int)
      status (float)
      statusMin (enum)
      statusMax (enum)
      xxx (text)
      xxxAvg (float)
      xxxMin (float)
      xxxMax (float)

    mon_sensor_cpu_day # delete after 6 months
    mon_sensor_cpu_week # delete after 5 years



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
- controller daemon
- add over time report (from db store)
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

monitor
=================================================

This application will make server management easy and fast. It will check the
whole IT landscape from the host to the application. While most monitoring
tools has it's focus on the server here the focus lies more on the application
side.

Usage
-------------------------------------------------
After the monitor and it's controllers are fully configured it may be run by
only calling:

    > monitor

    Run sensors once...

    Tue Oct 14 2014 08:20:21 GMT+0200 (CEST) - ekz:onepointvm:memory - ok
    Tue Oct 14 2014 08:20:21 GMT+0200 (CEST) - ekz:onepointvm - ok
    Tue Oct 14 2014 08:20:21 GMT+0200 (CEST) - ekz:onepointvm:diskfree - ok

    Done => ok

This will start the monitor on the command line and check all controllers. For each
controller a line is printed with it's status.
If a controller got a problem it will give a detailed report on the console.

Global options:

    -C, --nocolors  turn of color output
    -v, --verbose   run in verbose mode
    -h, --help      Show help

### Show controllers

Use the `-l` or `--list` option to list all possible configured controllers or
`-t`, `--tree`, `-r`, `--reverse` to get the same as tree view. Additionally
`-v` may be used to get some descriptive information.

    > monitor -l

    List of controllers

    - ekz:onepointvm - onepoint server
    - ekz:onepointvm:cpu - CPU activity on server onepoint
    - ekz:onepointvm:diskfree - Free diskspace on server onepoint
    - ekz:onepointvm:memory - Free memory on server onepoint
    - ekz:onepointvm:upgrade - Security upgrades on server onepoint
    - plusserver:vz23761:ping - Local ping on server vz23761

    Done.

    > monitor -t

    Tree view of controllers showing what is checked

    - ekz:onepointvm - onepoint server
      - ekz:onepointvm:cpu - CPU activity on server onepoint
      - ekz:onepointvm:memory - Free memory on server onepoint
      - ekz:onepointvm:diskfree - Free diskspace on server onepoint
      - ekz:onepointvm:upgrade - Security upgrades on server onepoint
    - plusserver:vz23761:ping - Local ping on server vz23761

    Done.

    > monitor -r

    Reverse tree of controllers showing area of damage

    - host:ekz:onepoint:cpu - CPU activity on server onepoint
      - host:ekz:onepoint - onepoint server
        - service:manage:apache - apache for manage tools
          - service:manage - manage tools
          - service:manage:https - access for manage tools
            - service:manage - manage tools

    Done.

### Run specific controller

It's also possible to only run specific controller if they are given as additional
parameters like:

    > monitor ekz:onepointvm:cpu

    Run sensors once...

    Tue Oct 14 2014 08:20:21 GMT+0200 (CEST) - ekz:onepointvm:cpu - ok

    Done => ok

Keep in mind that dependend controllers will run, too.


Display information
-------------------------------------------------

### Status

The monitor and controllers use the following status:

- __running__ if the sensor is already analyzing, you have to wait
- __disabled__ if this controller is currently not checked - this will be used
  like ok for further processing
- __ok__ if everything is perfect, there nothing have to be done - exit code 0
- __warn__ if the sensor reached the warning level, know you have to keep an eye on
  it - exit code 1
- __fail__ if the sensor failed and there is a problem - exit code 2


Configuration
-------------------------------------------------
As described above it may be accessed at `/etc/alinex-monitor/config` but it's
real path is in the application's directory `var/local/config`.


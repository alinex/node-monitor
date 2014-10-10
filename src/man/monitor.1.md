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

This will start the monitor on the command line and check all controllers. For each
controller a line is printed with it's status.
If a controller got a problem it will give a detailed report on the console.


### Status

The monitor and controllers use the following status:

__running__ if the sensor is already analyzing, you have to wait

__disabled__ if this controller is currently not checked - this will be used
like ok for further processing

__ok__ if everything is perfect, there nothing have to be done - exit code 0

__warn__ if the sensor reached the warning level, know you have to keep an eye on
it - exit code 1

__fail__ if the sensor failed and there is a problem - exit code 2


Configuration
-------------------------------------------------
As described above it has may be accessed through `/etc/alinex-monitor/config` but it's
real path is in the application's directory `var/local/config`.

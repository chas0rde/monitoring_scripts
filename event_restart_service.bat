@ECHO OFF
REM Script: event_restart_service
REM Author: Ingo Pohlschneider
REM Version 0.1
REM Desc: This script tries to restart a Windows service. It is used by the eventhandler of a monitoring system
REM       like Nagios or Icinga to restart a service when a problem was detected.
REM
REM Syntax: event_restart_service.cmd <service name> [ <caller name> ]

IF %1=="" GOTO NOSERVICE
IF %2=="" GOTO CHECKSERVICE
SET caller=Called by %2
ECHO %caller%

:CHECKSERVICE
sc query %1 > NUL
IF ERRORLEVEL 1060 GOTO SERVICENONEXISTEND
ECHO Checking current service state of %1
sc query %1 | find /I "STATE" | find "STOPPED" > NUL
IF errorlevel 1 GOTO SERVICERUNNING
ECHO Service %1 is currently stopped
GOTO RESTART

:SERVICERUNNING
ECHO Service %1 is already running. Exiting
eventcreate /t Information /id 771 /l application /d "Eventhandler: Restart of service %1 was requested, but service is already running. Exiting. %caller%" /so "%0" > NUL
GOTO END

:RESTART
ECHO Trying to restart service %1
eventcreate /t Information /id 771 /l application /d "Eventhandler: Restarting of service %1. %caller%" /so "%0" > NUL

net start %1 || GOTO ERROR > NUL

eventcreate /t Information /id 770 /l application /d "Eventhandler: Restart of service %1 successful. %caller%" /so "%0" > NUL
GOTO END

:ERROR
ECHO Restart of service %1 failed
eventcreate /t Critical /id 777 /l application /d "Eventhandler: Restart of service %1 failed. %caller%" /so "%0" > NUL
GOTO END

:NOSERVICE
ECHO No service to restart was supplied
eventcreate /t Information /id 771 /l application /d "No service to restart was supplied" /so "%0" > NUL
GOTO END

:SERVICENONEXISTEND
ECHO The service %1 was not found. Restart aborted.
eventcreate /t Information /id 771 /l application /d "The service %1 was not found. Restart aborted." /so "%0" > NUL

:END

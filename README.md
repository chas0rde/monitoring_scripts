# monitoring_scripts
Monitoring scripts for Nagios/Icinga

Various monitoring scripts for Nagios and/or Icinga

Tested on ubuntu linux

Free to use and alter.

Improvements are welcome :)

#Included scripts

##check_http_ntlm 
Check script for websites that use NTLM-based authentication.
Mimics check_http outputs

##check_smbshare_auth
Check script for smbshares using authentication to check the access of a certain user.
Writes a test-file to the share, reads it and does a diff. Afterwards the file is deleted.

##event_restart_service
Batch script to restart a windows service by its name. Checks if the service exists and is currently stopped.
If those conditions are true a restart of the service is attempted. 
Error messages and informational messages are posted to the console and the Windows Eventlog

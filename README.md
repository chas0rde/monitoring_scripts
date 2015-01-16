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

#!/bin/bash
#########################################################################
#
# File:         check_http_ntlm.sh
# Description:  Nagios check plugin to check a website that requires NTLM authentication via HTTP
# Language:     GNU Bourne-Again SHell
# Version:	1.0.0
# Date:		2015-01-15
# Author:	info@chas0r.de
#########################################################################
unset LANG

DEBUG=0

case "$(uname -s)"
	in
	SunOS)
	Echo="echo"
	;;
	Linux)
	Echo="echo -e"
	;;
	*)
	Echo="echo"
	;;
esac

print_help_msg(){
	print_version
	$Echo "Usage: $0 -h to get help."
	$Echo 
	$Echo 'Repository at https://github.com/chas0rde/monitoring_scripts'
        $Echo 'Report bugs to: info@chas0r.de'

}

print_full_help_msg(){
	print_version
	$Echo "Usage:"
	$Echo "$0 [-s search_string ] [ -h display help ] [ -v debug-level output ] -u username  -p password  <url> "
	$Echo 
	$Echo 'Repository at https://github.com/chas0rde/monitoring_scripts'
	$Echo 'Report bugs to: info@chas0r.de'

}

print_version(){
	$Echo $(cat $0 | head -n 7 | tail -n 1|sed 's/\# //')
}

cleanup(){
	/bin/rm -f $FILEHEADER
	/bin/rm -f $FILECONTENT
}

if [ $# -lt 1 ]; then
	print_help_msg
	exit 3
else
while getopts :s:u:p:P:hv OPTION
	do
		case $OPTION
			in
			u)
			USER="$OPTARG"
			;;
			p)
			PASS="$OPTARG"
			;;
			s)
			SEARCHSTRING="$OPTARG"
			;;
			v)
			DEBUG=1
			;;
			h)
			print_full_help_msg
			exit 3
			;;
			?)
			$Echo "Error: Illegal Option."
			print_help_msg
			exit 3
			;;
		esac
	done
fi
shift $(($OPTIND - 1))
URL=$1

if [ "$USER" == "" ]; then
	STATUS="Required attribute username (-u) not supplied. Aborting"
	$Echo $STATUS
	exit 2
fi
if [ "$PASS" == "" ]; then
	STATUS="Required attribute password (-p) not supplied. Aborting"
	$Echo $STATUS
	exit 2
fi
if [ "$URL" == "" ]; then
	STATUS="Required attribute url not supplied. Aborting"
	$Echo $STATUS
	exit 2
fi

command -v curl >/dev/null 2>&1 || { echo >&2 "curl is required but it's not installed.  Aborting."; exit 4; }
command -v flip >/dev/null 2>&1 || { echo >&2 "flip is required but it's not installed.  Aborting."; exit 4; }

if [ $DEBUG == 1 ]; then
	if [ "$USER"  != "" ]; then
		$Echo "User is $USER"
	fi
	if [ "$PASS" != "" ]; then
		$Echo "Password is $PASS"
	fi
	if [ "$SEARCHSTRING" != "" ]; then
		$Echo "Searchstring is $SEARCHSTRING"
	fi
	$Echo "URL is $URL"
	$Echo
fi

cd /tmp
FILEHEADER=/tmp/check_http_ntlm_header$$
FILECONTENT=/tmp/check_http_ntlm_content$$

PERF="$(/usr/bin/curl -s -S --ntlm -L -w "%{size_download}-%{time_total}" -o $FILECONTENT -D $FILEHEADER -u $USER:$PASS $URL)"
STATUSMSG="$(grep -e ^HTTP/ $FILEHEADER|tail -n1| sed -e 's/\r//')"
SIZE=$($Echo ${PERF%-*})
TIME=$($Echo ${PERF#*-}|sed -e 's/\./,/')

STATUSCODE=$($Echo $STATUSMSG | grep -oP "\d{3}")

if [ $DEBUG == 1 ]; then
	$Echo "Last status message was $STATUSMSG"
	$Echo "Last statuscode was $STATUSCODE"
	$Echo "Perfdata was $PERF"
	$Echo "Total $SIZE bytes downloaded"
	$Echo "Total time was $TIME s"
	$Echo
	$Echo "Header ($FILEHEADER) was:"
	cat $FILEHEADER
	$Echo
	$Echo "Content ($FILECONTENT) was:"
	cat $FILECONTENT
	$Echo
fi

if [ $STATUSCODE -lt 400 ]; then
	if [ "$SEARCHSTRING" != "" ]; then
		
		if ! grep -q $SEARCHSTRING $FILECONTENT; then
			cleanup
			$Echo "CRITICAL: Searchstring $SEARCHSTRING not found in content"
			exit 2
		fi
	fi
	cleanup
	$Echo "HTTP OK: $STATUSMSG - $SIZE bytes in $TIME seconds response time|time=${TIME}s;;;;0,000000 size=${SIZE}B;;;0"
else 
	cleanup
	$Echo "HTTP CRITICAL: $STATUSMSG"
	exit 2
fi

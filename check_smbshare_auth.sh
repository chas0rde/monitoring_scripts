#!/bin/bash
#########################################################################
#
# File:         check_smbshare.sh
# Description:  Nagios check plugin to check write access to a SMB fileshare.
# Language:     GNU Bourne-Again SHell
# Version:	1.0.0
# Date:		2015-01-15
# Author:	info@chas0r.de
#########################################################################
unset LANG

TESTFILE=$(hostname)_$$.txt
RESPFILE=RESP_$(hostname)_$$.txt
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
        $Echo 'Report bugs to: info@chas0r.de'

}

print_full_help_msg(){
	print_version
	$Echo "Usage:"
	$Echo "$0 [ -u username ] [ -p password ] [-d domain ] [ -h ] <path> "
	$Echo 
	$Echo 'Report bugs to: info@chas0r.de'

}

print_version(){
	$Echo $(cat $0 | head -n 7 | tail -n 1|sed 's/\# //')
}

if [ $# -lt 1 ]; then
	print_help_msg
	exit 3
else
while getopts :u:p:d:hv OPTION
	do
		case $OPTION
			in
			u)
			SMBUSER="$OPTARG"
			;;
			p)
			SMBPASS="$OPTARG"
			;;
			d)
			SMBDOMAIN="$OPTARG"
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
SMBPATH=$1

cd /tmp

if [ $DEBUG == 1 ]; then
	if [ "$SMBUSER"  != "" ]; then
		$Echo "User is $SMBUSER"
	fi
	if [ "$SMBPASS" != "" ]; then
		$Echo "Password is set $SMBPASS"
	fi
	if [ "$SMBDOMAIN" != "" ]; then
		$Echo "Domain is $SMBDOMAIN"
	fi
	$Echo "Path is $SMBPATH"
	$Echo
fi

if [ "$SMBPATH" == "" ]; then
	$Echo "Path is missing"
	Exit 4
fi

date >> $TESTFILE
$Echo "Monitoring Write-Test for SMB-Check by $(hostname)" >> $TESTFILE
$Echo "Destination share $SHARE" >> $TESTFILE

RET=0
STRING="OK - Testfile was written to share $SMBPATH successfully"
FAILSTRING="CRITICAL - Error writing testfile to share $SMBPATH."
if [ "$SMBUSER" != "" ]; then
	FAILSTRING="$FAILSTRING User: $SMBUSER"
fi
SMBCLIENT="/usr/bin/smbclient"

if [ "$SMBDOMAIN" != "" ]; then
	SMBCLIENT="$SMBCLIENT -W $SMBDOMAIN"
	if [ $DEBUG == 1 ]; then
		$Echo "Domain $SMBDOMAIN added to smb-command"
	fi
fi

if [ "$SMBUSER" != "" ]; then
	if [ "$SMBPASS" != "" ]; then
		SMBCLIENT="$SMBCLIENT -U $SMBUSER%$SMBPASS"
		if [ $DEBUG == 1 ]; then
			$Echo "User $SMBUSER and password added to smb-command"
		fi
	else
		$Echo "Password missing"
	fi
fi

SMBCLIENT="$SMBCLIENT $SMBPATH"


if [ $DEBUG == 1 ]; then
	$Echo "Final command is $SMBCLIENT"
	$Echo "Writing $TESTFILE"
	$Echo "Response file $RESPFILE"
	$Echo
fi

if [ $DEBUG == 1 ]; then
	$SMBCLIENT -c "put $TESTFILE" && $Echo
	$SMBCLIENT -c "get $TESTFILE $RESPFILE" && $Echo
	$Echo "Source"
	cat $TESTFILE && $Echo
	$Echo "Destination"
	cat $RESPFILE && $Echo
	/usr/bin/diff -a $TESTFILE $RESPFILE || STRING=$FAILSTRING RET=2
	$SMBCLIENT -c "del $TESTFILE" && $Echo
else
	$SMBCLIENT -c "put $TESTFILE" 2> /dev/null 1> /dev/null
	$SMBCLIENT -c "get $TESTFILE $RESPFILE" 2> /dev/null 1> /dev/null
	/usr/bin/diff -a $TESTFILE $RESPFILE 2> /dev/null 1>/dev/null|| STRING=$FAILSTRING RET=2
	$SMBCLIENT -c "del $TESTFILE" 2> /dev/null 1> /dev/null
fi

/bin/rm -f $RESPFILE
/bin/rm -f $TESTFILE

echo $STRING
exit $RET

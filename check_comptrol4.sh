#!/bin/bash
#
#################################################################################
#                                                                               #
#      Helper script for monitoring AC connected to Comptrol4Web via modbus TCP #
#                      created by Ingo Pohlschneider <http://www.chas0r.de>     #
#                                                        Version 0.02 / 2020    #
#################################################################################

# Changelog
# Date          Author                  Version         Comment
# 2020-07-06    I.Pohlschneider         0.01            Initial version
# 2020-07-21    I.Pohlschneider         0.02            Added Sequencing check and threshold-support


# Define global varibales
# ======================================
#
# Check if run via bash instead of other environment
if [ ! "$BASH_VERSION" ] ; then
    echo "Please do not use sh to run this script ($0), just execute it directly" 1>&2
    exit 1
fi
# Programm, version and author information
PROGNAME=`basename $0`
VERSION="Version 0.02"
AUTHOR="Ingo Pohlschneider (http://www.chas0r.de)"

# Date Format
HUMAN_DATE=`date "+%Y-%m-%d %H:%M"`

# Needed Packages
CHECK_MODBUS_BIN="/usr/local/bin/check_modbus"

# THRESHOLDS
TEMP_WARN_DIFF=3
TEMP_CRIT_DIFF=5

# Define the exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
EXITCODE=0

# Gernerate menue
# ======================================
#
print_version() {
    printf "$PROGNAME $VERSION $AUTHOR"
}


print_help() {
    print_version $PROGNAME $VERSION
    echo ""
    echo "$PROGNAME - Monitor AC system via CompTrol4web with modbus TCP"
    echo ""
    echo "$PROGNAME is a Nagios/Icinga plugin for checking the status of AC systems via CompTrol4web using modbus TCP"
    echo ""
    echo "Usage: $PROGNAME -H <HOSTNAME> -m <CHECK MODE: acstate | sequencing> -a <START REGISTER> -l <LABEL> -w <WARNING TRHESHOLD> -c <CRITICAL THRESHOLD>"
    echo ""
    echo "Parameter:"
    echo "  -H"
    echo "     Define the REMOTE Host, e.g. -H 192.168.6.71";
    echo "  -m"
    echo "     Define the check mode:";
    echo "       acstate    = overall status of a single AC unit";
    echo "       sequencing = number of active units in sequencing scenario";
    echo "  -a"
    echo "     Define the start-register for read  (comma-separated list for check-mode sequencing, single value for acstate)";
    echo "  -l"
    echo "     Label for the AC unit (comma-separated list for check-mode sequencing)";
    echo "  -w"
    echo "     Warning threshold. Syntax depending on check-mode:";
    echo "       acstate    = threshold for inlet temperature";
    echo "                    If no value is given a delta to setpoint temperature is calculated";
    echo "       sequencing = number of active units expected";
    echo "  -c"
    echo "     Critical threshold. Syntax depending on check-mode:";
    echo "       acstate    = threshold for inlet temperature";
    echo "                    If no value is given a delta to setpoint temperature is calculated";
    echo "       sequencing = number of active units expected";
    echo "  -h"
    echo "     This help"
    echo "  -v"
    echo "     Version"
    echo ""
    echo ""
    echo "Examples:"
    echo "   e.g. ./$PROGNAME  -H 192.168.6.71 -m acstate -a 1 -l UPS-AC -w 24 -c 27"
    echo "   e.g. ./$PROGNAME  -H 192.168.6.71 -m sequencing -a 1,16385,32769 -l Server1,Server2,Server3 -w 2 -c 1"
    echo ""
    exit $STATE_UNKNOWN
}

# Check if an paramater is given
if [ -z $1 ]; then
    echo $usage
    print_help
    exit $e_unknown
fi

# Check for parameters
while test -n "$1"; do
    case "$1" in
                -h)
                        print_help
                        exit $STATE_UNKNOWN
                        ;;
                -m)
                        CHECK_MODE=$2
                        shift
                        ;;
                -v)
                        print_version
                        exit $STATE_OK
                        ;;
                -H)
                        REMOTE_SERVER=$2
                        shift
                        ;;
                -a)
                        START_REGISTER=$2
                        shift
                        ;;
                -w)
                        WARN_THRESHOLD=$2
                        shift
                        ;;
                -c)
                        CRIT_THRESHOLD=$2
                        shift
                        ;;
                -l)
                        LABEL=$2
                        shift
                        ;;
                *)
                        print_help
                        ;;

        esac
        shift
done

# Check for Procs
# ======================================

if [ ! -f $CHECK_MODBUS_BIN ]; then
        printf "Failure: Programm $CHECK_MODBUS_BIN not found. Please install on the system the needed binary"
        exit $STATE_UNKNOWN
fi

# Check for given Hostanme
# ======================================
if [ "$REMOTE_SERVER" = "" ]; then
        printf "Error: >> Hostname and URL not given <<. Please specify a hostname, e.g. -H 192.1687.6.71";
        exit $STATE_UNKNOWN
fi

# Check for given start register
# ======================================
if [ "$START_REGISTER" = "" ]; then
        printf "Error: >> No start register was given << Please specify a start register to poll";
        exit $STATE_UNKNOWN
fi

# Check for given label
# ======================================
if [ "$LABEL" = "" ]; then
        printf "Error: >> No Label for the AC was given << Please specify a label for the AC system";
        exit $STATE_UNKNOWN
fi

# Check for valid check_mode
# ======================================
if [ "$CHECK_MODE" = "" ]; then
        printf "Error: >> No check mode was given << Please specify a check mode";
        exit $STATE_UNKNOWN
fi
if [ ! "$CHECK_MODE" = "acstate" ] && [ ! "$CHECK_MODE" = "sequencing" ]; then
        printf "Error: >> Invalid check mode $CHECK_MODE was given << Please specify a valid check mode";
        printf $usage
        print_help
        exit $STATE_UNKNOWN
fi

# Check mode acstate
if [ "$CHECK_MODE" = "acstate" ]; then

        # Check if START_REGISTER and LABEL are single values. If not this is not supported
        re='^[0-9]+$'
        if ! [[ $START_REGISTER =~ $re ]]; then
                printf "Error: >> Invalid start register for check mode $CHECK_MODE was given << Please specify a single numeric value if using acstate check mode";
                printf $usage
                print_help
                exit $STATE_UNKNOWN
        fi
        if [[ $LABEL == *","* ]]; then
                printf "Error: >> Invalid label for check mode $CHECK_MODE was given << Please specify a single value if using acstate check mode";
                printf $usage
                print_help
                exit $STATE_UNKNOWN
        fi

        OUTPUT="AC system $LABEL is ok"

        AC_RUNNING_STATE=$($CHECK_MODBUS_BIN -H $REMOTE_SERVER -a $START_REGISTER -f 3 | awk -F ": " '{print $2}' | awk '{gsub(/[ \t]+$/,""); print $0 }')
        AC_RUNNING_MODE=$($CHECK_MODBUS_BIN -H $REMOTE_SERVER -a $(($START_REGISTER+1)) -f 3 | awk -F ": " '{print $2}'| awk '{gsub(/[ \t]+$/,""); print $0 }')
        AC_FAN_LEVEL=$($CHECK_MODBUS_BIN -H $REMOTE_SERVER -a $(($START_REGISTER+2)) -f 3 | awk -F ": " '{print $2}'| awk '{gsub(/[ \t]+$/,""); print $0 }')
        AC_LOUVER_POSITION=$($CHECK_MODBUS_BIN -H $REMOTE_SERVER -a $(($START_REGISTER+3)) -f 3 | awk -F ": " '{print $2}'| awk '{gsub(/[ \t]+$/,""); print $0 }')
        AC_TEMP_SETPOINT=$($CHECK_MODBUS_BIN -H $REMOTE_SERVER -a $(($START_REGISTER+4)) -f 3 | awk -F ": " '{print $2}'| awk '{gsub(/[ \t]+$/,""); print $0 }')
        AC_TEMP_INLET=$($CHECK_MODBUS_BIN -H $REMOTE_SERVER -a $(($START_REGISTER+5)) -f 3 | awk -F ": " '{print $2}'| awk '{gsub(/[ \t]+$/,""); print $0 }')
        AC_ERROR_CODE=$($CHECK_MODBUS_BIN -H $REMOTE_SERVER -a $(($START_REGISTER+11)) -f 3 | awk -F ": " '{print $2}'| awk '{gsub(/[ \t]+$/,""); print $0 }')

        # Switch AC_RUNNING_STATE
        if [ "$AC_RUNNING_STATE" -eq "1" ]; then
        AC_RUNNING_STATE_STRING="ON"
        else
        AC_RUNNING_STATE_STRING="OFF"
        fi

        # Switch AC_RUNNING_MODE
        case "$AC_RUNNING_MODE" in
        "0") 
                AC_RUNNING_MODE="AUTO"
                ;;
        "1")   
                AC_RUNNING_MODE="HEATING"
                ;;
        "2") 
                AC_RUNNING_MODE="DRY"
                ;;
        "3") 
                AC_RUNNING_MODE="FAN"
                ;;
        "4") 
                AC_RUNNING_MODE="COOLING"
                ;;
        *)
                AC_RUNNING_MODE="UNKNOWN"
                ;;
        esac

        # Switch AC_FAN_LEVEL
        case "$AC_FAN_LEVEL" in
        "1")   
                AC_FAN_LEVEL="LOW"
                ;;
        "2") 
                AC_FAN_LEVEL="MEDIUM"
                ;;
        "3") 
                AC_FAN_LEVEL="HIGH"
                ;;
        "4") 
                AC_FAN_LEVEL="ULTRA HIGH"
                ;;
        *)
                AC_FAN_LEVEL="UNKNOWN"
                ;;
        esac

        # Switch AC_LOUVER_POSITION
        case "$AC_LOUVER_POSITION" in
        "10 ") 
                AC_LOUVER_POSITION="SWING"
                ;;
        esac

        # Alter Temperatures
        AC_TEMP_SETPOINT=$(echo "scale=1; $AC_TEMP_SETPOINT / 10"|bc)
        AC_TEMP_INLET=$(echo "scale=1; $AC_TEMP_INLET / 10"|bc)
        # Create performance data
        PERFDATA1="ac_running_state=$AC_RUNNING_STATE;;;;"
        PERFDATA2="ac_temp_setpoint=$AC_TEMP_SETPOINT;;;; ac_temp_inlet=$AC_TEMP_INLET;$WARN_THRESHOLD;$CRIT_THRESHOLD;;"
 
        # Set Warn/Crit if Temperature difference between Setpoint and inlet is too high
        if [ ! "$WARN_THRESHOLD" = "" ] || [ ! "$CRIT_THRESHOLD" = "" ]; then
                if [ ! "$WARN_THRESHOLD" = "" ] && [ ! "$CRIT_THRESHOLD" = "" ]; then
                
                        if [ $(echo "$AC_TEMP_INLET > $CRIT_THRESHOLD" |bc -l) -eq 1 ]; then
                                if [ "$AC_RUNNING_STATE" -eq "1" ]; then
                                        EXITCODE=2
                                        OUTPUT="CRITICAL: Inlet temperature ($AC_TEMP_INLET °C) too high (Threshold $CRIT_THRESHOLD °C)"
                                else
                                        EXITCODE=1
                                        OUTPUT="WARNING: Inlet temperature ($AC_TEMP_INLET °C) too high (Critical Threshold $CRIT_THRESHOLD °C) but unit is currently not running (possibly due to sequencing)"
                                fi
                        elif [ $(echo "$AC_TEMP_INLET >= $WARN_THRESHOLD" |bc -l) -eq 1 ]; then                               
                                EXITCODE=1
                                OUTPUT="WARNING: Inlet temperature ($AC_TEMP_INLET °C) high (Threshold $WARN_THRESHOLD °C)"
                        fi
                elif [ ! "$WARN_THRESHOLD" = "" ]; then
                        if [ $(echo "$AC_TEMP_INLET > $WARN_THRESHOLD" |bc -l) -eq 1  ]; then                               
                                EXITCODE=1
                                OUTPUT="WARNING: Inlet temperature ($AC_TEMP_INLET °C) high (Threshold $WARN_THRESHOLD °C)"
                        fi        
                else
                        if [ $(echo "$AC_TEMP_INLET > $CRIT_THRESHOLD" |bc -l) -eq 1  ]; then
                                EXITCODE=2
                                OUTPUT="CRITICAL: Inlet temperature ($AC_TEMP_INLET °C) too high (Threshold $CRIT_THRESHOLD °C)"
                        fi
                fi
        else
        # No thresholds given. Using predefined deltas to setpoint as threshold
                TEMP_DIFF=`echo "$AC_TEMP_INLET $AC_TEMP_SETPOINT" | awk '{print $1-$2}'`
                if [ $(echo "$TEMP_DIFF >= $TEMP_CRIT_DIFF" |bc -l) -eq 1 ]; then
                        EXITCODE=2
                        OUTPUT="CRITICAL: Inlet temperature difference to setpoint is too high. \nInlet: $AC_TEMP_INLET \n Setpoint: $AC_TEMPSETPOINT \n Critical delta: $TEMP_CRIT_DIFF"
                elif [ $(echo "$TEMP_DIFF >= $TEMP_WARN_DIFF" |bc -l) -eq 1 ]; then
                        EXITCODE=1
                        OUTPUT="WARNING: Inlet temperature difference to setpoint is high. \nInlet: $AC_TEMP_INLET \n Setpoint: $AC_TEMPSETPOINT \n Critical delta: $TEMP_WARN_DIFF"
                fi
        fi

        # Set critical if error code is not 0
        if [ $AC_ERROR_CODE -ne "0" ]; then
        EXITCODE=2
        OUTPUT="CRITICAL: There is an error code: $($AC_ERROR_CODE). Check your system"
        fi

        LONGOUTPUT="Running State: $AC_RUNNING_STATE_STRING \nRunning Mode: $AC_RUNNING_MODE \nFanlevel: $AC_FAN_LEVEL \nLouver Positon: $AC_LOUVER_POSITION \nTempertature Setpoint: $AC_TEMP_SETPOINT °C \nCurrent inlet Temperature: $AC_TEMP_INLET °C \nError-Code: $AC_ERROR_CODE"
fi

# Check mode sequencing
if [ "$CHECK_MODE" = "sequencing" ]; then
        OUTPUT="AC system sequencing is ok"

        #Tokenize LABEL and START_REGISTER
        IFS=','; LABEL_TOKENIZED=( $LABEL )
        IFS=','; START_REGISTER_TOKENIZED=( $START_REGISTER )
        # Check if array sizes are the same
        if ! [ "${#LABEL_TOKENIZED[@]}" -eq "${#START_REGISTER_TOKENIZED[@]}" ]; then
                printf "Error: >> Number of labels must match number of start registers";
                printf $usage
                print_help
                exit $STATE_UNKNOWN
        fi

        # Determine running mode for each AC unit an count active units
        declare -i NUM_RUNNING_UNITS
        NUM_RUNNING_UNITS=0
        for unit in "${START_REGISTER_TOKENIZED[@]}"
        do
                :
                UNIT_RUNNING_STATE=$($CHECK_MODBUS_BIN -H $REMOTE_SERVER -a $unit -f 3 | awk -F ": " '{print $2}' | awk '{gsub(/[ \t]+$/,""); print $0 }')
                if [ $UNIT_RUNNING_STATE -eq 1 ]; then
                        NUM_RUNNING_UNITS+=1
                fi
        done

        OUTPUT+=" $NUM_RUNNING_UNITS ac units running"
        
        if [ ! "$WARN_THRESHOLD" = "" ] || [ ! "$CRIT_THRESHOLD" = "" ]; then
                if [ ! "$WARN_THRESHOLD" = "" ] && [ ! "$CRIT_THRESHOLD" = "" ]; then
                        if [ $(echo "$NUM_RUNNING_UNITS < $CRIT_THRESHOLD" |bc -l) -eq 1 ]; then
                                EXITCODE=2
                                OUTPUT="CRITICAL: AC unit sequencing in error. $NUM_RUNNING_UNITS of "${#START_REGISTER_TOKENIZED[@]}" units running"
                        elif [ $(echo "$NUM_RUNNING_UNITS < $WARN_THRESHOLD" |bc -l) -eq 1 ]; then                               
                                EXITCODE=1
                                OUTPUT="WARNING: AC unit sequencing deprecated. $NUM_RUNNING_UNITS of "${#START_REGISTER_TOKENIZED[@]}" units running"
                        fi
                elif [ ! "$WARN_THRESHOLD" = "" ]; then
                        if [ $(echo "$NUM_RUNNING_UNITS < $WARN_THRESHOLD" |bc -l) -eq 1 ]; then   
                                EXITCODE=1
                                OUTPUT="WARNING: AC unit sequencing deprecated. $NUM_RUNNING_UNITS of "${#START_REGISTER_TOKENIZED[@]}" units running"
                        fi        
                else
                        if [ $(echo "$NUM_RUNNING_UNITS < $CRIT_THRESHOLD" |bc -l) -eq 1  ]; then
                                EXITCODE=2
                                OUTPUT="CRITICAL: AC unit sequencing in error. $NUM_RUNNING_UNITS of "${#START_REGISTER_TOKENIZED[@]}" units running"
                        fi    
                fi
        else
                # No thresholds given.
                OUTPUT+=". Note: no thresholds given!"
        fi
        
        # Create performance data
        PERFDATA1="ac_sequencing_running_units=$NUM_RUNNING_UNITS;$WARN_THRESHOLD;$CRIT_THRESHOLD;0;"${#START_REGISTER_TOKENIZED[@]}""
fi

# Create output
printf "$OUTPUT|$PERFDATA1\n$LONGOUTPUT|$PERFDATA2"
exit $EXITCODE

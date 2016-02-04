#!/bin/bash

# Verify if this script is running as root and if not exit
if [ "$(id -u)" != "0" ]; then
        echo -n "\nERROR: This script must be run as root!\n" 1>&2
        exit 1
fi

# Prints usage
usage() {
        echo -e "\nUsage:"
        echo -e "-h\t\t\tThis help"
        echo -e "-s [seconds]\t\tSleep interval between tests (default is 10 seconds)\n"
        exit 0
}

# --------------------------------------------------------------------------------
# Set default options
# How many seconds to sleep between tests
update_interval=10
# --------------------------------------------------------------------------------

# Get command line arguments
while getopts ":s:h" opts; do
        case "${opts}" in
        s)
                update_interval=${OPTARG}
                ;;
        h | *)
                usage
                ;;
        esac
done

# Look for config file
if [ -e ./config.ini ]; then
        source ./config.ini
else
        echo -e "\nWARNING: config.ini not found, using defaults!\n";
        source ./config.ini.default
fi

# Verify if gpspipe is installed
if [ ! -x $gpspipe_bin ]; then
        echo -e "\ngpspipe binary not found or is not executable!\n";
        exit 1
fi

# Verify if gpsd is running
gpsd_pid=`ps cax | grep gpsd`
if [ $? -ne 0 ]; then
        echo -e "\nERROR: GPSD is not running, please make sure to start it!\n"
        exit 1
fi

# Start the loop
while true
do
        # Get GPS Data in JSON format from gpsd
        echo -ne "Looking for current location..."
        while true
        do
                tpv=$($gpspipe_bin -w -n 5 | grep -m 1 TPV | python -mjson.tool 2>/dev/null)
                lon=$(echo "$tpv" | grep "lon" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
                lat=$(echo "$tpv" | grep "lat" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
                
                if [ ! -z "$lon" -a ! -z "$lat" ]; then
                        break
                else
                        echo -ne "."
                fi
        done
        
        echo -e "Ok\n"
        
        gps_date=$(echo "$tpv" | grep "time" | cut -d: -f2 | cut -dT -f1 | cut -d, -f1 | tr -d ' ' | tr -d '"')
        gps_time=$(echo "$tpv" | grep "time" | cut -dT -f2 | cut -d. -f1 | cut -d, -f1 | tr -d ' ')
        alt=$(echo "$tpv" | grep "alt" | cut -d: -f2 | cut -d, -f1 | tr -d ' ' | awk '{print int($1)}')
        spd=$(echo "$tpv" | grep "speed" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
        track=$(echo "$tpv" | grep "track" | cut -d: -f2 | cut -d, -f1 | tr -d ' ' | awk '{print int($1)}')

        if [ -z "$alt" ]; then
                echo "WARNING: No GPS altitude - setting to 0 Meters"
                alt=0
        fi

        if [ -z "$spd" ]; then
                echo "WARNING: No GPS speed - setting to 0 km/h"
                spd=0
        fi

        if [ -z "$track" ]; then
                echo "WARNING: No GPS track - setting to 0 Degrees"
                track=0
        fi

        # Convert speed from meters per second to kilometers per hour
        spd=`echo $spd | awk '{print int($1 * 3.6)}'`

        # Print GPS Results
        echo -e "Date:\t\t$gps_date"
        echo -e "Time:\t\t$gps_time"
        echo -e "Longitude:\t$lon"
        echo -e "Latitude:\t$lat"
        echo -e "Altitude:\t$alt Meters"
        echo -e "Speed:\t\t$spd km/h"
        echo -e "Track:\t\t$track Degrees"

        echo -e "\nNOTE: Sleeping for $update_interval seconds..."
        update_interval_tmp="$update_interval"
        while [ $update_interval_tmp -gt 0 ]; do
                echo -ne "$update_interval_tmp...\033[0K\r"
                sleep 1
                : $((update_interval_tmp--))
        done
        echo "--------------------------------------------------------------------------------"

        # Clear all vars
        unset tpv
        unset gps_date
        unset gps_time
        unset lat
        unset lon
        unset alt
        unset spd
        unset track
done

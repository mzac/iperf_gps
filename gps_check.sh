#!/bin/bash

# Look for config file
if [ -e ./config.ini ]; then
        source ./config.ini
else
        echo -e "\nWARNING: config.ini not found, using defaults!";
        source ./config.ini.default
fi

# Verify if this script is running as root and if not exit
if [ "$(id -u)" != "0" ]; then
        echo -n "\nERROR: This script must be run as root!\n" 1>&2
        exit 1
fi

# Verify if gpspipe is installed
if [ ! -x $gpspipe_bin ]; then
        echo -e "\ngpspipe binary not found or is not executable!\n";
        exit 1
fi

# Verify if gpsd is running
gpsd_pid=`ps cax | grep gpsd`
if [ $? -ne 0 ]; then
        echo "\nERROR: GPSD is not running, please make sure to start it!\n"
        exit 1
fi

# Start the loop
while true
do
        # Get GPS Data in JSON format from gpsd
        tpv=$($gpspipe_bin -w -n 5 | grep -m 1 TPV | python -mjson.tool)
        gps_date=$(echo "$tpv" | grep "time" | cut -d: -f2 | cut -dT -f1 | cut -d, -f1 | tr -d ' ' | tr -d '"')
        gps_time=$(echo "$tpv" | grep "time" | cut -dT -f2 | cut -d. -f1 | cut -d, -f1 | tr -d ' ')
        lon=$(echo "$tpv" | grep "lon" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
        lat=$(echo "$tpv" | grep "lat" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
        alt=$(echo "$tpv" | grep "alt" | cut -d: -f2 | cut -d, -f1 | tr -d ' ' | awk '{print int($1)}')
        spd=$(echo "$tpv" | grep "speed" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
        track=$(echo "$tpv" | grep "track" | cut -d: -f2 | cut -d, -f1 | tr -d ' ' | awk '{print int($1)}')

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

        echo -e "Sleeping for $update_interval seconds..."
        echo "--------------------------------------------------------------------------------"
        sleep $update_interval

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

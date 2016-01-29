#!/bin/bash

# Location of gpspipe binary
gpspipe_bin="/usr/bin/gpspipe"

# Location of gpsd PID
gpsd_pid_file="/var/run/gpsd.pid"

# --------------------------------------------------------------------------------
# Do not change any settings below this line

# Verify if gpspipe is installed
if [ ! -x $gpspipe_bin ]; then
        echo -e "\ngpspipe binary not found or is not executable!\n";
        exit 1
fi

# Verify if gpsd is running
if [ -e $gpsd_pid_file ]; then
        gpsd_pid=`cat $gpsd_pid_file`
        if [ ! -e /proc/$gpsd_pid/exe ]; then
                echo "GPSD is not running, please make sure to start it!"
                exit 1
        fi
else
        echo "Cannot find GPSD PID file!"
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
  echo -e "Date:\t$gps_date"
  echo -e "Time:\t$gps_time"
  echo -e "Longitude:\t$lon"
  echo -e "Latitude:\t$lat"
  echo -e "Altitude:\t$alt"
  echo -e "Speed:\t$spd"
  echo -e "Track:\t$track"

  echo -e "Sleeping for $update_interval seconds...\n"
  sleep $update_interval
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

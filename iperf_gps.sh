#!/bin/bash

# How many seconds to run the iPerf test
iperf_test_interval=5

# How many seconds to sleep between tests
update_interval=10

# Location of iPerf binary
iperf_bin="/usr/bin/iperf"

# The port to connect to iPerf (5001 default)
iperf_port=5001

# How long to run the iPerf test
iperf_time=5

# Location of gpspipe binary
gpspipe_bin="/usr/bin/gpspipe"

# Location of gpsd PID
gpsd_pid_file="/var/run/gpsd.pid"

# --------------------------------------------------------------------------------
# Do not change any settings below this line

# iPerf server to connect to
iperf_server="$1"

# Verify if iPerf is installed
if [ ! -x $iperf_bin ]; then
        echo -e "\niPerf binary not found or is not executable!\n";
        exit 1
fi

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

# Verify that the iPerf server and base filename for output is specified
if [ -z $1 -a -z $2 ]; then
        echo -e "\nUsage:"
        echo -e "$0 <server_ip> <base_filename>\n"
        exit 1
fi

# Verify that the iPerf server is alive with ICMP
/bin/ping -c 1 -w 5 $1 > /dev/null
if [ $? -ne 0 ]; then
        echo "iPerf server $1 is down - via ICMP ping!"
        exit 1
fi

# Verify that the iPerf server is up
/bin/nc -z -v -w 5 $1 $iperf_port > /dev/null
if [ $? -ne 0 ]; then
        echo "iPerf server $1 on port $iperf_port is down!"
        exit 1
fi

# Set the timestamp and filename for the exported data
export_file_timestamp=`date +%Y-%m-%dT%H:%M:%S%z`
export_file_name="$1-$2-$export_file_timestamp.csv"

# Verify if the export file already exists
if [ ! -e "$export_file_name" ]; then
        touch "$export_file_name"
fi

# Verify that we can write to the export file
if [ ! -w "$export_file_name" ]; then
        echo "Cannot write to $export_file_name"
        exit 1
fi

# Print CSV header to console
echo "date,time,longitude,latitude,altitude,speed,track,iperf_server,iperf_test_interval,iperf_client_bytes,iperf_client_bps,iperf_server_bytes,iperf_server_bps" >> $export_file_name

echo -e "\nAt any time, press CRTL-C to stop the script"
echo -e "Writing to $export_file_name\n"
echo -e "GPS Data: time,lon,lat,alt,spd,track\n"

# Start the loop
while true
do

# Verify that the iPerf server is alive with ICMP
/bin/ping -c 1 -w 5 $1 > /dev/null
if [ $? -ne 0 ]; then
        echo "iPerf server $1 is down - via ICMP ping!"
else
        # Get GPS Data in JSON format from gpsd
        tpv=$($gpspipe_bin -w -n 5 | grep -m 1 TPV | python -mjson.tool)
        lon=$(echo "$tpv" | grep "lon" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
        lat=$(echo "$tpv" | grep "lat" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
        alt=$(echo "$tpv" | grep "alt" | cut -d: -f2 | cut -d, -f1 | tr -d ' ' | awk '{print int($1)}')
        spd=$(echo "$tpv" | grep "speed" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
        track=$(echo "$tpv" | grep "track" | cut -d: -f2 | cut -d, -f1 | tr -d ' ' | awk '{print int($1)}')
        gps_date=$(echo "$tpv" | grep "time" | cut -d: -f2 | cut -dT -f1 | cut -d, -f1 | tr -d ' ' | tr -d '"')
        gps_time=$(echo "$tpv" | grep "time" | cut -dT -f2 | cut -d. -f1 | cut -d, -f1 | tr -d ' ')

        # Convert speed from meters per second to kilometers per hour
        spd=`echo $spd | awk '{print int($1 * 3.6)}'`

        # Check if lon and lat are set
        if [ ! -z "$lon" -a ! -z "$lat" ]; then

                if [ -z "$alt" ]; then
                        echo "No alt - setting to 0"
                        alt=0
                fi
                if [ -z "$spd" ]; then
                        echo "No speed - setting to 0"
                        spd=0
                fi
                if [ -z "$track" ]; then
                        echo "No track - setting to 0"
                        track=0
                fi
                if [ $spd -le 1 ]; then
                        echo "Not moving - setting track to 0"
                        track=0
                fi

                # Create GPS result string
                gps_result="$gps_date,$gps_time,$lon,$lat,$alt,$spd,$track"

                echo "GPS Data: $gps_result"

                echo "Running iPerf test"
                iperf_result=`$iperf_bin -c $iperf_server -r -t $iperf_test_interval --reportstyle C`

                iperf_result_client=$(echo "$iperf_result" | head -1)
                iperf_result_server=$(echo "$iperf_result" | tail -1)

                iperf_result_client_bytes=$(echo "$iperf_result_client" | cut -d, -f8)
                iperf_result_server_bytes=$(echo "$iperf_result_server" | cut -d, -f8)

                iperf_result_client_bps=$(echo "$iperf_result_client" | cut -d, -f9)
                iperf_result_server_bps=$(echo "$iperf_result_server" | cut -d, -f9)

                echo "Writing results to file:"
                echo "$gps_date,$gps_time,$lon,$lat,$alt,$spd,$track,$iperf_server,$iperf_test_interval,$iperf_result_client_bytes,$iperf_result_client_bps,$iperf_result_server_bytes,$iperf_result_server_bps" | tee -a $export_file_name

        else
                echo "No GPS Fix!"
                echo $tpv
        fi
fi

echo -e "Sleeping for $update_interval seconds...\n"
sleep $update_interval

# Clear all vars
unset tpv
unset lat
unset lon
unset alt
unset spd
unset track
unset gps_date
unset gps_time
unset gps_result
unset iperf_result
unset iperf_result_server
unset iperf_result_client_bytes
unset iperf_result_server_bytes
unset iperf_result_client_bps
unset iperf_result_server_bps

done

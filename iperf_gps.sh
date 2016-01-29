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

# Verify if iPerf is installed
if [ ! -x $iperf_bin ]; then
        echo -e "\nERROR: iPerf binary not found or is not executable!\n";
        exit 1
fi

# Verify if gpspipe is installed
if [ ! -x $gpspipe_bin ]; then
        echo -e "\nERROR: gpspipe binary not found or is not executable!\n";
        exit 1
fi

# Verify if gpsd is running
if [ -e $gpsd_pid_file ]; then
        gpsd_pid=`cat $gpsd_pid_file`
        if [ ! -e /proc/$gpsd_pid/exe ]; then
                echo "ERROR: GPSD is not running, please make sure to start it!"
                exit 1
        fi
else
        echo "ERROR: Cannot find GPSD PID file!"
        exit 1
fi

# Verify that the iPerf server and base filename for output is specified
if [ -z $1 -a -z $2 ]; then
        echo -e "\nUsage:"
        echo -e "$0 <server_ip> <base_filename>\n"
        exit 1
else
        # iPerf server to connect to
        iperf_server="$1"
fi

# Verify that the iPerf server is alive with ICMP
echo -ne "\nRunning ICMP test to see if server is alive..."
/bin/ping -n -c 1 -w 5 $iperf_server > /dev/null
if [ $? -ne 0 ]; then
        echo "ERROR: iPerf server $iperf_server is down - via ICMP ping!"
        exit 1
else
        echo "Ok"
fi

# Verify that the iPerf server is up
echo -ne "Running Netcat test to see if iPerf is up on server..."
/bin/nc -z -v -w 5 $iperf_server $iperf_port 2> /dev/null
if [ $? -ne 0 ]; then
        echo "ERROR: iPerf server $iperf_server on port $iperf_port is down!"
        exit 1
else
        echo "Ok"
fi

# Set the timestamp and filename for the exported data
export_file_timestamp=`date +%Y-%m-%dT%H:%M:%S%z`
export_file_name="$iperf_server-$2-$export_file_timestamp.csv"

# Verify if the export file already exists
if [ ! -e "$export_file_name" ]; then
        touch "$export_file_name"
else
        echo "ERROR: File $export_file_name already exists!"
        exit 1
fi

# Verify that we can write to the export file
if [ ! -w "$export_file_name" ]; then
        echo "ERROR: Cannot write to $export_file_name"
        exit 1
fi

echo -e "Writing CSV data to $export_file_name\n"
echo "--------------------------------------------------------------------------------"

# Print CSV header to file
echo "date,time,longitude,latitude,altitude,speed,track,iperf_server,ping_min,ping_avg,ping_max,ping_mdev,iperf_test_interval,iperf_client_bytes,iperf_client_bps,iperf_server_bytes,iperf_server_bps" >> $export_file_name

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

        # Check if lon and lat are set
        if [ ! -z "$lon" -a ! -z "$lat" ]; then
                if [ -z "$alt" ]; then
                        echo "NOTE: No GPS altitude - setting to 0"
                        alt=0
                fi
                if [ -z "$spd" ]; then
                        echo "NOTE: No GPS speed - setting to 0"
                        spd=0
                fi
                if [ -z "$track" ]; then
                        echo "NOTE: No GPS track - setting to 0"
                        track=0
                fi
                if [ $spd -le 1 ]; then
                        echo "NOTE: Not moving - setting to 0"
                        track=0
                fi

                # Verify that the iPerf server is alive with ICMP, if not skip iperf test and set results to zero
                /bin/ping -n -c 1 -w 5 $iperf_server > /dev/null
                if [ $? -ne 0 ]; then
                        echo "iPerf server $iperf_server is down - via ICMP ping!"
                        
                        ping_result_min="0"
                        ping_result_avg="0"
                        ping_result_max="0"
                        ping_result_mdev="0"
                        
                        iperf_result_client_bytes="0"
                        iperf_result_server_bytes="0"
                        
                        iperf_result_client_bps="0"
                        iperf_result_server_bps="0"
                else
                        echo "Running ICMP test..."
                        ping_result=`/bin/ping -n -c 5 -w 5 -i 0.5 $iperf_server | tail -1 | cut -d ' ' -f 4`
                        ping_result_min=$(echo "$ping_result" | cut -d/ -f1)
                        ping_result_avg=$(echo "$ping_result" | cut -d/ -f2)
                        ping_result_max=$(echo "$ping_result" | cut -d/ -f3)
                        ping_result_mdev=$(echo "$ping_result" | cut -d/ -f4)
                        
                        echo "Running iPerf test..."
                        iperf_result=`$iperf_bin -c $iperf_server -r -t $iperf_test_interval --reportstyle C`

                        iperf_result_client=$(echo "$iperf_result" | head -1)
                        iperf_result_server=$(echo "$iperf_result" | tail -1)

                        iperf_result_client_bytes=$(echo "$iperf_result_client" | cut -d, -f8)
                        iperf_result_server_bytes=$(echo "$iperf_result_server" | cut -d, -f8)

                        iperf_result_client_bps=$(echo "$iperf_result_client" | cut -d, -f9)
                        iperf_result_server_bps=$(echo "$iperf_result_server" | cut -d, -f9)
                fi
                echo "Writing results to file:"
                echo "$gps_date,$gps_time,$lon,$lat,$alt,$spd,$track,$iperf_server,$ping_result_min,$ping_result_avg,$ping_result_max,$ping_result_mdev,$iperf_test_interval,$iperf_result_client_bytes,$iperf_result_client_bps,$iperf_result_server_bytes,$iperf_result_server_bps" | tee -a $export_file_name
        else
                echo -e "No GPS Fix!\nRaw GPS Data:"
                echo $tpv
        fi

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
        unset ping_result
        unset ping_result_min
        unset ping_result_avg
        unset ping_result_max
        unset ping_result_mdev
        unset iperf_result
        unset iperf_result_server
        unset iperf_result_client_bytes
        unset iperf_result_server_bytes
        unset iperf_result_client_bps
        unset iperf_result_server_bps

done

#!/bin/bash

source ./config.ini

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
                echo "\nERROR: GPSD is not running, please make sure to start it!\n"
                exit 1
        fi
else
        echo -e "\nERROR: Cannot find GPSD PID file!\n"
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

echo -e "\n--------------------------------------------------------------------------------"

# Verify that the iPerf server is alive with ICMP
echo -ne "NOTE: Running ICMP ping to see if server is alive..."
/bin/ping -n -c 1 -w 5 $iperf_server > /dev/null
if [ $? -ne 0 ]; then
        echo "ERROR: iPerf server $iperf_server is down - via ICMP ping!"
        exit 1
else
        echo "Ok"
fi

# Verify that the iPerf server is up
echo -ne "NOTE: Running Netcat test to see if iPerf is up on server..."
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
        echo "ERROR: File $export_file_name already exists or cannot create!"
        exit 1
fi

# Verify that we can write to the export file
if [ ! -w "$export_file_name" ]; then
        echo "ERROR: Cannot write to $export_file_name"
        exit 1
fi

echo -e "NOTE: Writing CSV data to $export_file_name"
echo "--------------------------------------------------------------------------------"

# Print CSV header to file
echo "test_id,date,time,longitude,latitude,altitude,speed,track,iperf_server,ping_min,ping_avg,ping_max,ping_mdev,iperf_test_interval,iperf_client_bytes,iperf_client_bps,iperf_server_bytes,iperf_server_bps" > $export_file_name

# Set test_id to zero
test_id=1

# Start the loop
while true
do
        # Get GPS Data in JSON format from gpsd
        tpv=$($gpspipe_bin -w -n 5 | grep -m 1 TPV | python -mjson.tool 2>/dev/null)
        gps_date=$(echo "$tpv" | grep "time" | cut -d: -f2 | cut -dT -f1 | cut -d, -f1 | tr -d ' ' | tr -d '"')
        gps_time=$(echo "$tpv" | grep "time" | cut -dT -f2 | cut -d. -f1 | cut -d, -f1 | tr -d ' ')
        lon=$(echo "$tpv" | grep "lon" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
        lat=$(echo "$tpv" | grep "lat" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
        alt=$(echo "$tpv" | grep "alt" | cut -d: -f2 | cut -d, -f1 | tr -d ' ' | awk '{print int($1)}')
        spd=$(echo "$tpv" | grep "speed" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
        track=$(echo "$tpv" | grep "track" | cut -d: -f2 | cut -d, -f1 | tr -d ' ' | awk '{print int($1)}')

        # Check if lon and lat are set
        if [ ! -z "$lon" -a ! -z "$lat" ]; then
                
                echo -e "NOTE: Test sequence number: $test_id"
                
                # Convert speed from meters per second to kilometers per hour
                spd=`echo $spd | awk '{print int($1 * 3.6)}'`
                
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
                
                if [ $spd -le 1 ]; then
                        echo "WARNING: Not moving - setting track to 0 Degrees"
                        track=0
                fi

                # Print GPS Results
                echo -e "\nGPS Date:\t\t$gps_date"
                echo -e "GPS Time:\t\t$gps_time"
                echo -e "GPS Longitude:\t\t$lon"
                echo -e "GPS Latitude:\t\t$lat"
                echo -e "GPS Altitude:\t\t$alt Meters"
                echo -e "GPS Speed:\t\t$spd km/h"
                echo -e "GPS Track:\t\t$track Degrees\n"

                # Verify that the iPerf server is alive with ICMP, if not skip iperf test and set results to zero
                echo -en "NOTE: Check if server is still alive..."
                /bin/ping -n -c 1 -w 5 $iperf_server > /dev/null
                if [ $? -ne 0 ]; then
                        echo "ERROR"
                        echo "ERROR: iPerf server $iperf_server is down - via ICMP ping, setting iPerf results to 0!"
                        
                        ping_result_min="0"
                        ping_result_avg="0"
                        ping_result_max="0"
                        ping_result_mdev="0"
                        
                        iperf_result_client_bytes="0"
                        iperf_result_server_bytes="0"
                        
                        iperf_result_client_bps="0"
                        iperf_result_server_bps="0"
                else
                        echo "Ok"
                        echo -ne "NOTE: Running ICMP test..."
                        ping_result=`/bin/ping -n -c 5 -w 5 -i 0.5 $iperf_server | tail -1 | cut -d ' ' -f 4`
                        if [ $? -eq 0 ]; then
                                echo -e "Ok\n"
                                ping_result_min=$(echo "$ping_result" | cut -d/ -f1)
                                ping_result_avg=$(echo "$ping_result" | cut -d/ -f2)
                                ping_result_max=$(echo "$ping_result" | cut -d/ -f3)
                                ping_result_mdev=$(echo "$ping_result" | cut -d/ -f4)
                                echo -e "Ping min:\t\t$ping_result_min ms"
                                echo -e "Ping avg:\t\t$ping_result_avg ms"
                                echo -e "Ping max:\t\t$ping_result_max ms"
                                echo -e "Ping mdev:\t\t$ping_result_mdev ms"
                        else
                                echo "ERROR"
                                ping_result_min="0"
                                ping_result_avg="0"
                                ping_result_max="0"
                                ping_result_mdev="0"
                        fi
                        
                        echo -ne "\nNOTE: Running iPerf test..."
                        iperf_result=`$iperf_bin -c $iperf_server -r -t $iperf_test_interval --reportstyle C`

                        echo -e "Ok\n"

                        iperf_result_client=$(echo "$iperf_result" | head -1)
                        iperf_result_server=$(echo "$iperf_result" | tail -1)

                        iperf_result_client_bytes=$(echo "$iperf_result_client" | cut -d, -f8)
                        iperf_result_server_bytes=$(echo "$iperf_result_server" | cut -d, -f8)

                        iperf_result_client_bps=$(echo "$iperf_result_client" | cut -d, -f9)
                        iperf_result_server_bps=$(echo "$iperf_result_server" | cut -d, -f9)
                        
                        echo -e "iPerf Client Bytes:\t$iperf_result_client_bytes"
                        echo -e "iPerf Server Bytes:\t$iperf_result_server_bytes"
                        echo -e "iPerf Client BPS:\t$iperf_result_client_bps"
                        echo -e "iPerf Server BPS\t$iperf_result_server_bps"
                fi
                echo -ne "\nNOTE: Writing results to file..."
                echo "$test_id,$gps_date,$gps_time,$lon,$lat,$alt,$spd,$track,$iperf_server,$ping_result_min,$ping_result_avg,$ping_result_max,$ping_result_mdev,$iperf_test_interval,$iperf_result_client_bytes,$iperf_result_client_bps,$iperf_result_server_bytes,$iperf_result_server_bps" >> $export_file_name
                if [ $? -eq 0 ]; then
                        echo "Ok"
                        ((test_id++))
                else
                        echo "ERROR: Cannot write to $export_file_name"
                        exit 1
                fi
        else
                echo "ERROR: No GPS fix, not running tests!"
        fi

        echo -e "NOTE: Sleeping for $update_interval seconds..."
        update_interval_tmp="$update_interval"
        while [ $update_interval_tmp -gt 0 ]; do
                echo -ne "$update_interval_tmp...\033[0K\r"
                sleep 1
                : $((update_interval_tmp--))
        done
        echo -e "--------------------------------------------------------------------------------\033[0K\r"

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

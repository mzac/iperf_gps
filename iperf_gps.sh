#!/bin/bash

# Verify if this script is running as root and if not exit
if [ "$(id -u)" != "0" ]; then
        echo -e "\nERROR: This script must be run as root\!\n"
        exit 1
fi

# Prints usage
usage() { 
        echo -e "\nUsage:"
        echo -e "$0 -i [server_ip]\n"
        echo -e "Required:\n"
        echo -e "-i [server_ip]\t\tIP Address or Hostname of the iPerf Server"
        echo -e "\nOptional:\n"
        echo -e "-h\t\t\tThis help"
        echo -e "-m\t\t\tRun through tests manually (no sleep)"
        echo -e "-p [port]\t\tiPerf port to connect to (default is 5001)"
        echo -e "-s [seconds]\t\tSleep interval between tests (default is 10 seconds)"
        echo -e "-t [seconds]\t\tHow long to run iPerf test (default is 5 seconds)"
        echo -e "-u\t\t\tRun iPerf with UDP tests (default is TCP)"
        echo -e "-w [base_filename]\tText that will be included in the filename\n"
        exit 0
}

# --------------------------------------------------------------------------------
# Set default options
# How many seconds to sleep between tests
update_interval=10

# The default iPerf server port
iperf_port=5001

# How long to run the iPerf test
iperf_test_interval=5

# Set manual run to 0
manual_run=0
# --------------------------------------------------------------------------------

# Get command line arguments
while getopts ":i:p:s:t:w:hmu" opts; do
        case "${opts}" in
        i)
                iperf_server=${OPTARG}
                ;;
        m)
                manual_run=1
                ;;
        p)
                iperf_port=${OPTARG}
                ;;
        s)
                update_interval=${OPTARG}
                ;;
        t)
                iperf_test_interval=${OPTARG}
                ;;
        u)
                iperf_mode="-u"
                ;;
        w)
                base_filename="${OPTARG}-"
                ;;
        h | *)
                usage
                ;;
        esac
done

# Verify if all required command line arguments are specified
if [ -z "$iperf_server" ]; then
        usage
fi

# Look for config file
if [ -e ./config.ini ]; then
        source ./config.ini
else
        echo -e "\nWARNING: config.ini not found, using defaults!";
        source ./config.ini.default
fi

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
gpsd_pid=`ps cax | grep gpsd`
if [ $? -ne 0 ]; then
        echo -e "\nERROR: GPSD is not running, please make sure to start it!\n"
        exit 1
fi


echo -e "\n--------------------------------------------------------------------------------"

# Verify if we have wifi and we want to use it
echo -ne "NOTE: Verify if have Wifi..."
wifi_list=`/bin/netstat -i | grep wlan | cut -d ' ' -f1 | tr '\n' ' '`
if [[ $wifi_list =~ .*wlan.* ]]; then
        echo -e "Ok\n"
        while read -p "NOTE: Use Wifi (y/n) [y]: " use_wifi; do
                if [ -z "$use_wifi" ]; then
                        use_wifi="y"
                fi
                case "$use_wifi" in
                        y*|Y*)
                                read -p "NOTE: Select Wifi interface to use (wlan0 default) [${wifi_list%?}]: " wifi_interface
                                if [ "$wifi_interface" = "" ]; then
                                        wifi_interface="wlan0"
                                        echo -e "NOTE: Setting Wifi interface to $wifi_interface...Ok"
                                        break
                                fi
                        ;;
                        n*|N*)
                                echo -e "NOTE: Not using Wifi...Ok"
                                break
                        ;;
                        *)
                                echo -e "ERROR: Invalid input!\n"
                        ;;
                esac
        done
else
        echo "No Wifi interfaces found!"
fi

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
export_file_name="$iperf_server-$base_filename$export_file_timestamp.csv"

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
echo "test_id,date,time,longitude,latitude,altitude,speed,track,iperf_server,wifi_bssid,wifi_ssid,wifi_freq,wifi_signal,wifi_tx_rate,wifi_rx_rate,ping_min,ping_avg,ping_max,ping_mdev,iperf_test_interval,iperf_client_bytes,iperf_client_bps,iperf_server_bytes,iperf_server_bps" > $export_file_name

# Set test_id to zero
test_id=1

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

        # Check if lon and lat are set
        if [ ! -z "$lon" -a ! -z "$lat" ]; then
                
                # If location found
                echo "Ok"
                
                # Get the rest of the GPS data
                gps_date=$(echo "$tpv" | grep "time" | cut -d: -f2 | cut -dT -f1 | cut -d, -f1 | tr -d ' ' | tr -d '"')
                gps_time=$(echo "$tpv" | grep "time" | cut -dT -f2 | cut -d. -f1 | cut -d, -f1 | tr -d ' ')
                alt=$(echo "$tpv" | grep "alt" | cut -d: -f2 | cut -d, -f1 | tr -d ' ' | awk '{print int($1)}')
                spd=$(echo "$tpv" | grep "speed" | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
                track=$(echo "$tpv" | grep "track" | cut -d: -f2 | cut -d, -f1 | tr -d ' ' | awk '{print int($1)}')

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

                # Verify if we have a Wifi connection
                wifi_disconnected=0
                if [ -n "$wifi_interface" ]; then
                        echo -ne "NOTE: Check if we are still connected to Wifi..."
                        wifi_connection_status=`/sbin/iw dev $wifi_interface link | grep "Connected to" | cut -d ' ' -f 1,2`
                        if [ "$wifi_connection_status" == "Connected to" ]; then
                                echo -e "Ok\n"
                                
                                # Get Wifi data
                                wifi_iw_link=`/sbin/iw dev $wifi_interface link`
                                wifi_bssid=`printf '%s\n' "$wifi_iw_link" | grep "Connected to" | cut -d ' ' -f3`
                                wifi_ssid=`printf '%s\n' "$wifi_iw_link" | grep "SSID" | cut -d ' ' -f2`
                                wifi_freq=`printf '%s\n' "$wifi_iw_link" | grep "freq" | cut -d ' ' -f2`
                                
                                wifi_iw_station_dump=`/sbin/iw dev $wifi_interface station dump`
                                wifi_signal=`printf '%s\n' "$wifi_iw_station_dump" | grep "signal:" | tr -d '\t' | cut -d ' ' -f3,4`
                                wifi_tx_rate=`printf '%s\n' "$wifi_iw_station_dump" | grep "tx bitrate:" | tr -d '\t' | awk -F':' '{print $NF}'`
                                wifi_rx_rate=`printf '%s\n' "$wifi_iw_station_dump" | grep "rx bitrate:" | tr -d '\t' | awk -F':' '{print $NF}'`
                                
                                echo -e "Wifi SSID:\t\t$wifi_ssid"
                                echo -e "Wifi BSSID:\t\t$wifi_bssid"
                                echo -e "Wifi Freq:\t\t$wifi_freq"
                                echo -e "Wifi Signal:\t\t$wifi_signal"
                                echo -e "Wifi TX Rate:\t\t$wifi_tx_rate"
                                echo -e "Wifi RX Rate:\t\t$wifi_rx_rate\n"
                        else
                                echo "ERROR!"
                                echo "ERROR: Wifi is disconnected, settings results to 0!"
                                wifi_disconnected=1
                        fi
                fi

                # Verify that the iPerf server is alive with ICMP, if not skip iperf test and set results to zero
                if [ $wifi_disconnected -ne 1 ]; then
                        echo -ne "NOTE: Check if server is still alive..."
                fi
                /bin/ping -n -c 1 -w 5 $iperf_server > /dev/null
                if [ $? -ne 0 ] || [ $wifi_disconnected -eq 1 ]; then
                        if [ $wifi_disconnected -ne 1 ]; then
                                echo "ERROR"
                                echo "ERROR: iPerf server $iperf_server is down - via ICMP ping, setting iPerf results to 0!"
                        fi
                        
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
                        
                        echo -ne "\nNOTE: Running iPerf test for $iperf_test_interval seconds..."
                        iperf_result=`$iperf_bin $iperf_mode -c $iperf_server -r -t $iperf_test_interval --reportstyle C`

                        echo -e "Ok\n"

                        iperf_result_client=$(echo "$iperf_result" | head -1)
                        iperf_result_server=$(echo "$iperf_result" | tail -1)

                        iperf_result_client_bytes=$(echo "$iperf_result_client" | cut -d, -f8)
                        iperf_result_server_bytes=$(echo "$iperf_result_server" | cut -d, -f8)

                        iperf_result_client_bps=$(echo "$iperf_result_client" | cut -d, -f9)
                        iperf_result_server_bps=$(echo "$iperf_result_server" | cut -d, -f9)
                        
                        iperf_result_client_mbps=`echo $iperf_result_client_bps | awk '{print int($1 / 1000000)}'`
                        iperf_result_server_mbps=`echo $iperf_result_server_bps | awk '{print int($1 / 1000000)}'`
                        
                        echo -e "iPerf Client Bytes:\t$iperf_result_client_bytes"
                        echo -e "iPerf Server Bytes:\t$iperf_result_server_bytes"
                        echo -e "iPerf Client BPS:\t$iperf_result_client_bps / $iperf_result_client_mbps Mbit/s"
                        echo -e "iPerf Server BPS\t$iperf_result_server_bps / $iperf_result_server_mbps Mbit/s"
                fi
                echo -ne "\nNOTE: Writing results to file [$export_file_name] ... "
                echo "$test_id,$gps_date,$gps_time,$lon,$lat,$alt,$spd,$track,$iperf_server,$wifi_bssid,$wifi_ssid,$wifi_freq,$wifi_signal,$wifi_tx_rate,$wifi_rx_rate,$ping_result_min,$ping_result_avg,$ping_result_max,$ping_result_mdev,$iperf_test_interval,$iperf_result_client_bytes,$iperf_result_client_bps,$iperf_result_server_bytes,$iperf_result_server_bps" >> $export_file_name
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

        if [ $manual_run -ne 1 ]; then
                echo -e "NOTE: Sleeping for $update_interval seconds..."
                update_interval_tmp="$update_interval"
                while [ $update_interval_tmp -gt 0 ]; do
                        echo -ne "$update_interval_tmp...\033[0K\r"
                        sleep 1
                        : $((update_interval_tmp--))
                done
        else
                read -p "NOTE: Press [ENTER] when ready to run next test..."
        fi

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
        
        unset wifi_connection_status
        unset wifi_iw_link
        unset wifi_iw_station_dump
        unset wifi_bssid
        unset wifi_ssid
        unset wifi_freq
        unset wifi_signal
        unset wifi_tx_rate
        unset wifi_rx_rate
        unset wifi_disconnected
                                
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
        unset iperf_result_client_mbps
        unset iperf_result_server_mbps

done

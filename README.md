# iperf_gps

This script lets you run iPerf from a Linux computer to a remote iPerf server while keeping track of your location using a GPS.

It will also collect Ping tests data as well as Wireless Wifi statistics if you are on Wifi.

Uses of this script include:
- Outdoor Wifi Survey
- Moving Vehicle 3G/LTE Connection

## Requirements:

- Linux
- iPerf https://iperf.fr/
- gpsd http://www.catb.org/gpsd/
- Netcat https://en.wikipedia.org/wiki/Netcat
- Python https://www.python.org/
- A GPS connected to your computer
- Wireless 'iw' tools https://wireless.wiki.kernel.org/en/users/documentation/iw

### Debian install:
As Root:
```
root@pi:~# apt-get install gpsd gpsd-clients iperf
root@pi:~# git clone https://github.com/mzac/iperf_gps.git
root@pi:~# cd iperf_gps
root@pi:~# cp config.ini.default config.ini
```

## Usage:
```
root@pi:~# ./iperf_gps.sh

Usage:
./iperf_gps.sh -i [server_ip]

Required:

-i [server_ip]          IP Address of the iPerf Server

Optional:

-h                      This help
-m                      Run through tests manually (no sleep)
-p [port]               iPerf port to connect to (default is 5001)
-s [seconds]            Sleep interval between tests (default is 10 seconds)
-t [seconds]            How long to run iPerf test (default is 5 seconds)
-u                      Run iPerf with UDP tests (default is TCP)
-w [base_filename]      Text that will be included in the filename
```

## Example:
```
root@pi:~# ./iperf_gps.sh -i 10.0.0.10

--------------------------------------------------------------------------------
NOTE: Verify if have Wifi...No Wifi interfaces found!
NOTE: Running ICMP ping to see if server is alive...Ok
NOTE: Running Netcat test to see if iPerf is up on server...Ok
NOTE: Writing CSV data to 10.0.0.10-2016-01-29T16:35:43+0000.csv
--------------------------------------------------------------------------------
Looking for current location...Ok
NOTE: Test sequence number: 1

GPS Date:               2016-01-29
GPS Time:               16:35:44
GPS Longitude:          -73.0000000
GPS Latitude:           45.000000000
GPS Altitude:           0 Meters
GPS Speed:              0 km/h
GPS Track:              0 Degrees

NOTE: Check if server is still alive...Ok
NOTE: Running ICMP test...Ok

Ping min:               13.538 ms
Ping avg:               16.603 ms
Ping max:               19.316 ms
Ping mdev:              2.178 ms

NOTE: Running iPerf test for 5 seconds...Ok

iPerf Client Bytes:     3145728
iPerf Server Bytes:     3670016
iPerf Client BPS:       4786759
iPerf Server BPS        4351867

NOTE: Writing results to file [10.0.0.10-2016-01-29T16:35:43+0000.csv] ...Ok
NOTE: Sleeping for 10 seconds...
```

When you are finished with your tests, stop the script with `CTRL-C`

You will then be able to parse the CSV file created however you wish.

## Roadmap
- [ ] Verify if iPerf server is capable of bidirectional test (need to add in timeout in initial setup test)
- [ ] Create CSV to KML script
- [x] Add in ICMP checks
- [x] Verify iPerf server is up and working before running tests
- [x] Add Wifi tests (SSID, BSSID, Signal, etc)

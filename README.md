# iperf_gps

This script lets you run iPerf from a Linux computer to a remote iPerf server while keeping track of your location using a GPS.

## Requirements:

- Linux
- iPerf https://iperf.fr/
- gpsd http://www.catb.org/gpsd/
- Netcat https://en.wikipedia.org/wiki/Netcat
- Python https://www.python.org/
- A GPS connected to your computer

### Debian install:
```
root@pi:~# apt-get install gpsd gpsd-clients iperf
root@pi:~# git clone https://github.com/mzac/iperf_gps.git
root@pi:~# cd iperf_gps
root@pi:~# ./iperf_gps.sh
```

## Example:

```
root@pi:~# ./iperf_gps.sh 10.0.0.10 vehicle1

--------------------------------------------------------------------------------
NOTE: Running ICMP ping to see if server is alive...Ok
NOTE: Running Netcat test to see if iPerf is up on server...Ok
NOTE: Writing CSV data to 10.0.0.10-vehicle1-2016-01-29T16:35:43+0000.csv
--------------------------------------------------------------------------------
```

Once you start the script, it will verify if there is a GPS position, and if so will then run iPerf tests

```
NOTE: Test sequence number: 1

GPS Date:               2016-01-29
GPS Time:               16:36:20
GPS Longitude:          -73.57000000
GPS Latitude:           45.500000000
GPS Altitude:           33 Meters
GPS Speed:              25 km/h
GPS Track:              132 Degrees

NOTE: Check if server is still alive...Ok
NOTE: Running ICMP test...Ok

Ping min:               9.004 ms
Ping avg:               9.699 ms
Ping max:               10.579 ms
Ping mdev:              0.547 ms

NOTE: Running iPerf test...Ok

iPerf Client Bytes:     3407872
iPerf Server Bytes:     3670016
iPerf Client BPS:       5050635
iPerf Server BPS        4850194

NOTE: Writing results to file...Ok
NOTE: Sleeping for 10 seconds...
```

When you are finished with your tests, stop the script with `CTRL-C`

You will then be able to parse the CSV file created however you wish.

## Roadmap
- [ ] Create CSV to KML script
- [x] Add in ICMP checks
- [x] Verify iPerf server is up and working before running tests

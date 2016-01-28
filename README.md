# iperf_gps

This script lets you run iPerf from a Linux computer to a remote iPerf server while keeping track of your location using a GPS.

## Requirements:

- Linux
- iPerf https://iperf.fr/
- gpsd http://www.catb.org/gpsd/
- Python https://www.python.org/
- A GPS connected to your computer

### Debian install:
```
apt-get install gpsd gpsd-clients iperf
```

## Example:

```
root@pi:~# ./iperf_gps.sh vehicle1

At any time, press CRTL-C to stop the script
Writing to vehicle1-2016-01-28T17:42:35+0000.csv
```

Once you start the script, it will verify if there is a GPS position, and if so will then run iPerf tests

```
GPS Data: time,lon,lat,alt,spd,track

Not moving - setting track to 0
GPS Data: 2016-01-28,17:45:06,-73.57000000,45.500000000,48,1,0
Running iperf test
Writing results to file:
2016-01-28,17:45:06,-73.57000000,45.500000000,48,1,0,10.0.0.10,5,524288,576495,917504,688276
Sleeping for 10 seconds...

```

When you are finished with your tests, stop the script with `CTRL-C`

You will then be able to parse the CSV file created however you wish.

## Roadmap
- [ ] Create CSV to KML script

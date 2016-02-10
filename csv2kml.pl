#!/usr/bin/perl

use Getopt::Long;
use Text::CSV;

check_options();

my $csv = Text::CSV->new();

open(CSVFILE, "<", $o_csv_file) || die("Could not open file!");

my $kml_output  = "<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n"
                . "\t<Document>\n"
                . "\t\t<Name>$o_csv_file</name>\n";

while(<CSVFILE>) {
        s/#.*//;
        next if /^(\s)*$/;
        chomp;
        push @lines, $_;

        if ($csv->parse($_)) {
                my @columns = $csv->fields();
                $test_id        	= $columns[0];
                $test_date      	= $columns[1];
                $test_time      	= $columns[2];
                $latitude       	= $columns[3];
                $longitude      	= $columns[4];
                $altitude       	= $columns[5];
                $speed          	= $columns[6];
                $track			= $columns[7];
                $iperf_server		= $columns[8];
                $wifi_bssid		= $columns[9];
                $wifi_ssid		= $columns[10];
                $wifi_freq		= $columns[11];
                $wifi_signal		= $columns[12];
                $wifi_tx_rate		= $columns[13];
                $wifi_rx_rate		= $columns[14];
                $ping_min		= $columns[15];
                $ping_avg		= $columns[16];
                $ping_max		= $columns[17];
                $ping_mdev		= $columns[18];
                $iperf_test_interval	= $columns[19];
                $iperf_client_bytes	= $columns[20];
                $iperf_client_bps	= $columns[21];
                $iperf_server_bytes	= $columns[22];
                $iperf_server_bps	= $columns[23];
                
                $kml_output     = $kml_output
                                . "\t\t\t<Placemark>\n"
                                . "\t\t\t\t<Name>ID: $test_id</Name>\n"
                                . "\t\t\t\t<ExtendedData>\n"
                                . "\t\t\t\t\t<Data name=\"Test ID\"><value>$test_id</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"Test Date\"><value>$test_date</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"Test Time\"><value>$test_time</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"Latitude\"><value>$latitude</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"Longitude\"><value>$longitude</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"Altitude\"><value>$altitude Meters</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"Speed\"><value>$speed km/h</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"Track\"><value>$track Degrees</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"iPerf Server\"><value>$iperf_server</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"WiFi BSSID\"><value>$wifi_bssid</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"WiFi SSID\"><value>$wifi_ssid</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"WiFi Freq\"><value>$wifi_freq</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"WiFi Signal\"><value>$wifi_signal</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"WiFi TX Rate\"><value>$wifi_tx_rate</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"WiFi RX Rate\"><value>$wifi_rx_rate</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"Ping Min\"><value>$ping_min ms</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"Ping Avg\"><value>$ping_avg ms</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"Ping Max\"><value>$ping_max ms</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"Ping mdev\"><value>$ping_mdev ms</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"iPerf Test Interval\"><value>$iperf_test_interval</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"iPerf Client Bytes\"><value>$iperf_client_bytes</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"iPerf Client BPS\"><value>$iperf_client_bps</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"iPerf Server Bytes\"><value>$iperf_server_bytes</value></Data>\n"
                                . "\t\t\t\t\t<Data name=\"iPerf Server BPS\"><value>$iperf_server_bps</value></Data>\n"
                                . "\t\t\t\t</ExtendedData>\n"
                                . "\t\t\t\t<Point>\n"
                                . "\t\t\t\t\t<coordinates>$latitude,$longitude</coordinates>\n"
                                . "\t\t\t\t</Point>\n"
                                . "\t\t\t</Placemark>\n";
                                
        } else {
                my $err = $csv->error_input;
                print "Failed to parse line: $err";
        }

}

$kml_output	= $kml_output
		. "\t<Document>\n"
		. "<kml>\n";

close(CSVFILE);

if (defined($o_termbin)) {
	print "Sending output to termbin.com...\n";
	my $termbin_cmd = "echo $kml_output | /bin/nc termbin.com 9999";
	my $termbin_output = `$termbin_cmd`;
	print "$termbin_output\n";
	exit;
} else {
	print "$kml_output";
	exit;
}

sub usage {
        print "\nUsage:\n";
        print "$0 -c <csv_file>\n\n";
        print "Required:\n";
        print "-c [csv_file]\t\tThe CSV file you want to convert\n";
        print "\nOptional:\n";
        print "-h\t\t\tThis help\n";
        print "-t\t\t\tSend output to termbin.com\n";
}

sub check_options {
        Getopt::Long::Configure ("bundling");
        GetOptions(
                'c:s'   => \$o_csv_file,        'csv:s'         => \$o_csv_file,
                'h'     => \$o_help,            'help'          => \$o_help,
                't'	=> \$o_termbin,		'termbin'	=> \$o_termbin,
        );

        if (not defined ($o_csv_file) || defined($o_help)) {
                usage();
                exit;
        }
}
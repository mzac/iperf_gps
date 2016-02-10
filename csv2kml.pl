#!/usr/bin/perl

use strict;
use Getopt::Long;
use Text::CSV;

# Define Global Vars
my $o_csv_file;
my $o_help;
my $o_kml_file;
my $o_termbin;

check_options();

my $csv = Text::CSV->new();

open(CSVFILE, "<", $o_csv_file) || die("Could not open file!");

my $kml_output  = "<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n"
                . "\t<Document>\n"
                . "\t\t<Name>$o_csv_file</Name>\n";

while(<CSVFILE>) {
        s/#.*//;
        next if /^(\s)*$/;
        chomp;
        next if ($. == 1); # Skip first line
        push @lines, $_;

        if ($csv->parse($_)) {
                my @columns = $csv->fields();
                my $test_id        	= $columns[0];
                my $test_date      	= $columns[1];
                my $test_time      	= $columns[2];
                my $latitude       	= $columns[3];
                my $longitude      	= $columns[4];
                my $altitude       	= $columns[5];
                my $speed          	= $columns[6];
                my $track		= $columns[7];
                my $iperf_server	= $columns[8];
                my $wifi_bssid		= $columns[9];
                my $wifi_ssid		= $columns[10];
                my $wifi_freq		= $columns[11];
                my $wifi_signal		= $columns[12];
                my $wifi_tx_rate	= $columns[13];
                my $wifi_rx_rate	= $columns[14];
                my $ping_min		= $columns[15];
                my $ping_avg		= $columns[16];
                my $ping_max		= $columns[17];
                my $ping_mdev		= $columns[18];
                my $iperf_test_interval	= $columns[19];
                my $iperf_client_bytes	= $columns[20];
                my $iperf_client_bps	= $columns[21];
                my $iperf_server_bytes	= $columns[22];
                my $iperf_server_bps	= $columns[23];
                
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
		. "\t</Document>\n"
		. "</kml>\n";

close(CSVFILE);

print "$kml_output";

if (defined($o_termbin)) {
	print "Sending output to termbin.com...\n";

	open TERMBIN, "| /bin/nc termbin.com 9999"
		or die "can't fork: $!";
	local $SIG{PIPE} = sub { die "termbin pipe broke" };
	print TERMBIN "$kml_output";
	close TERMBIN or die "bad termbin: $! $?";
}

if (defined($o_kml_file)) {
	my ($kml_ext) = $o_kml_file =~ /((\.[^.\s]+)+)$/;
	
	if ($kml_ext ne '.kml') {
		$o_kml_file	= $o_kml_file
				. ".kml";
	}

	print "Sending output to KML file: $o_kml_file\n";
	
	open KMLFILE, ">$o_kml_file"
		or die $!;
	print KMLFILE "$kml_output";
	close (KMLFILE);
}

print "\nAll done!\n\n";
exit;

sub usage {
        print "\nUsage:\n";
        print "$0 -c <csv_file>\n\n";
        print "Required:\n";
        print "-c [csv_file]\t\tThe CSV file you want to convert\n";
        print "\nOptional:\n";
        print "-h\t\t\tThis help\n";
        print "-t\t\t\tSend output to termbin.com\n";
        print "-w [kml_file]\t\tWrite KML to file\n";
        print "\n";
}

sub check_options {
        Getopt::Long::Configure ("bundling");
        GetOptions(
                'c:s'   => \$o_csv_file,        'csv:s'         => \$o_csv_file,
                'h'     => \$o_help,            'help'          => \$o_help,
                't'	=> \$o_termbin,		'termbin'	=> \$o_termbin,
		'w:s'	=> \$o_kml_file,	'output:s'	=> \$o_kml_file,
        );

        if (defined $o_help || not defined $o_csv_file) {
                usage();
                exit;
        }
}

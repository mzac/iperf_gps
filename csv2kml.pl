#!/usr/bin/perl

use Getopt::Long;
use Text::CSV;

check_options();

my $csv = Text::CSV->new();

open(CSVFILE, "<", $o_csv_file) || die("Could not open file!");

my $kml_output  = "<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n";
print "$kml_output";

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
        } else {
                my $err = $csv->error_input;
                print "Failed to parse line: $err";
        }

}

close(CSVFILE);

sub usage {
        print "\nUsage:\n";
        print "$0 -c <csv_file>\n\n";
        print "Required:\n";
        print "-c [csv_file]\t\tThe CSV file you want to convert\n";
}

sub check_options {
        Getopt::Long::Configure ("bundling");
        GetOptions(
                'h'     => \$o_help,            'help'          => \$o_help,
                'c:s'   => \$o_csv_file,        'csv:s'         => \$o_csv_file,
        );

        if (defined($o_help)) {
                usage();
                exit;
        }
}

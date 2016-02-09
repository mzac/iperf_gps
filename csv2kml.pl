#!/usr/bin/perl

use Getopt::Long;
use Text::CSV;

check_options();

sub usage {
        print "\nSyntax:\n";
        print "$0 -k <csv_file>\n\n";
}

sub check_options {
        Getopt::Long::Configure ("bundling");
        GetOptions(
                'h'     => \$o_help,    'help'          => \$o_help,
                'c:s'   => \$o_csv,     'csv:s'         => \$o_csv,
        );

        if (defined($o_help)) {
                usage();
                exit;
        }
}

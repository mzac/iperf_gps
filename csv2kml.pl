#!/usr/bin/perl

use Getopt::Long;
use Text::CSV;

check_options();

my $csv = Text::CSV->new();

open(CSVFILE, "<", $o_csv_file) || die("Could not open file!");

while(<CSVFILE> {
}

close(CSVFILE);

sub usage {
        print "\nSyntax:\n";
        print "$0 -k <csv_file>\n\n";
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

#!/usr/bin/perl
# dump.pl -- create bin dump of input file.
use strict;
use warnings;
use Getopt::Std;
use Config;

my $filename = $ARGV[0];
my $output   = $ARGV[1];
my $buffer;
my $address = 0;
my $old_fh;

$0 =~ s|.*[/\\]||;
my $usage = <<EOT;
Usage:  $0 [-h]
   or:  $0 file_in [file_out]
EOT

my %OPT = ();
warn($usage), exit(0) if !getopts( 'h', \%OPT ) or $OPT{'h'};
if ($output) {
    open( OUT, "> $output" ) || die "Couldn't open $output for output:
+ $!\n";
    $old_fh = select(OUT);
}
die "No filename specified\n" unless ($filename);
open( FILE, $filename ) || die "Couldn't open $filename: $!\n";
binmode FILE;

while ( read( FILE, $buffer, 1 ) ) {
    my $nr = ord($buffer);
    printf( "%08b\n", $nr );
}
close(FILE);

if ($output) {
    select($old_fh) if ($output);
    close(OUT);
}


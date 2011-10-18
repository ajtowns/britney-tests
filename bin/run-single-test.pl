#!/usr/bin/perl

use strict;
use warnings;

use BritneyTest;
use Getopt::Long;

my %opt = (
    'sat-britney' => 0,
);
my %opthash = (
    'sat-britney!' => \$opt{'sat-britney'},
);

# init commandline parser
Getopt::Long::config('bundling', 'no_getopt_compat', 'no_auto_abbrev');

# process commandline options
GetOptions(%opthash) or die("error parsing options\n");

my ($britney, $TESTSET, $RUNDIR, $test) = @ARGV;
my $create_test = sub { return BritneyTest->new (@_); };

if ($opt{'sat-britney'}) {
    require BritneyTest::SAT;
    $create_test = sub { return BritneyTest::SAT->new (@_); };
    print "N: Using SAT-britney calling convention\n";
}


die "Usage: $0 <britney> <testset> <rundir> <test>"
    unless $britney && $TESTSET && $RUNDIR && $test;
die "Testset does not exists" unless -d $TESTSET;
unless ( -d $RUNDIR ) {
    mkdir $RUNDIR, 0777 or die "mkdir $RUNDIR: $!";
}

my $bt = $create_test->({}, "$RUNDIR/$test", "$TESTSET/$test");
$bt->setup;
$bt->run ($britney) or exit 1;


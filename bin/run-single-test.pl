#!/usr/bin/perl

# Copyright 2011 Niels Thykier <niels@thykier.net>
# License GPL-2 or (at your option) any later.

use strict;
use warnings;

use BritneyTest;
use Getopt::Long;

my %opt = (
    'sat-britney' => 0,
    'fixed-point' => 0,
);
my %opthash = (
    'sat-britney!' => \$opt{'sat-britney'},
    'fixed-point'  => \$opt{'fixed-point'},
    'help|h'       => \&_usage,
);

my $prog = $0;
$prog =~ s,[^/]*/,,g;
$prog =~ s/\.pl$//;

# init commandline parser
Getopt::Long::config ('bundling', 'no_getopt_compat', 'no_auto_abbrev');

# process commandline options
GetOptions (%opthash) or die "error parsing options, run with --help for more info\n";

my ($britney, $TESTSET, $RUNDIR, $test) = @ARGV;
my $create_test = sub { return BritneyTest->new (@_); };
my $impl = 'britney2';

if ($opt{'sat-britney'}) {
    require BritneyTest::SAT;
    $create_test = sub { return BritneyTest::SAT->new (@_); };
    $impl = 'sat-britney';
    print "N: Using SAT-britney calling convention\n";
}


die "Usage: $prog <britney> <testset> <rundir> <test>\n"
    unless $britney && $TESTSET && $RUNDIR && $test;
die "Testset \"$TESTSET\" does not exists\n" unless -d $TESTSET;

die "There is no test called \"$test\" in \"$TESTSET\"\n"
    unless -d "$TESTSET/$test";

unless ( -d $RUNDIR ) {
    mkdir $RUNDIR, 0777 or die "mkdir $RUNDIR: $!";
}

my $o = {'fixed-point' => $opt{'fixed-point'} };
my $bt = $create_test->($o, "$RUNDIR/$test", "$TESTSET/$test");
$bt->setup;
my $ignore_expected = ($bt->testdata ('ignore-expected')//'no') eq 'yes';
my ($suc, $iter);
my $exitcode = 0;
eval { ($suc, $iter) = $bt->run ($britney, $impl); };
if ($@) {
    print "ERROR: $@";
    exit 2;
} elsif ($ignore_expected or $suc == SUCCESS_EXPECTED or $suc == FAILURE_EXPECTED) {
    print "Failed (but expected)\n" if $suc == FAILURE_EXPECTED;
} else {
    $exitcode = 1;
    print "UNEXPECTED SUCCESS\n" if $suc == SUCCESS_UNEXPECTED;
    print "FAILED\n" if $suc == FAILURE_UNEXPECTED;
}
print "$iter iterations\n" if $iter > 1;

exit $exitcode;

### functions ###

sub _usage {
    print <<EOF ;
Usage: $prog [options] <britney> <testset> <rundir> <test>

Runs the <britney> on the test <test> in a test suite (specified as
the <testset> directory).  The output is stored in the <rundir>
directory, which must not exists.

 --sat-britney   Use the SAT-britney call style (defaults to britney2 style)
 --fixed-point   Calculate a fixed point before comparing the result.


Note that --fixed-point is only guaranteed to terminate if the britney
implementation behaves as a function with an attractive fixed point.

Please refer to the README for more information on "britney call
styles" and requirements for using "--fixed-point".

EOF
    exit 0;
}

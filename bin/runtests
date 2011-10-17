#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    my $dir = $ENV{'TEST_ROOT'}||'.';
    $ENV{'TEST_ROOT'} = $dir;
}

use lib "$ENV{'TEST_ROOT'}/perl-lib";

use BritneyTest;

my $ts;
my $tf;
eval {
    require Time::HiRes;
    import Time::HiRes qw(gettimeofday tv_interval);

    print "N: Using Time::HiRes to calculate run times\n";
    $ts = sub {
        return [gettimeofday()];
    };
    $tf = sub {
        my ($start) = @_;
        my $diff = tv_interval ($start);
        return sprintf (' (%.3fs)', $diff);
    };
};

unless ($ts && $tf) {
    print "N: Fall back to no timing\n";
    $ts = sub { return 0; };
    $tf = sub { return ''; };
};

my ($britney, $TESTSET, $RUNDIR) = @ARGV;

my @tests;
my $failed = 0;

die "Usage: $0 <britney> <testset> <rundir>"
    unless $britney && $TESTSET && $RUNDIR;

mkdir $RUNDIR, 0777 or die "mkdir $RUNDIR: $!\n";
opendir my $dd, $TESTSET or die "opendir $TESTSET: $!\n";
@tests = grep { !/^\./o } sort readdir $dd;
close $dd;

foreach my $t (@tests) {
    my $bt = BritneyTest->new ({}, "$RUNDIR/$t", "$TESTSET/$t");
    my $res;
    print "Running $t...";
    $bt->setup;
    my $t = $ts->();
    if ($bt->run ($britney)) {
        $res = " done";
    } else {
        $res = " FAILED";
        $failed++;
    }
    $res = $res . ( $tf->($t));
    print "$res\n";
}

print "\nSummery:\n";
print 'Ran ' . scalar (@tests) . " tests\n";
print "Failed tests: $failed\n";
exit $failed ? 1 : 0;

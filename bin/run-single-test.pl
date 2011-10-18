#!/usr/bin/perl

use strict;
use warnings;

use BritneyTest;

my ($britney, $TESTSET, $RUNDIR, $test) = @ARGV;

die "Usage: $0 <britney> <testset> <rundir> <test>"
    unless $britney && $TESTSET && $RUNDIR && $test;
die "Testset does not exists" unless -d $TESTSET;
unless ( -d $RUNDIR ) {
    mkdir $RUNDIR, 0777 or die "mkdir $RUNDIR: $!";
}

my $bt = BritneyTest->new ({}, "$RUNDIR/$test", "$TESTSET/$test");
$bt->setup;
$bt->run ($britney) or exit 1;


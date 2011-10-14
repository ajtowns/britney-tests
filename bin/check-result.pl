#!/usr/bin/perl

use strict;
use warnings;

use Expectation;

my ($expf, $resf) = @ARGV;

die "Usage: $0 <expected> <actual>" unless $expf && $resf;

my $res = Expectation->new;
my $exp = Expectation->new;

$exp->read ($expf);
$res->read ($resf);

my ($as, $rs, $ab, $rb) = $exp->diff ($res);

if (@$as) {
    print "Added source packages:\n";
    foreach my $added (@$as) {
        my @d = @$added;
        print "  @d\n";
    }
}
if (@$rs) {
    print "Removed source packages:\n";
    foreach my $removed (@$rs) {
        my @d = @$removed;
        print "  @d\n";
    }
}
if (@$ab) {
    print "Added binary packages:\n";
    foreach my $added (@$ab) {
        my @d = @$added;
        print "  @d\n";
    }
}
if (@$rb) {
    print "Removed binary packages:\n";
    foreach my $removed (@$rb) {
        my @d = @$removed;
        print "  @d\n";
    }
}


exit (@$as + @$rs + @$ab + @$rb) ? 1 : 0;

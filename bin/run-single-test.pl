#!/usr/bin/perl

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

if ($opt{'sat-britney'}) {
    require BritneyTest::SAT;
    $create_test = sub { return BritneyTest::SAT->new (@_); };
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
my ($res, $iter) = $bt->run ($britney);

print "$iter iterations\n" if $iter > 1;

exit ($res ? 0 : 1);

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

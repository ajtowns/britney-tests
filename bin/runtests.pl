#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    my $dir = $ENV{'TEST_ROOT'}||'.';
    $ENV{'TEST_ROOT'} = $dir;
}

use lib "$ENV{'TEST_ROOT'}/perl-lib";

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

my $create_test = sub { return BritneyTest->new (@_); };

if ($opt{'sat-britney'}) {
    require BritneyTest::SAT;
    $create_test = sub { return BritneyTest::SAT->new (@_); };
    print "N: Using SAT-britney calling convention\n";
}



my ($britney, $TESTSET, $RUNDIR) = @ARGV;

my @tests;
my $failed = 0;

die "Usage: $prog <britney> <testset> <rundir>\n"
    unless $britney && $TESTSET && $RUNDIR;
die "Testset \"$TESTSET\" does not exists\n"
    unless -d $TESTSET;

my ($ts, $tf) = _load_timer();

mkdir $RUNDIR, 0777 or die "mkdir $RUNDIR: $!\n";
opendir my $dd, $TESTSET or die "opendir $TESTSET: $!\n";
@tests = grep { !/^\./o } sort readdir $dd;
close $dd;

foreach my $t (@tests) {
    my $o = {'fixed-point' => $opt{'fixed-point'}};
    my $bt = $create_test->($o, "$RUNDIR/$t", "$TESTSET/$t");
    my $res;
    print "Running $t...";
    $bt->setup;
    my $t = $ts->();
    my ($suc, $iter) = $bt->run ($britney);
    if ($suc) {
        $res = " done";
    } else {
        $res = " FAILED";
        $failed++;
    }
    # Calculate the number of iterations used to find the result
    #  (it takes at least one iteration to reach a fixed-point).
    $res .= " [$iter iterations]" if $iter > 1;
    $res = $res . ( $tf->($t));
    print "$res\n";
}

print "\nSummary:\n";
print 'Ran ' . scalar (@tests) . " tests\n";
print "Failed tests: $failed\n";
exit ($failed ? 1 : 0);

### functions ###

sub _usage {

    print <<EOF ;
Usage: $prog [options] <britney> <testset> <rundir>

Runs the <britney> on a test suite (specified as the <testset>
directory).  The output is stored in the <rundir> directory, which
must not exists.

 --sat-britney   Use the SAT-britney call style (defaults to britney2 style)
 --fixed-point   Calculate a fixed point before comparing the result.


Note that --fixed-point is only guaranteed to terminate if the britney
implementation behaves as a function with an attractive fixed point.

Please refer to the README for more information on "britney call
styles" and requirements for using "--fixed-point".

EOF
    exit 0;
}

sub _load_timer {
    my ($ts, $tf);
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
    return ($ts, $tf);
}

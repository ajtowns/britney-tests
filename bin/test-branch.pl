#!/usr/bin/perl

# Copyright 2011 Niels Thykier <niels@thykier.net>
# License GPL-2 or (at your option) any later.

use strict;
use warnings;

BEGIN {
    my $dir = $ENV{'TEST_ROOT'}||'.';
    $ENV{'TEST_ROOT'} = $dir;
}

use lib "$ENV{'TEST_ROOT'}/perl-lib";

use BritneyTest;
use Expectation;
use Getopt::Long;

my %opt = (
    'sat-britney' => 0,
    'fixed-point' => 0,
    'orig-branch' => 'master',
    'test-branch' => '',
    'git-dir'     => '',
);
my %opthash = (
    'sat-britney!'   => \$opt{'sat-britney'},
    'fixed-point'    => \$opt{'fixed-point'},
    'orig-branch=s'  => \$opt{'orig-branch'},
    'test-branch=s'  => \$opt{'test-branch'},
    'git-dir=s'      => \$opt{'git-dir'},
    'help|h'         => \&_usage,
);

my $prog = $0;
$prog =~ s,[^/]*/,,g;
$prog =~ s/\.pl$//;

# init commandline parser
Getopt::Long::config ('bundling', 'no_getopt_compat', 'no_auto_abbrev');

# process commandline options
GetOptions (%opthash) or die "error parsing options, run with --help for more info\n";

die "Missing test-branch argument.\n" unless $opt{'test-branch'};
die "Cannot pit a branch against itself.\n" if $opt{'test-branch'} eq $opt{'orig-branch'};

my $create_test = sub { return BritneyTest->new (@_); };

if ($opt{'sat-britney'}) {
    require BritneyTest::SAT;
    $create_test = sub { return BritneyTest::SAT->new (@_); };
    print "N: Using SAT-britney calling convention\n";
} else {
    print "N: Setting PYTHONDONTWRITEBYTECODE=1\n";
    $ENV{'PYTHONDONTWRITEBYTECODE'} = 1;
}

my ($britney, $TESTSET, $RUNDIR) = @ARGV;

my @tests;
my %failed = ();
my $diffs = 0;
my %it = ();
my %accrt = ();
die "Usage: $prog <britney> <testset> <rundir>\n"
    unless $britney && $TESTSET && $RUNDIR;
die "Testset \"$TESTSET\" does not exists\n"
    unless -d $TESTSET;

my ($ts, $tf) = _load_timer();

unless ($opt{'git-dir'}) {
    require File::Basename;
    require Cwd;
    my $dir;
    my $abs = Cwd::abs_path ($britney);
    die "Cannot determine abs_path of $britney: $!" unless $abs;
    $dir = File::Basename::dirname ($abs);
    $opt{'git-dir'} = "$dir/.git";
}

die "$opt{'git-dir'} does not exists.\n" unless -d $opt{'git-dir'};

mkdir $RUNDIR, 0777 or die "mkdir $RUNDIR: $!\n";
mkdir "$RUNDIR/orig", 0777 or die "mkdir $RUNDIR/orig: $!\n";
mkdir "$RUNDIR/test", 0777 or die "mkdir $RUNDIR/test: $!\n";

opendir my $dd, $TESTSET or die "opendir $TESTSET: $!\n";
@tests = grep { !/^\./o } sort readdir $dd;
close $dd;

foreach my $t (@tests) {
    my %fail = ();
    my $checkdiff = 0;
    print "Running $t";
    foreach my $reviewed ('orig', 'test') {
        my $o = {'fixed-point' => $opt{'fixed-point'}};
        my $bt;
        my $res;
        my $ignore_expected;
        my $branch = $opt{"$reviewed-branch"};
        _checkout_branch ($opt{'git-dir'}, $branch);
        print " | $branch:";
        $bt = $create_test->($o, "$RUNDIR/$reviewed/$t", "$TESTSET/$t");
        $bt->setup;
        $ignore_expected = ($bt->testdata ('ignore-expected')//'no') eq 'yes';
        my $t = $ts->();
        my ($suc, $iter) = $bt->run ($britney);
        if ($ignore_expected) {
            $res = ' done';
            $checkdiff = 1;
        } elsif ($suc) {
            $res = ' ok';
        } else {
            $res = ' FAILED';
            $fail{$reviewed}++;
            $failed{$reviewed}++;
        }
        $accrt{$reviewed} += $tf->($t);
        # Calculate the number of iterations used to find the result
        #  (it takes at least one iteration to reach a fixed-point).
        if ($iter) {
            $it{$reviewed} += $iter;
        }
        $res = $res;
        print "$res";
    }

    if ($checkdiff || $fail{'orig'} && $fail{'test'}) {
        # they both failed, but did they produce the same result?
        my $ores = Expectation->new ();
        my $tres = Expectation->new ();
        my ($as, $rs, $ab, $rb);

        $ores->read ("$RUNDIR/orig/$t/var/data/output/HeidiResult");
        $tres->read ("$RUNDIR/test/$t/var/data/output/HeidiResult");

        ($as, $rs, $ab, $rb) = $ores->diff ($tres);
        if (@$as + @$rs + @$ab + @$rb) {
            $diffs++;
            print "| DIFF";
            open my $fd, '>', "$RUNDIR/$t.diff" or die "opening $RUNDIR/$t.diff: $!";
            Expectation::print_diff ($fd, $as, $rs, $ab, $rb);
            close $fd or die "closing $RUNDIR/$t.diff: $!";
        }
    }
    print "\n";
}


print "\nSummary:\n";
print 'Ran ' . scalar (@tests) . " tests\n";
print "$opt{'orig-branch'} failed $failed{'orig'} tests\n" if $failed{'orig'};
print "$opt{'test-branch'} failed $failed{'test'} tests\n" if $failed{'test'};
print "There were $diffs test(s) where the two branches both failed and produced different results\n"
    if $diffs;
exit (($failed{'test'} || $diffs) ? 1 : 0);

### functions ###

sub _usage {

    print <<EOF ;
Usage: $prog [options] <britney> <testset> <rundir>

Tests two git branches of britney against each other.  They are run
against the tests in <testset> and their output will be stored in
<rundir>, which must not exists.

If both branches fail a given test, their output will be diffed to see
if they produce the same output.

The test runner will be using "git [--git-dir=\$dir] checkout \$branch"
to switch between branches.

 --sat-britney      Use the SAT-britney call style (defaults to britney2 style)
 --fixed-point      Calculate a fixed point before comparing the result.
 --orig-branch=<b>  The "original" branch (defaults to "master")
 --test-branch=<b>  The "new" branch
 --git-dir=<dir>    The "git-dir" (defaults to dirname(<britney>)/.git)

Note that --fixed-point is only guaranteed to terminate if the britney
implementation behaves as a function with an attractive fixed point.

Please refer to the README for more information on "britney call
styles" and requirements for using "--fixed-point".

Note: This will leave the git repository in the "new" branch if the
run completes.  If the run is aborted (for whatever reason) the
repository may be left in either the "original" or "new" branch.

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
            return $diff;
        };
    };

    unless ($ts && $tf) {
        print "N: Fall back to no timing\n";
        $ts = sub { return 0; };
        $tf = sub { return ''; };
    };
    return ($ts, $tf);
}

sub _checkout_branch {
    my ($gitdir, $branch) = @_;
    # --git-dir=<dir> might look attractive, but git in stable appears to f*** it up.
    system ("cd \"$gitdir/..\" && git checkout -q \"$branch\"") == 0
        or die "\ncd \"$gitdir/..\" && git checkout -q \"$branch\" failed with code: " . (($? >> 8) & 0xff);
    return 1;
}

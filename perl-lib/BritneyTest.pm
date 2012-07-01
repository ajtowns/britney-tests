# perl

# Copyright 2011 Niels Thykier <niels@thykier.net>
# License GPL-2 or (at your option) any later.

package BritneyTest;

use base qw(Class::Accessor);

use strict;
use warnings;

use Carp qw(croak);
use Expectation;
use SystemUtil;

my $DEFAULT_ARCH = 'i386';
my @AUTO_CREATE_EMPTY = (
    'var/data/testing/Sources',
    'var/data/testing/Packages_@ARCH@',
    'var/data/testing/BugsV',
    'var/data/testing-proposed-updates/Sources',
    'var/data/testing-proposed-updates/Packages_@ARCH@',
    'var/data/testing-proposed-updates/BugsV',
    'var/data/unstable/Sources',
    'var/data/unstable/Packages_@ARCH@',
    'var/data/unstable/BugsV',
    'hints/test-hints',
);

sub new {
    my ($class, $testdata, $rundir, $testdir) = @_;
    my $self = {
        'rundir'   => $rundir,
        'testdir'  => $testdir,
        'testdata' => $testdata,
    };
    bless $self, $class;
    return $self;
}

sub setup {
    my ($self) = @_;
    my $rundir = $self->rundir;
    my $testdir = $self->testdir;
    my $outputdir;
    my $hintlink;
    mkdir $rundir, 0777 or croak "mkdir $rundir: $!";
    system ('rsync', '-a', "$testdir/", "$rundir/") == 0 or
        croak "rsync failed: " . (($?>>8) & 0xff);
    $outputdir = "$rundir/var/data/output";
    unless (-d $outputdir ) {
        mkdir $outputdir, 0777 or croak "mkdir $outputdir: $!";
    }
    $hintlink = "$rundir/var/data/unstable/Hints";
    unless ( -d "$hintlink/" ) {
        symlink "$rundir/hints", $hintlink or croak "symlink $hintlink -> $rundir/hints: $!";
    }

    $self->_read_test_data;

    foreach my $autogen (@AUTO_CREATE_EMPTY) {
        my @subst = (''); #do once
        my $dosubst = 0;
        if ($autogen =~ m/\@ARCH\@/) {
            # ... per architecture
            @subst = split m/\s++/, $self->{'testdata'}->{'architectures'} // $DEFAULT_ARCH;
            $dosubst = 1;
        }
        foreach my $a (@subst) {
            my $f = "$rundir/$autogen";
            my $dir;
            $f =~ s/\@ARCH\@/$a/ if $dosubst;

            next if -e $f;
            $dir = $f;
            $dir =~ s,/[^/]++$,,;
            unless ( -d $dir ) {
                system ('mkdir', '-p', $dir) == 0 or croak "mkdir -p $dir failed";
            }
            open my $fd, '>', $f or croak "open $f: $!";
            close $fd or croak "close $f: $!";
        }
    }
    $self->_gen_britney_conf ("$rundir/britney.conf", $self->{'testdata'},
                              "$rundir/var/data", "$outputdir");

    $self->_hook ('post-setup');
}

sub run {
    my ($self, $britney) = @_;
    my $cmd = $self->_britney_cmdline ($britney);
    my $rundir = $self->rundir;
    my $testdata = $self->{'testdata'};
    my $i = 0;
    my $exp = Expectation->new;
    my $result = 0;
    $exp->read ("$rundir/expected");

    while (1) {
        system_file ("$rundir/log.txt", $cmd) == 0 or
            croak "$britney died with  ". (($?>>8) & 0xff);
        my $res = Expectation->new;
        my $lres;
        my $fixp = 0;

        $res->read ("$rundir/var/data/output/HeidiResult");
        if ( -e "$rundir/var/data/output/HeidiResult-$i") {
            $lres = Expectation->new;
            $lres->read ("$rundir/var/data/output/HeidiResult-$i");
            $fixp = 1 unless $lres->diff ($res);
        }

        my ($as, $rs, $ab, $rb) = $exp->diff ($res);
        # Always create the diff (even if it would be empty)
        # - this allows people to trivally examine the diffs to the
        #   real result at different points before the fixed-point
        open(my $fd, '>', "$rundir/diff") or croak "opening $rundir/diff: $!";

        if (($testdata->{'ignore-expected'}//'') eq 'yes') {
            # "Any" result is "ok"
            $result = 1;
        } else {
            if (@$as + @$rs + @$ab + @$rb) {
                # Failed
                Expectation::print_diff ($fd, $as, $rs, $ab, $rb);
                $result = 0;
            } else {
                $result = 1;
            }
        }

        close $fd or croak "closing $rundir/diff: $!";

        if ($testdata->{'fixed-point'}) {
            last if $fixp;
            # not at a fixed point - prepare for the next point.
            # We assume Britney updates $rundir/var/data/testing/
            $i++;
            rename "$rundir/var/data/output/HeidiResult", "$rundir/var/data/output/HeidiResult-$i"
                or croak "rename HeidiResult -> HeidiResult-$i: $!";
            rename "$rundir/log.txt", "$rundir/log-$i.txt"
                or croak "rename log.txt -> log-$i.txt: $!";
            rename "$rundir/diff", "$rundir/diff-$i"
                or croak "rename log.txt -> log-$i.txt: $!";
        } else {
            # If we are not looking for a fixed-point then stop here.
            last;
        }
    }
    return wantarray ? ($result, $i) : $result;
}

sub clean {
    my ($self) = @_;
    my $rundir = $self->rundir;
    system 'rm', '-r', $rundir == 0 or croak "rm -r $rundir failed: $?";
}

sub testdata {
    my ($self, $key) = @_;
    return $self->{'testdata'}->{$key};
}

sub _britney_cmdline {
    my ($self, $britney) = @_;
    my $rundir = $self->rundir;
    my $conf = "$rundir/britney.conf";

    return [$britney, '-c', $conf, '--control-files', '-v'];
}


sub _hook {
    my ($self, $hook) = @_;
    my $rundir = $self->rundir;
    return unless -x "$rundir/hooks/$hook";
    system_file ("$rundir/$hook.log", ["$rundir/hooks/$hook", $rundir]) == 0
        or croak "$hook hook died with  ". (($?>>8) & 0xff);
}

BritneyTest->mk_ro_accessors (qw(rundir testdir));

sub _read_test_data {
    my ($self) = @_;
    my $rundir = $self->rundir;
    my $dataf = "$rundir/test-data";
    return unless -s $dataf;
    open my $fd, '<', $dataf or croak "opening $dataf: $!";
    while (my $line = <$fd> ) {
        chomp ($line);
        if ($line =~ m/^([^ \t:]+):\s*(\S(?:.*\S)?)\s*$/o) {
            my ($opt,$value) = (lc $1, $2);
            $self->{'testdata'}->{$opt} = $value
                unless exists $self->{'testdata'}->{$opt};
        }
    }
    close $fd;
}

sub _gen_britney_conf {
    my ($self, $file, $data, $datadir, $outputdir) = @_;

    my $archs   = $data->{'architectures'}//$DEFAULT_ARCH;
    my $nbarchs = $data->{'no-break-architectures'}//$DEFAULT_ARCH;
    my $farchs  = $data->{'fucked-architectures'}//'';
    my $barchs  = $data->{'break-architectures'}//'';

    open my $fd, '>', $file or croak "$file: $!";
    # contents of the conf
    print $fd <<EOF;
# Configuration file for britney

# Paths for control files
TESTING           = $datadir/testing
TPU               = $datadir/testing-proposed-updates
UNSTABLE          = $datadir/unstable

# Output
NONINST_STATUS    = $outputdir/non-installable-status
EXCUSES_OUTPUT    = $outputdir/excuses.html
UPGRADE_OUTPUT    = $outputdir/output.txt
HEIDI_OUTPUT      = $outputdir/HeidiResult

# List of release architectures
ARCHITECTURES     = $archs

# if you're not in this list, arch: all packages are allowed to break on you
NOBREAKALL_ARCHES = $nbarchs

# if you're in this list, your packages may not stay in sync with the source
FUCKED_ARCHES     = $farchs

# if you're in this list, your uninstallability count may increase
BREAK_ARCHES      = $barchs

# if you're in this list, you are a new architecture
NEW_ARCHES        =

# priorities and delays
MINDAYS_LOW       = 10
MINDAYS_MEDIUM    = 5
MINDAYS_HIGH      = 2
MINDAYS_CRITICAL  = 0
MINDAYS_EMERGENCY = 0
DEFAULT_URGENCY   = low

# hint permissions
HINTS_TEST-HINTS  = ALL

# support for old libraries in testing (smooth update)
# use ALL to enable smooth updates for all the sections
SMOOTH_UPDATES = libs oldlibs

EOF
    close $fd or croak "$file: $!";
}

1;


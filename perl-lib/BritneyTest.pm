# perl

# Copyright 2011 Niels Thykier <niels@thykier.net>
# License GPL-2 or (at your option) any later.

package BritneyTest;

use strict;
use warnings;

use base qw(Exporter Class::Accessor);

use constant {
    SUCCESS_EXPECTED => 0,
    FAILURE_UNEXPECTED => 1,
    SUCCESS_UNEXPECTED => 2,
    FAILURE_EXPECTED => 3,
    ERROR_EXPECTED => 4,
};

use Carp qw(croak);
use Dpkg::Control;

use File::Find;

use Expectation;
use SystemUtil;
use TestLib;

our @EXPORT = qw(
      SUCCESS_EXPECTED
      FAILURE_UNEXPECTED
      SUCCESS_UNEXPECTED
      FAILURE_EXPECTED
      ERROR_EXPECTED
);

my $DEFAULT_ARCH = 'i386';
my @AUTO_CREATE_EMPTY = (
    'var/data/testing/BugsV',
    'var/data/testing-proposed-updates/Sources',
    'var/data/testing-proposed-updates/Packages_@ARCH@',
    'var/data/testing-proposed-updates/BugsV',
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
    mkdir $rundir, 0777 or croak "mkdir $rundir: $!";
    system ('rsync', '-a', "$testdir/", "$rundir/") == 0 or
        croak "rsync failed: " . (($?>>8) & 0xff);
    $outputdir = "$rundir/var/data/output";
    unless (-d $outputdir ) {
        system ('mkdir', '-p', $outputdir) == 0 or croak "mkdir -p $outputdir failed";
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

    {
        my $hintlink = "$rundir/var/data/unstable/Hints";
        my $datatdir = "$rundir/var/data/testing";
        unless ( -d "$hintlink/" ) {
            symlink "../../../hints", $hintlink or croak "symlink $hintlink -> $rundir/hints: $!";
        }
        unless ( -f "$datatdir/Urgency" or -f "$datatdir/Dates" ) {
            $self->_generate_urgency_dates ($datatdir, "$rundir/var/data/unstable/");
        }
    }


    $self->_gen_britney_conf ("$rundir/britney.conf", $self->{'testdata'},
                              "$rundir/var/data", "$outputdir");

    $self->_hook ('post-setup');
}

sub run {
    my ($self, $britney, $impl) = @_;
    my $cmd = $self->_britney_cmdline ($britney);
    my $rundir = $self->rundir;
    my $testdata = $self->{'testdata'};
    my $i = 0;
    my $exp = Expectation->new;
    my $result = 0;
    $exp->read ("$rundir/expected");

    while (1) {
        my $res = Expectation->new;
        my $lres;
        my $fixp = 0;
        my $s = system_file("$rundir/log.txt", $cmd);
        my $heidi = "$rundir/var/data/output/HeidiResult";
        if ($s) {
            if ($impl && exists($self->{'failures'}{lc $impl})) {
                my $ex = $self->{'failures'}{lc $impl};
                if ($ex eq 'crash') {
                    return (ERROR_EXPECTED, $i) if wantarray;
                    return ERROR_EXPECTED;
                }
                croak "$britney died with  ". (($?>>8) & 0xff);
            }
        }


        if ( ! -f $heidi) {
            croak("$britney did not produce a HeidiResult at ${heidi} - perhaps a silent failure!?");
        }
        $res->read($heidi);
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
                $result = FAILURE_UNEXPECTED;
            } else {
                $result = SUCCESS_EXPECTED;
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
    if ($impl and exists $self->{'failures'}{lc $impl}) {
        my $ex = $self->{'failures'}{lc $impl};
        # The implementation is expected to fail or crash, so any
        # success is "unexpected"
        $result = SUCCESS_UNEXPECTED if $result == SUCCESS_EXPECTED;
        if ($result == FAILURE_UNEXPECTED && $ex ne 'crash') {
            # We were expected to fail here.
            $result = FAILURE_EXPECTED;
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
    my $ctrl;
    my @para;
    return unless -s $dataf;
    open my $fd, '<', $dataf or croak "opening $dataf: $!";
    while ( defined ($ctrl = Dpkg::Control->new (type => CTRL_UNKNOWN)) and
            ($ctrl->parse ($fd, $dataf)) ) {
        push @para, $ctrl;
    }
    close $fd;
    $self->{'testdata'} = shift @para;
    if ($self->{'testdata'}->{'expected-failure'}) {
        my $rawfield = $self->{'testdata'}{'expected-failure'};
        my %impl;
        for my $entry (grep { $_ } split(m/(?:\s++|\n)++/o, $rawfield)) {
            my $ex = 'failure';
            if (index($entry, '=') > -1) {
                ($entry, $ex) = split('=', $entry, 2);
            }
            $impl{lc $entry} = $ex;
        }
        $self->{'failures'} = \%impl;
    }
}

sub _generate_urgency_dates {
    my ($self, $datatdir, $siddir) = @_;
    my $urgen = "$datatdir/Test-urgency.in";
    my $dates = {};
    my $urgencies = {};
    my @sources = ();
    my $ctrl;

    if (! -d $siddir) {
        croak "$siddir is not a directory";
    }

    my @allsidsources = ();
    find( sub { push @allsidsources, $File::Find::name if "$_" eq "Sources"; },
          $siddir );

    for my $sidsources (@allsidsources) {
        open my $fd, '<', $sidsources or croak "opening $sidsources: $!";
        while ( defined ($ctrl = Dpkg::Control->new (type => CTRL_INDEX_SRC)) and
                ($ctrl->parse ($fd, $sidsources)) ) {
            my $source = $ctrl->{'Package'};
            my $version = $ctrl->{'Version'};
            croak "$sidsources contains a bad entry!"
                unless defined $source and defined $version;
            push @sources, [$source, $version];
            $urgencies->{"$source/$version"} = 'low';
            $dates->{"$source/$version"} = 1;
        }
        close $fd;
    }

    if ( -f $urgen ) {
        # Load the urgency generation hints.
        # Britney's day begins at 3pm.
        my $bnow = int (((time / (60 * 60)) - 15) / 24);
        open my $fd, '<', $urgen or croak "opening $urgen: $!";
        while ( my $line = <$fd> ) {
            chomp $line;
            next if $line =~ m/^\s*(?:\#|\z)/o;
            my ($srcver, $date, $urgency) = split m/\s++/, $line, 3;
            croak "Cannot parse line $. in $urgen."
                unless defined $srcver and defined $date and
                       defined $urgency;
            croak "Reference to unknown source $srcver ($urgen: $.)"
                unless exists $urgencies->{$srcver};
            croak "Unknown urgency for $srcver ($urgen: $.)"
                unless $urgency =~ m/^(low|medium|high|emergency|critical)$/;
            if ($date eq '*') {
                $date = 1;
            } elsif ($date =~ m/^age=(\d+)$/o) {
                $date = $bnow - $1;
            } elsif ($date !~ m/^\d+$/o) {
                croak "Date for $srcver is not an int ($urgen: $.)";
            }
            $urgencies->{$srcver} = $urgency;
            $dates->{$srcver} = $date;
        }
        close $fd;
    }

    TestLib::gen_dates_urgencies ($datatdir, \@sources, $dates, $urgencies);
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
NONINST_STATUS      = $outputdir/non-installable-status
EXCUSES_OUTPUT      = $outputdir/excuses.html
UPGRADE_OUTPUT      = $outputdir/output.txt
HEIDI_OUTPUT        = $outputdir/HeidiResult
EXCUSES_YAML_OUTPUT = $outputdir/excuses.yaml

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


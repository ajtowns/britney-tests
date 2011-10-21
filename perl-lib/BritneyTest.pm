# perl

package BritneyTest;

use base qw(Class::Accessor);

use strict;
use warnings;

use Carp qw(croak);
use Expectation;
use SystemUtil;

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
        mkdir $outputdir, 0777 or croak "mkdir $outputdir: $!";
    }

    $self->_read_test_data;

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

        if (@$as + @$rs + @$ab + @$rb) {
            # Failed
            _print_diff ($fd, $as, $rs, $ab, $rb);
            $result = 0;
        } else {
            $result = 1;
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

sub _britney_cmdline {
    my ($self, $britney) = @_;
    my $rundir = $self->rundir;
    my $conf = "$rundir/britney.conf";

    return [$britney, '-c', $conf, '--control-files',
            '-v', '--auto-hinter'];
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

    my $archs   = $data->{'architectures'}//'i386';
    my $nbarchs = $data->{'no-break-architectures'}//'i386';
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

sub _print_diff {
    my ($fd, $as, $rs, $ab, $rb) = @_;
    if (@$as) {
        print $fd "Added source packages:\n";
        foreach my $added (@$as) {
            my @d = @$added;
            print $fd "  @d\n";
        }
    }
    if (@$rs) {
        print $fd "Removed source packages:\n";
        foreach my $removed (@$rs) {
            my @d = @$removed;
            print $fd "  @d\n";
        }
    }
    if (@$ab) {
        print $fd "Added binary packages:\n";
        foreach my $added (@$ab) {
            my @d = @$added;
            print $fd "  @d\n";
        }
    }
    if (@$rb) {
        print $fd "Removed binary packages:\n";
        foreach my $removed (@$rb) {
            my @d = @$removed;
            print $fd "  @d\n";
        }
    }

}

1;


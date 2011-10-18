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

    $self->_gen_britney_conf ("$rundir/britney.conf", $self->{'testdata'},
                              "$rundir/var/data", "$outputdir");

    $self->_hook ('post-setup');
}

sub run {
    my ($self, $britney) = @_;
    my $rundir = $self->rundir;
    my $conf = "$rundir/britney.conf";
    system_file ("$rundir/log.txt", [$britney, '-c', $conf,
                 '--control-files', '-v', '--auto-hinter', '--compatible']) == 0 or
                     croak "britney died with  ". (($?>>8) & 0xff);
    my $res = Expectation->new;
    my $exp = Expectation->new;

    $exp->read ("$rundir/expected");
    $res->read ("$rundir/var/data/output/HeidiResult");

    my ($as, $rs, $ab, $rb) = $exp->diff ($res);
    if (@$as + @$rs + @$ab + @$rb) {
    	my $fd;
    	open($fd,">","$rundir/diff") or croak $!;
        _print_diff ($fd, $as, $rs, $ab, $rb);
	close($fd);
        return 0;
    }
    return 1;
}

sub clean {
    my ($self) = @_;
    my $rundir = $self->rundir;
    system 'rm', '-r', $rundir == 0 or croak "rm -r $rundir failed: $?";
}


sub _hook {
    my ($self, $hook) = @_;
    my $rundir = $self->rundir;
    return unless -x "$rundir/hooks/$hook";
    system_file ("$rundir/$hook.log", ["$rundir/hooks/$hook", $rundir]) == 0
        or croak "$hook hook died with  ". (($?>>8) & 0xff);
}

BritneyTest->mk_ro_accessors (qw(rundir testdir));

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


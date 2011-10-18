# perl
package BritneyTest::SAT;

use strict;
use warnings;

use base 'BritneyTest';
use Class::ISA;

sub _britney_cmdline {
    my ($self, $britney) = @_;
    my $rundir = $self->rundir;

    return [$britney, '-d', "$rundir/var/data", '--full-dependencies',
            '--heidi', "$rundir/var/data/output/HeidiResult",
            '-a', 'i386'];

}

1;


# perl
package BritneyTest::SAT;

use strict;
use warnings;

use base 'BritneyTest';

sub _britney_cmdline {
    my ($self, $britney) = @_;
    my $rundir = $self->rundir;
    my $rawarchs = $self->{'testdata'}->{'architectures'}//'i386';
    my $arch = join(',', split m/\s++/o, $rawarchs);
    return [$britney, '-d', "$rundir/var/data",
            '--heidi', "$rundir/var/data/output/HeidiResult",
            '-a', $arch];

}

1;


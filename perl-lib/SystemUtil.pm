# perl

package SystemUtil;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = (qw(system_file));

sub system_file {
    my ($file, $cmd) = @_;
    open my $fd, '>', $file or die "open $file: $!";
    my $pid = open my $cd, '-|';
    my $res;
    die "fork failed: $!" unless defined $pid;
    $ENV{PERLLIB} = join ':',@INC;
    unless ($pid) {
        # child - re-direct STDERR to STDOUT and exec
        close STDERR;
        open STDERR, '>&STDOUT' or die "reopen stderr: $!";
        exec @$cmd or die "exec @$cmd failed: $!";
    }

    while (my $line = <$cd>) {
        print $fd $line;
    }
    close $cd;
    $res = $?;
    close $fd or die "closing $file: $!";
    return $res;
}



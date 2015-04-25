# perl

# Copyright 2011 Niels Thykier <niels@thykier.net>
# License GPL-2 or (at your option) any later.

package SystemUtil;

use strict;
use warnings;

use base 'Exporter';

use constant MIN_OOM_ADJ => 0;

our @EXPORT = (qw(system_file));

sub system_file {
    my ($file, $cmd) = @_;
    open my $fd, '>', $file or die "open $file: $!";
    my $pid = open my $cd, '-|';
    my $res;
    $fd->autoflush;
    die "fork failed: $!" unless defined $pid;
    $ENV{PERLLIB} = join ':',@INC;
    $ENV{PYTHONHASHSEED} = 'random' if not exists($ENV{PYTHONHASHSEED});
    unless ($pid) {
        # child - [Linux] Ensure that the OOM killer considers
        # us a target in low memory conditions.
        if ( -e '/proc/self/oom_adj') {
            open(my $oom_fd, '<', '/proc/self/oom_adj')
                or die "open oom_adj: $!";
            my $score = <$oom_fd>;
            chomp($score);
            close($fd) or die "close oom_adj: $!";
            if ($score < MIN_OOM_ADJ) {
                # Re-open oom_adj (it doesn't like seeking)
                open($oom_fd,  '>', '/proc/self/oom_adj')
                    or die "open oom_adj [write]: $!";
                print {$oom_fd} MIN_OOM_ADJ . "\n";
                close($oom_fd) or die "close oom_adj [write]: $!";
            }

        }
        # re-direct STDERR to STDOUT and exec
        close STDERR;
        open(STDERR, '>&', \*STDOUT) or die "reopen stderr: $!";
        STDOUT->autoflush;
        STDERR->autoflush;
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



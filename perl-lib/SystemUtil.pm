# perl

# Copyright 2011 Niels Thykier <niels@thykier.net>
# License GPL-2 or (at your option) any later.

package SystemUtil;

use strict;
use warnings;

use base 'Exporter';

use POSIX qw(nice);

use constant MIN_OOM_ADJ => 0;

our @EXPORT = (qw(system_file));

sub system_file {
    my ($file, $cmd) = @_;
    open my $fd, '>', $file or die "open $file: $!";
    my $pid = fork;
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
            close($oom_fd) or die "close oom_adj: $!";
            if ($score < MIN_OOM_ADJ) {
                # Re-open oom_adj (it doesn't like seeking)
                open($oom_fd,  '>', '/proc/self/oom_adj')
                    or die "open oom_adj [write]: $!";
                print {$oom_fd} MIN_OOM_ADJ . "\n";
                close($oom_fd) or die "close oom_adj [write]: $!";
            }

        }
        # Try to apply nice-ness, but if it fails then ignore it.
        nice(10) or 1;
        # re-direct STDERR to STDOUT and exec
        open(STDOUT, '>&', $fd) or die "reopen stdout: $!";
        open(STDERR, '>&', \*STDOUT) or die "reopen stderr: $!";
        STDOUT->autoflush;
        STDERR->autoflush;
        exec @$cmd or die "exec @$cmd failed: $!";
    }
    waitpid($pid, 0) == $pid or die("waitpid($pid, 0) failed: $!");
    return $?;
}



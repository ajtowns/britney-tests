# perl

# Copyright 2011 Niels Thykier <niels@thykier.net>
# License GPL-2 or (at your option) any later.

package Expectation;

use strict;
use warnings;

use Carp qw(croak);

sub new {
    my ($type) = @_;
    my $self = {
        'source' => {},
        'binary'  => {},
    };
    bless $self, $type;
    return $self;
}

sub read {
    my ($self, $file) = @_;
    my ($pkg, $ver, $at);
    open my $fd, '<', $file or croak "$file: $!";
    while (my $line = <$fd>) {
        chomp $line;
        next if $line eq '';
        next if $line =~ m/^\s*+#/o;
        ($pkg, $ver, $at) = split m/\s++/o, $line;
        $self->{'source'}->{"${pkg} ${ver}"} = 1 if $at eq 'source';
        $self->{'binary'}->{"${pkg} ${ver} ${at}"} = 1 if $at ne 'source';
    }
    close $fd;
}

# Returns the differences in list context.  In scalar context
# a truth value if they differ and a non-truth value if they
# are identical.
sub diff {
    my ($self, $other) = @_;
    # Copy the internal lists
    my @sd = _diff_hash_ref ($self->{'source'}, $other->{'source'});
    my @bd = _diff_hash_ref ($self->{'binary'}, $other->{'binary'});

    return (@sd, @bd) if wantarray;
    my $d = 0;
    foreach my $r ((@sd, @bd)) {
        $d += @$r;
    }
    return $d;
}

sub _diff_hash_ref {
    my ($oh, $nh) = @_;
    my @added;
    my @removed;
    my %copy = %{ $oh };

    # Simple diff algorithm - first copy the original hash,
    # remove all common elements from the new and the copy.
    # Any element in the new, that is not in the copy are
    # "new" and all elements left in copy will be "removed"
    # in the new hash.

    foreach my $k (sort keys %$nh) {
         if (! exists $copy{$k}) {
            my @d = split m/\s++/o, $k;
            push @added, \@d;
        }
        delete $copy{$k};
    }
    foreach my $k (sort keys %copy) {
         my @d = split m/\s++/o, $k;
        push @removed, \@d;
    }
    return (\@added, \@removed);
}


# Expectation::print_diff ($fd, @diff)
#
# $fd is the file handle to write it to.
# @diff is a diff returned by $a->diff ($b)
sub print_diff {
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


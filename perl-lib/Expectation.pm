# perl

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
        ($pkg, $ver, $at) = split m/\s++/o, $line;
        $self->{'source'}->{"${pkg} ${ver}"} = 1 if $at eq 'source';
        $self->{'binary'}->{"${pkg} ${ver} ${at}"} = 1 if $at ne 'source';
    }
    close $fd;
}

sub diff {
    my ($self, $other) = @_;
    # Copy the internal lists
    my @sd = _diff_hash_ref ($self->{'source'}, $other->{'source'});
    my @bd = _diff_hash_ref ($self->{'binary'}, $other->{'binary'});

    return (@sd, @bd);
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

1;


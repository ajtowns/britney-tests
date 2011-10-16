# perl

package TestLib;

use strict;
use warnings;

use Carp qw(croak);

# gen_dates_urgencies ($tdir, $spkgs, $dates, $urgencies)
#
# $tdir is the path to the testing data dir (where Urgency and Dates is to be created)
# $spkgs is a list ref of ['package', 'version'] entries
#  - i.e. [['lintian', '2.5.4'], ['eclipse', '3.7.1']]
# $dates is a hashref mapping "$pkg/$ver" to a date
#  - if an entry is not present, it is assumed to be "1"
#  - if $dates is undefined, all dates are assumed to be "1"
# $urgencies is a hashref mapping "$pkg/$ver" to an urgency
#  - if an entry is not present, it is assumed to be "low"
#  - if $urgencies is undefined, all urgencies are assumed to be "low"
sub gen_dates_urgencies {
    my ($testingdir, $spkgs, $dates, $urgencies) = @_;
    $dates = {} unless $dates;
    $urgencies = {} unless $urgencies;

    open my $df, '>', "$testingdir/Dates" or croak "opening $testingdir/Dates: $!";
    open my $uf, '>', "$testingdir/Urgency" or croak "opening $testingdir/Urgency: $!";

    foreach my $s (@$spkgs) {
        my ($pkg,$ver) = @$s;
        my $date = $dates->{"$pkg/$ver"}//1;
        my $urgen = $urgencies->{"$pkg/$ver"}//'low';
        print $df "$pkg $ver $date\n";
        print $uf "$pkg $ver $urgen\n";
    }

    close $df or croak "closing $testingdir/Dates: $!";
    close $uf or croak "closing $testingdir/Urgency: $!";
}

1;


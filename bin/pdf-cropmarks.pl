#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Getopt::Long;
use PDF::Cropmarks;

my $paper = 'a4';
my ($no_top, $no_bottom, $no_inner, $no_outer, $oneside) = (0,0,0,0,0);
GetOptions(
           'paper=s' => \$paper,
           'no-top' => \$no_top,
           'no-bottom' => \$no_bottom,
           'no-inner' => \$no_inner,
           'no-outer' => \$no_outer,
           'one-side' => \$oneside,
          ) or die;

my ($input, $output) = @ARGV;
die "Missing input file" unless $input && -f $input;

if (-e $output) {
    unlink $output or die "Cannot remove $output: $!\n";
}

if ($no_top && $no_bottom) {
    warn "You specified no-top and no-bottom, centering instead\n";
}

if ($no_inner && $no_outer) {
    warn "You specified no-inner and no-outer, centering instead\n";
}

my $crop = PDF::Cropmarks->new(file => $input,
                               output => $output,
                               paper => $paper,
                               top => !$no_top,
                               bottom => !$no_bottom,
                               inner => !$no_inner,
                               outer => !$no_outer,
                               twoside => !$oneside,
                              );
$crop->add_cropmarks;



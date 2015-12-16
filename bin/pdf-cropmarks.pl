#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use PDF::Cropmarks;

my ($input) = @ARGV;

die "Missing input file" unless $input && -f $input;

my $crop = PDF::Cropmarks->new(file => $input);

print $crop->add_cropmarks . "\n";


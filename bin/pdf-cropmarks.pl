#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Getopt::Long;
use PDF::Cropmarks;
use Pod::Usage;

my $paper = 'a4';
my ($help, $version);
my ($no_top, $no_bottom, $no_inner, $no_outer, $oneside) = (0,0,0,0,0);
GetOptions(
           'paper=s' => \$paper,
           'no-top' => \$no_top,
           'no-bottom' => \$no_bottom,
           'no-inner' => \$no_inner,
           'no-outer' => \$no_outer,
           'one-side' => \$oneside,
           help => \$help,
           version => \$version,
          ) or die;

if ($help) {
    pod2usage(get_version());
    exit;
}

if ($version) {
    print get_version();
    exit;
}


my ($input, $output) = @ARGV;
die "Missing input file" unless $input && -f $input;
die "Missing output file" unless $output && $output =~ m/\w/;

if (-e $output) {
    unlink $output or die "Cannot remove $output: $!\n";
}

if ($no_top && $no_bottom) {
    warn "You specified no-top and no-bottom, centering instead\n";
}

if ($no_inner && $no_outer) {
    warn "You specified no-inner and no-outer, centering instead\n";
}

my $crop = PDF::Cropmarks->new(input => $input,
                               output => $output,
                               paper => $paper,
                               top => !$no_top,
                               bottom => !$no_bottom,
                               inner => !$no_inner,
                               outer => !$no_outer,
                               twoside => !$oneside,
                              );
$crop->add_cropmarks;


sub get_version {
    return "Using PDF::Cropmarks version " . $PDF::Cropmarks::VERSION . "\n";
}

=head1 NAME

pdf-cropmarks.pl -- Use PDF::Cropmarks to add cropmarks to an existing PDF.

=head1 SYNOPSIS

  pdf-cropmarks.pl [ options ] input.pdf output.pdf

Both the input file and output file must be specified. The output file
is replaced if already exists.

=head2 Options

=over 4

=item --paper

The dimensions of the output PDF.

You can specify the dimension providing a (case insensitive) string
with the paper name (2a, 2b, 36x36, 4a, 4b, a0, a1, a2, a3, a4, a5,
a6, b0, b1, b2, b3, b4, b5, b6, broadsheet, executive, ledger, legal,
letter, tabloid) or a string with width and height separated by a
column, like C<11cm:200mm>. Supported units are mm, in, pt and cm.

=item --no-top

No margins (and no cropmarks on the top of the page).

=item --no-bottom

No margins (and no cropmarks on the bottom of the page).

=item --no-inner

No margins (and no cropmarks) on the inner margins of the page. By
default inner sides are the left margins on odd pages, and right
margins on even pages. If --one-side is specified, the inner margins
are always the left one.

=item --no-outer

Same as --no-inner, but for the outer margins.

=item --one-side

Affects how to consider --no-outer or --no-inner. If this flag is set,
outer margins are always the right one, and inner are always the left
ones.

=item --help

Show this help and exit.

=item --version

Show the PDF::Cropmarks version and exit.

=back

=cut

#!perl

use strict;
use warnings;
use File::Spec::Functions qw/catfile/;
use PDF::Cropmarks;
use Data::Dumper;
use Test::More tests => 11;

my $impose = 1;
eval { require PDF::Imposition };
if ($@) {
    $impose = 0;
}

my $input = catfile(qw/t test-input.pdf/);
my $output = catfile(qw/t test-output-thickness.pdf/);
my $impout = catfile(qw/t test-output-thickness-imposed.pdf/);

{
    my $cropper = PDF::Cropmarks->new(input => $input,
                                  paper => 'a4',
                                  signature => 1,
                                  output => $output);
    is $cropper->total_output_pages, 12, "out pages ok";
}

{
    my $cropper = PDF::Cropmarks->new(input => $input,
                                  paper => 'a4',
                                  signature => 0,
                                  output => $output);
    is $cropper->total_output_pages, 12, "out pages ok with signature == 0";
}

{
    my $cropper = PDF::Cropmarks->new(input => $input,
                                  paper => 'a4',
                                  signature => 13,
                                  output => $output);
    eval { $cropper->total_output_pages };
    ok $@, "Found exception with signature not multiple of 4";
}

{
    my $cropper = PDF::Cropmarks->new(input => $input,
                                  paper => 'a4',
                                  signature => 4,
                                  output => $output);
    my %thicks = map { $_ => "0.000" } 1..12;
    off_is_deeply($cropper->thickness_page_offsets, \%thicks, "mapping ok for sig 4")
      or diag Dumper($cropper->thickness_page_offsets) . " vs " . Dumper(\%thicks);
}

{
    my $cropper = PDF::Cropmarks->new(input => $input,
                                  paper => 'a4',
                                  signature => 8,
                                  output => $output);
    my $thin = $cropper->paper_thickness_in_pt;
    diag "Paper thickness is $thin";
    my %thicks = (
                  1 => $thin,
                  2 => $thin,
                  3 => '0.000',
                  4 => '0.000',
                  5 => '0.000',
                  6 => '0.000',
                  7 => $thin,
                  8 => $thin,
                  9 => $thin,
                  10 => $thin,
                  11 => '0.000',
                  12 => '0.000',
                  13 => '0.000',
                  14 => '0.000',
                  15 => $thin,
                  16 => $thin,
                 );
    off_is_deeply($cropper->thickness_page_offsets, \%thicks, "map ok for sig 8")
      or diag Dumper($cropper->thickness_page_offsets) . " vs " . Dumper(\%thicks);
}

foreach my $signature (1, 12) {
    my $cropper = PDF::Cropmarks->new(input => $input,
                                      paper => 'a4',
                                      # 1 and 12 are the same for this pdf
                                      signature => $signature,
                                      output => $output);
    my $thin = $cropper->paper_thickness_in_pt;
    diag "Paper thickness is $thin";
    my %thicks = (
                  1 => $thin * 2,
                  2 => $thin * 2,
                  3 => $thin,
                  4 => $thin,
                  5 => '0.000',
                  6 => '0.000',
                  7 => '0.000',
                  8 => '0.000',
                  9 => $thin,
                  10 => $thin,
                  11 => $thin * 2,
                  12 => $thin * 2,
                 );
    off_is_deeply($cropper->thickness_page_offsets, \%thicks, "map ok for sig 8")
      or diag Dumper($cropper->thickness_page_offsets) . " vs " . Dumper(\%thicks);
}



{
    my $cropper = PDF::Cropmarks->new(input => $input,
                                      paper => 'a4',
                                      inner => 0,
                                      signature => 16,
                                      paper_thickness => '3cm',
                                      output => $output);

    ok ($cropper->paper_thickness_in_pt, "Thickness ok");
    is ($cropper->total_input_pages, 12, "Pages in ok");
    is ($cropper->total_output_pages, 16, "Pages out ok");
    my $thin = $cropper->paper_thickness_in_pt;
    diag "Paper thickness is $thin";

    my %thicks = (
                  1 => $thin * 3,
                  2 => $thin * 3,
                  3 => $thin * 2,
                  4 => $thin * 2,
                  5 => $thin * 1,
                  6 => $thin * 1,
                  7 => $cropper->_round(0),
                  8 => $cropper->_round(0),
                  9 => $cropper->_round(0),
                  10 => $cropper->_round(0),
                  11 => $thin * 1,
                  12 => $thin * 1,
                  13 => $thin * 2,
                  14 => $thin * 2,
                  15 => $thin * 3,
                  16 => $thin * 3,
                 );

    off_is_deeply($cropper->thickness_page_offsets, \%thicks, "Mapping ok")
      or diag Dumper($cropper->thickness_page_offsets) . " vs " . Dumper(\%thicks);
    $cropper->add_cropmarks;
    if ($impose) {
        my $imposer = PDF::Imposition->new(file => $output,
                                           outfile => $impout,
                                           signature => 16,
                                           schema => '2up');
        $imposer->impose;
        diag "Output left in " . $imposer->outfile;
    }
}

sub off_is_deeply {
    my ($got, $expected, $msg) = @_;
    my %offsets  = map { $_ => $got->{$_}->{offset} } keys %$got;
    is_deeply(\%offsets, $expected, $msg);
}

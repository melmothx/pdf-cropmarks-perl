#!perl
use utf8;
use strict;
use warnings;

use Test::More tests => 126;
use Data::Dumper;
use PDF::API2;
use PDF::Cropmarks;
use File::Spec::Functions qw/catfile catdir/;
use File::Temp;

my @out;

my $wd = File::Temp->newdir(CLEANUP => !$ENV{AMW_NOCLEANUP});

diag "Output in $wd";
diag "Set AMW_NOCLEANUP to true to avoid removing it" unless $ENV{AMW_NOCLEANUP};

foreach my $paper ('a4', 'a6', ' 150mm : 8in ') {
    foreach my $args (
                      {
                      },
                      {
                       title => "Title paper is $paper",
                      },
                      {
                       top => 0,
                       inner => 0,
                       bottom => 1,
                       outer => 1,
                       twoside => 1,
                       cropmark_length => '10mm',
                       cropmark_offset => '1mm',
                       font_size => '10pt',
                       signature => 1,
                       paper_thickness => '1mm',
                      },
                      {
                       top => 1,
                       inner => 1,
                       bottom => 0,
                       outer => 0,
                       twoside => 1,
                       cropmark_length => '1cm',
                       cropmark_offset => '8pt',
                       font_size => '8pt',
                       signature => 16,
                      },
                      {
                       top => 0,
                       inner => 0,
                       bottom => 1,
                       outer => 1,
                       twoside => 0,
                       cropmark_length => '1in',
                       cropmark_offset => '1MM',
                       font_size => '10pt',
                       signature => 4,
                      },
                      {
                       top => 1,
                       inner => 1,
                       bottom => 0,
                       outer => 0,
                       twoside => 0,
                       cropmark_length => '0.5IN',
                       cropmark_offset => '1MM',
                       font_size => '10PT',
                      }) {
        my $papername = $paper . join ('-', map { $_ => $args->{$_} }
                                       sort keys %$args);
        $papername =~ s/\W/-/g;
        my $output = catfile($wd, 'test-output-' . $papername . '.pdf');
        my $cropper = PDF::Cropmarks->new(input => catfile(qw/t test-input.pdf/),
                                          paper => uc($paper),
                                          output => $output,
                                          %$args,
                                         );
        ok $cropper->in_pdf_object;
        ok $cropper->out_pdf_object;
        ok $cropper->_tmpdir;
        ok (-d $cropper->_tmpdir, "Tmpdir exists : ". $cropper->_tmpdir);
        ok $cropper->add_cropmarks;
        ok (-f $output, "$output exists");

        my $pdf = PDF::API2->open($output);
        my $count = $pdf->pages;
        ok($count, "Found $count pages");
        # we can't really test much without looking at the output...
        # diag "Output left in $output";
        push @out, $output;
    }
}


diag "Output:\n" . join("\n", @out) if $ENV{AMW_NOCLEANUP};


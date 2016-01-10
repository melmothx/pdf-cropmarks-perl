#!perl
use utf8;
use strict;
use warnings;

use Test::More tests => 288;
use Data::Dumper;
use PDF::API2;
use PDF::Cropmarks;
use File::Spec::Functions qw/catfile catdir/;

my @out;

foreach my $paper ('a4', 'a5', 'a6', '150mm:8in', ' 15cm : 20cm ', 'letter') {
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
        my $output = catfile('t', 'test-output-' . $papername . '.pdf');
        unlink $output if -f $output;
        ok (! -f $output, "$output doesn't exists");
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


if ($ENV{AMW_DEBUG}) {
    diag "Output:\n" . join("\n", @out);
}
else {
    foreach my $file (@out) {
        unlink $file or die "Cannot remove $file $!";
    }
}



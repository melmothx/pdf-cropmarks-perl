#!perl
use utf8;
use strict;
use warnings;

use Test::More;
use Data::Dumper;
use PDF::API2;
use PDF::Cropmarks;
use File::Spec::Functions qw/catfile catdir/;

my @out;

foreach my $paper ('a4', 'a5', 'a6', '150mm:8in', ' 15cm : 20cm ', 'letter') {
    foreach my $args (
                      {
                       top => 1,
                       bottom => 1,
                      },
                      {
                       top => 0,
                       bottom => 1,
                      },
                      {
                       top => 1,
                       bottom => 0,
                      }) {
        my $papername = $paper
          . '-bottom-' . $args->{bottom}
          . '-top-' . $args->{top};
        $papername =~ s/\W/-/g;
        my $output = catfile('t', 'test-output-' . $papername . '.pdf');
        unlink $output if -f $output;
        ok (! -f $output, "$output doesn't exists");
        my $cropper = PDF::Cropmarks->new(file => catfile(qw/t test-input.pdf/),
                                          paper => uc($paper),
                                          output => $output,
                                          %$args,
                                         );
        ok $cropper->in_pdf_object;
        ok $cropper->out_pdf_object;
        ok $cropper->tmpdir;
        ok (-d $cropper->tmpdir, "Tmpdir exists") and diag $cropper->tmpdir;
        ok $cropper->add_cropmarks;
        ok (-f $output, "$output exists");

        my $pdf = PDF::API2->open($output);
        my $count = 0;
        while ($pdf->openpage($count + 1)) {
            $count++;
        }
        ok($count, "Found $count pages");
        # we can't really test much without looking at the output...
        diag "Output left in $output";
        push @out, $output;
    }
}

diag "Output:\n" . join("\n", @out);
done_testing;


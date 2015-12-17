#!perl
use utf8;
use strict;
use warnings;

use Test::More;
use Data::Dumper;
use PDF::Cropmarks;
use File::Spec::Functions qw/catfile catdir/;

my $output = catfile(qw/t test-output.pdf/);
unlink $output if -f $output;
ok (! -f $output, "$output doesn't exists");
my $cropper = PDF::Cropmarks->new(file => catfile(qw/t test-input.pdf/),
                                  output => $output);
ok $cropper->in_pdf_object;
ok $cropper->out_pdf_object;
ok $cropper->tmpdir;
ok (-d $cropper->tmpdir, "Tmpdir exists") and diag $cropper->tmpdir;
ok $cropper->add_cropmarks;
ok (-f $output, "$output exists");
done_testing;
print Dumper ($cropper);
unlink $output unless $ENV{PDFC_DEBUG};

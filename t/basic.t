#!perl
use utf8;
use strict;
use warnings;

use Test::More;
use PDF::Cropmarks;
use File::Spec::Functions qw/catfile catdir/;

my $cropper = PDF::Cropmarks->new(file => catfile(qw/t test-input.pdf/));
ok $cropper->in_pdf_object;
ok $cropper->out_pdf_object;
ok $cropper->tmpdir;
ok (-d $cropper->tmpdir, "Tmpdir exists") and diag $cropper->tmpdir;

done_testing;

                                  

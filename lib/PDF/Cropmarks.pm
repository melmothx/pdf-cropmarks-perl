package PDF::Cropmarks;

use utf8;
use strict;
use warnings;

use Moo;
use Types::Standard qw/Str Object/;
use File::Copy;
use File::Spec;
use File::Temp;
use PDF::API2;
use POSIX qw();
use namespace::clean;

use constant {
    DEBUG => !!$ENV{PDFC_DEBUG},
};


has file => (is => 'ro', isa => Str, required => 1);

has tmpdir => (is => 'ro',
               isa => Object,
               default => sub {
                   return File::Temp->newdir(CLEANUP => !DEBUG);
               });

has in_pdf => (is => 'lazy', isa => Str);

sub _build_in_pdf {
    my $self = shift;
    my $name = File::Spec->catfile($self->tmpdir, 'in.pdf');
    copy ($self->file, $name) or die "Cannot copy input to $name $!";
    return $name;
}

has in_pdf_object => (is => 'lazy', isa => Object);

sub _build_in_pdf_object {
    my $self = shift;
    my $input = eval { PDF::API2->open($self->in_pdf) };
    if (!$input || $@) {
        warn $@ if DEBUG && $@;
        # same as in PDF::Imposition::Schema
        require CAM::PDF;
        my $src = CAM::PDF->new($self->in_pdf);
        my $tmpfile_copy = File::Spec->catfile($self->tmpdir, 'v14.pdf');
        $src->cleansave();
        $src->output($tmpfile_copy);
        undef $src;
        $input = PDF::API2->open($tmpfile_copy);
    }
    if ($input) {
        return $input;
    }
    else {
        die "Cannot open " . $self->in_pdf unless $input;
    }
}

has out_pdf_object => (is => 'lazy', isa => Object);

sub _build_out_pdf_object {
    my $pdf = PDF::API2->new;
    my $now = POSIX::strftime(q{%Y%m%d%H%M%S+00'00'}, localtime(time()));
    $pdf->info(Creator => 'PDF::Imposition',
               Producer => 'PDF::API2',
               CreationDate => $now,
               ModDate => $now);
    return $pdf;
}



sub add_cropmarks {
    my $self = shift;
    return $self->in_pdf;
}

1;

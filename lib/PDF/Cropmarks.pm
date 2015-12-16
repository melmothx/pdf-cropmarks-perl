package PDF::Cropmarks;

use utf8;
use strict;
use warnings;

use Moo;
use Types::Standard qw/Str Object/;
use File::Copy;
use File::Spec;
use File::Temp;
use CAM::PDF;
use PDF::API2;
use namespace::clean;

has file => (is => 'ro', isa => Str, required => 1);

has tmpdir => (is => 'ro',
               isa => Object,
               default => sub {
                   return File::Temp->newdir(CLEANUP => 1);
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
    
    
}

sub add_cropmarks {
    my $self = shift;
    return $self->in_pdf;
}

1;

package PDF::Cropmarks::Page;

use utf8;
use strict;
use warnings;

use Moo;
use Types::Standard qw/Int Object/;
use Data::Dumper;
use namespace::clean;

use constant {
    DEBUG => !!$ENV{PDFC_DEBUG},
};

has page_number => (is => 'ro', isa => Int, required => 1);

has input_pdf => (is => 'ro', isa => Object, required => 1);

has output_pdf => (is => 'ro', isa => Object, required => 1);

sub import_page {
    my $self = shift;
    my $page = $self->output_pdf->page;
    my ($llx, $lly, $urx, $ury) = $page->get_mediabox;
    die "mediabox origins for output pdf should be zero" if $llx + $lly;
    print "$llx, $lly, $urx, $ury\n" if DEBUG;
    my ($inllx, $inlly, $inurx, $inury) =
      $self->input_pdf->openpage($self->page_number)->get_mediabox;
    print "$inllx, $inlly, $inurx, $inury\n" if DEBUG;
    die "mediabox origins for input pdf should be zero" if $inllx + $inlly;
    # place the content into page
    my $offset_x = int(($urx - $inurx) / 2);
    my $offset_y = int(($ury - $inury) / 2);
    print "Offsets are $offset_x, $offset_y\n" if DEBUG;
    my $xo = $self->output_pdf->importPageIntoForm($self->input_pdf,
                                                   $self->page_number);
    my $gfx = $page->gfx;
    $gfx->formimage($xo, $offset_x, $offset_y);
    if (DEBUG) {
        my $line = $page->gfx;
        $line->strokecolor('black');
        $line->linewidth(1);
        $line->rectxy($offset_x, $offset_y,
                      $offset_x + $inurx, $offset_y + $inury);
        $line->stroke;
    }
}

1;

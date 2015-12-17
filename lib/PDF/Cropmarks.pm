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
use PDF::API2::Util;
use POSIX qw();
use namespace::clean;

use constant {
    DEBUG => !!$ENV{PDFC_DEBUG},
};


has file => (is => 'ro', isa => Str, required => 1);

has output => (is => 'ro', isa => Str, required => 1);

has paper => (is => 'ro', isa => Str, default => sub { 'a4' });

has tmpdir => (is => 'ro',
               isa => Object,
               default => sub {
                   return File::Temp->newdir(CLEANUP => !DEBUG);
               });

has in_pdf => (is => 'lazy', isa => Str);

has out_pdf => (is => 'lazy', isa => Str);

sub _build_in_pdf {
    my $self = shift;
    my $name = File::Spec->catfile($self->tmpdir, 'in.pdf');
    copy ($self->file, $name) or die "Cannot copy input to $name $!";
    return $name;
}

sub _build_out_pdf {
    my $self = shift;
    my $name = File::Spec->catfile($self->tmpdir, 'out.pdf');
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
    my $self = shift;
    my $pdf = PDF::API2->new;
    my $now = POSIX::strftime(q{%Y%m%d%H%M%S+00'00'}, localtime(time()));
    $pdf->info(Creator => 'PDF::Imposition',
               Producer => 'PDF::API2',
               CreationDate => $now,
               ModDate => $now);
    $pdf->mediabox($self->paper_dimensions);
    return $pdf;
}

sub paper_dimensions {
    my $self = shift;
    my $paper = $self->paper;
    my %sizes = PDF::API2::Util::getPaperSizes();
    if (my $dimensions = %sizes{lc($self->paper)}) {
        return @$dimensions;
    }
    else {
        warn "Cannot get dimensions from $paper, using A4";
        return @{$sizes{a4}};
    }
}


sub add_cropmarks {
    my $self = shift;
    my $page = 1;
    while (my $pageobj = $self->in_pdf_object->openpage($page)) {
        print "Importing page $page\n" if DEBUG;
        $self->import_page($pageobj, $page);
        $page++;
    }
    $self->out_pdf_object->saveas($self->out_pdf);
    $self->in_pdf_object->end;
    $self->out_pdf_object->end;
    move($self->out_pdf, $self->output)
      or die "Cannot copy " . $self->out_pdf . ' to ' . $self->output;
    return $page;
}

sub import_page {
    my ($self, $in_page, $page_number) = @_;
    my $page = $self->out_pdf_object->page;
    my ($llx, $lly, $urx, $ury) = $page->get_mediabox;
    die "mediabox origins for output pdf should be zero" if $llx + $lly;
    print "$llx, $lly, $urx, $ury\n" if DEBUG;
    my ($inllx, $inlly, $inurx, $inury) = $in_page->get_mediabox;
    print "$inllx, $inlly, $inurx, $inury\n" if DEBUG;
    die "mediabox origins for input pdf should be zero" if $inllx + $inlly;
    # place the content into page
    my $offset_x = int(($urx - $inurx) / 2);
    my $offset_y = int(($ury - $inury) / 2);
    print "Offsets are $offset_x, $offset_y\n" if DEBUG;
    my $xo = $self->out_pdf_object->importPageIntoForm($self->in_pdf_object,
                                                       $page_number);
    my $gfx = $page->gfx;
    $gfx->formimage($xo, $offset_x, $offset_y);
    if (DEBUG) {
        my $line = $page->gfx;
        $line->strokecolor('black');
        $line->linewidth(0.5);
        $line->rectxy($offset_x, $offset_y,
                      $offset_x + $inurx, $offset_y + $inury);
        $line->stroke;
    }
    my $crop = $page->gfx;
    $crop->strokecolor('black');
    $crop->linewidth(0.5);
    my $crop_width = 30;
    my $crop_offset = 8;
    # left bottom corner
    $crop->move($offset_x - $crop_width - $crop_offset, $offset_y);
    $crop->line($offset_x - $crop_offset,               $offset_y);

    $crop->move($offset_x, $offset_y - $crop_offset);
    $crop->line($offset_x, $offset_y - $crop_offset - $crop_width);

    # right bottom corner
    $crop->move($offset_x + $inurx + $crop_offset, $offset_y);
    $crop->line($offset_x + $inurx + $crop_offset + $crop_width, $offset_y);

    $crop->move($offset_x + $inurx,
                $offset_y - $crop_offset);
    $crop->line($offset_x + $inurx,
                $offset_y - $crop_offset - $crop_width);

    # top right corner
    $crop->move($offset_x + $inurx + $crop_offset,
                $offset_y + $inury);
    $crop->line($offset_x + $inurx + $crop_offset + $crop_width,
                $offset_y + $inury);

    $crop->move($offset_x + $inurx,
                $offset_y + $inury + $crop_offset);
    $crop->line($offset_x + $inurx,
                $offset_y + $inury + $crop_offset + $crop_width);

    # top left corner
    $crop->move($offset_x, $offset_y + $inury + $crop_offset);
    $crop->line($offset_x, $offset_y + $inury + $crop_offset + $crop_width);

    $crop->move($offset_x - $crop_offset, $offset_y + $inury);
    $crop->line($offset_x - $crop_offset - $crop_width, $offset_y + $inury);

    # and stroke
    $crop->stroke;

    # then add the text
    my $text = $page->text;
    my $marker = sprintf('Pg %.4d', $page_number);
    $text->font($self->out_pdf_object->corefont('Courier'), int($crop_offset - 1));
    $text->fillcolor('black');

    # bottom left
    $text->translate($offset_x - (($crop_width + $crop_offset)),
                     $offset_y - (($crop_width + $crop_offset)));
    $text->text($marker);

    # bottom right
    $text->translate($inurx + $offset_x + $crop_offset,
                     $offset_y - (($crop_width + $crop_offset)));
    $text->text($marker);

    # top left
    $text->translate($offset_x - (($crop_width + $crop_offset)),
                     $offset_y + $inury + $crop_width);
    $text->text($marker);

    # top right
    $text->translate($inurx + $offset_x + $crop_offset,
                     $offset_y + $inury + $crop_width);
    $text->text($marker);
}



1;

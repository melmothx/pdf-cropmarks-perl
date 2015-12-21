package PDF::Cropmarks;

use utf8;
use strict;
use warnings;

use Moo;
use Types::Standard qw/Str Object Bool StrictNum/;
use File::Copy;
use File::Spec;
use File::Temp;
use PDF::API2;
use PDF::API2::Util;
use POSIX qw();
use File::Basename qw/fileparse/;
use namespace::clean;

use constant {
    DEBUG => !!$ENV{PDFC_DEBUG},
};

=encoding utf8

=head1 NAME

PDF::Cropmarks - Add cropmarks to existing PDFs

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

This module prepares PDF for printing adding the cropmarks, usually on
a larger physical page, doing the same thing the LaTeX package "crop"
does.

It comes with a ready-made script, C<pdf-cropmarks.pl>. E.g.

 $ pdf-cropmarks.pl --help # usage
 $ pdf-cropmarks.pl --paper a3 input.pdf output.pdf

To use the module in your code:

  use strict;
  use warnings;
  use PDF::Cropmarks;
  PDF::Cropmarks->new(input => $input,
                      output => $output,
                      paper => $paper,
                      # other options here
                     )->add_cropmarks;

If everything went well (no exceptions thrown), you will find the new
pdf in the output you provided.

=cut

our $VERSION = '0.01';

=head1 ACCESSORS

The following options need to be passed to the constructor and are
read-only.

=head2 input <file>

The filename of the input. Required.

=head2 output

The filename of the output. Required.

=head2 paper

This module each logical page of the original PDF into a larger
physical page, adding the cropmarks in the margins. With this option
you can control the dimension of the output paper.

You can specify the dimension providing a (case insensitive) string
with the paper name (2a, 2b, 36x36, 4a, 4b, a0, a1, a2, a3, a4, a5,
a6, b0, b1, b2, b3, b4, b5, b6, broadsheet, executive, ledger, legal,
letter, tabloid) or a string with width and height separated by a
column, like C<11cm:200mm>. Supported units are mm, in, pt and cm.

An exception is thrown if the module is not able to parse the input
provided.

=head2 Positioning

The following options control where the logical page is put on the
physical one. They all default to true, meaning that the logical page
is centered. Setting top and bottom to false, or inner and outer to
false makes no sense (you achieve the same result specifing a paper
with the same width or height) and thus ignored, resulting in a
centering.

=over 4

=item top

=item bottom

=item inner

=item outer

=back

=head2 twoside

Boolean, defaults to true.

This option affects the positioning, if inner or outer are set to
false. If C<twoside> is true (default), inner margins are considered
the left ones on an the recto pages (the odd-numbered ones). If set to
false, the left margin is always considered the inner one.

=head2 cropmark_length

Default: 12mm

The length of the cropmark line.

=head2 cropmark_offset

Default: 3mm

The distance from the logical page corner and the cropmark line.

=head2 font_size

Default: 8pt

The font size of the headers and footers with the job name, date, and
page numbers.

=cut

has cropmark_length => (is => 'ro', isa => Str, default => sub { '12mm' });

has cropmark_offset => (is => 'ro', isa => Str, default => sub { '3mm' });

has font_size => (is => 'ro', isa => Str, default => sub { '8pt' });

has cropmark_length_in_pt => (is => 'lazy', isa => StrictNum);
has cropmark_offset_in_pt => (is => 'lazy', isa => StrictNum);
has font_size_in_pt => (is => 'lazy', isa => StrictNum);

sub _build_cropmark_length_in_pt {
    my $self = shift;
    return $self->_string_to_pt($self->cropmark_length);
}
sub _build_cropmark_offset_in_pt {
    my $self = shift;
    return $self->_string_to_pt($self->cropmark_offset);
}

sub _build_font_size_in_pt {
    my $self = shift;
    return $self->_string_to_pt($self->font_size);
}


sub _measure_re {
    return qr{([0-9]+(\.[0-9]+)?)
              (mm|in|pt|cm)}sxi;
}

sub _string_to_pt {
    my ($self, $string) = @_;
    my %compute = (
                   mm => sub { $_[0] / (25.4 / 72) },
                   in => sub { $_[0] / (1 /72) },
                   pt => sub { $_[0] / 1 },
                   cm => sub { $_[0] / (25.4 / 72) * 10 },
                  );
    my $re = $self->_measure_re;
    if ($string =~ $re) {
        my $size = $1;
        my $unit = lc($3);
        return sprintf('%.2f', $compute{$unit}->($size));
    }
    else {
        die "Unparsable measure string $string";
    }
}

=head1 METHODS

=head2 add_cropmarks

This is the only public method: create the new pdf from C<input> and
leave it in C<output>.

=cut

has input => (is => 'ro', isa => Str, required => 1);

has output => (is => 'ro', isa => Str, required => 1);

has paper => (is => 'ro', isa => Str, default => sub { 'a4' });

has _tmpdir => (is => 'ro',
                isa => Object,
                default => sub {
                    return File::Temp->newdir(CLEANUP => !DEBUG);
                });

has in_pdf => (is => 'lazy', isa => Str);

has out_pdf => (is => 'lazy', isa => Str);

has basename => (is => 'lazy', isa => Str);

has timestamp => (is => 'lazy', isa => Str);

sub _build_basename {
    my $self = shift;
    my $basename = fileparse($self->input, qr{\.pdf}i);
    return $basename;
}

sub _build_timestamp {
    my $now = localtime();
    return $now;
}

has top => (is => 'ro', isa => Bool, default => sub { 1 });
has bottom => (is => 'ro', isa => Bool, default => sub { 1 });
has inner => (is => 'ro', isa => Bool, default => sub { 1 });
has outer => (is => 'ro', isa => Bool, default => sub { 1 });
has twoside => (is => 'ro', isa => Bool, default => sub { 1 });

sub _build_in_pdf {
    my $self = shift;
    my $name = File::Spec->catfile($self->_tmpdir, 'in.pdf');
    copy ($self->input, $name) or die "Cannot copy input to $name $!";
    return $name;
}

sub _build_out_pdf {
    my $self = shift;
    return File::Spec->catfile($self->_tmpdir, 'out.pdf');
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
        my $tmpfile_copy = File::Spec->catfile($self->_tmpdir, 'v14.pdf');
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
    $pdf->mediabox($self->_paper_dimensions);
    return $pdf;
}

sub _paper_dimensions {
    my $self = shift;
    my $paper = $self->paper;
    my %sizes = PDF::API2::Util::getPaperSizes();
    my $measure_re = $self->_measure_re;
    if (my $dimensions = $sizes{lc($self->paper)}) {
        return @$dimensions;
    }
    elsif ($paper =~ m/\A\s*
                       $measure_re
                       \s*:\s*
                       $measure_re
                       \s*\z/sxi) {
        # 3 + 3 captures
        my $xsize = $1;
        my $xunit = $3;
        my $ysize = $4;
        my $yunit = $6;
        return ($self->_string_to_pt($xsize . $xunit),
                $self->_string_to_pt($ysize . $yunit));
    }
    else {
        die "Cannot get dimensions from $paper, using A4";
    }
}


sub add_cropmarks {
    my $self = shift;
    my $page = 1;
    while (my $pageobj = $self->in_pdf_object->openpage($page)) {
        print "Importing page $page\n" if DEBUG;
        $self->_import_page($pageobj, $page);
        $page++;
    }
    $self->out_pdf_object->saveas($self->out_pdf);
    $self->in_pdf_object->end;
    $self->out_pdf_object->end;
    move($self->out_pdf, $self->output)
      or die "Cannot copy " . $self->out_pdf . ' to ' . $self->output;
    return $page;
}

sub _round {
    my ($self, $float) = @_;
    $float || 0;
    return sprintf('%.2f', $float);
}

sub _import_page {
    my ($self, $in_page, $page_number) = @_;
    my $page = $self->out_pdf_object->page;
    my ($llx, $lly, $urx, $ury) = $page->get_mediabox;
    die "mediabox origins for output pdf should be zero" if $llx + $lly;
    print "$llx, $lly, $urx, $ury\n" if DEBUG;
    my ($inllx, $inlly, $inurx, $inury) = $in_page->get_mediabox;
    print "$inllx, $inlly, $inurx, $inury\n" if DEBUG;
    die "mediabox origins for input pdf should be zero" if $inllx + $inlly;
    # place the content into page

    my $offset_x = $self->_round(($urx - $inurx) / 2);
    my $offset_y = $self->_round(($ury - $inury) / 2);

    # adjust offset if bottom or top are missing. Both missing doesn't
    # make much sense
    if (!$self->bottom && !$self->top) {
        # warn "bottom and top are both false, centering\n";
    }
    elsif (!$self->bottom) {
        $offset_y = 0;
    }
    elsif (!$self->top) {
        $offset_y *= 2;
    }

    if (!$self->inner && !$self->outer) {
        # warn "inner and outer are both false, centering\n";
    }
    elsif (!$self->inner) {
        if ($self->twoside and !($page_number % 2)) {
            $offset_x *= 2;
        }
        else {
            $offset_x = 0;
        }
    }
    elsif (!$self->outer) {
        if ($self->twoside and !($page_number % 2)) {
            $offset_x = 0;
        }
        else {
            $offset_x *= 2;
        }
    }
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
    my $crop_width = $self->cropmark_length_in_pt;
    my $crop_offset = $self->cropmark_offset_in_pt;
    # left bottom corner
    $self->_draw_line($crop,
                      ($offset_x - $crop_offset,               $offset_y),
                      ($offset_x - $crop_width - $crop_offset, $offset_y));


    $self->_draw_line($crop,
                      ($offset_x, $offset_y - $crop_offset),
                      ($offset_x, $offset_y - $crop_offset - $crop_width));

    # right bottom corner
    $self->_draw_line($crop,
                      ($offset_x + $inurx + $crop_offset, $offset_y),
                      ($offset_x + $inurx + $crop_offset + $crop_width,
                       $offset_y));
    $self->_draw_line($crop,
                      ($offset_x + $inurx,
                       $offset_y - $crop_offset),
                      ($offset_x + $inurx,
                       $offset_y - $crop_offset - $crop_width));

    # top right corner
    $self->_draw_line($crop,
                      ($offset_x + $inurx + $crop_offset,
                       $offset_y + $inury),
                      ($offset_x + $inurx + $crop_offset + $crop_width,
                       $offset_y + $inury));

    $self->_draw_line($crop,
                      ($offset_x + $inurx,
                       $offset_y + $inury + $crop_offset),
                      ($offset_x + $inurx,
                       $offset_y + $inury + $crop_offset + $crop_width));

    # top left corner
    $self->_draw_line($crop,
                      ($offset_x, $offset_y + $inury + $crop_offset),
                      ($offset_x,
                       $offset_y + $inury + $crop_offset + $crop_width));

    $self->_draw_line($crop,
                      ($offset_x - $crop_offset,
                       $offset_y + $inury),
                      ($offset_x - $crop_offset - $crop_width,
                       $offset_y + $inury));

    # and stroke
    $crop->stroke;

    # then add the text
    my $text = $page->text;
    my $marker = sprintf('Pg %.4d', $page_number);
    $text->font($self->out_pdf_object->corefont('Courier'),
                $self->_round($self->font_size_in_pt));
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

    my $text_marker = $self->basename . ' ' . $self->timestamp .
      ' page ' . $page_number;
    # and at the top and and the bottom add jobname + timestamp
    $text->translate(($inurx / 2) + $offset_x,
                     $offset_y + $inury + $crop_width);
    $text->text_center($text_marker);

    $text->translate(($inurx / 2) + $offset_x,
                     $offset_y - ($crop_width + $crop_offset));
    $text->text_center($text_marker);
}

sub _draw_line {
    my ($self, $gfx, $from_x, $from_y, $to_x, $to_y) = @_;
    $gfx->move($from_x, $from_y);
    $gfx->line($to_x, $to_y);
    my $radius = 3;
    $gfx->circle($to_x, $to_y, $radius);
    $gfx->move($to_x - $radius, $to_y);
    $gfx->line($to_x + $radius, $to_y);
    $gfx->move($to_x, $to_y - $radius);
    $gfx->line($to_x, $to_y + $radius);
}

=head1 AUTHOR

Marco Pessotto, C<< <melmothx at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to the CPAN's RT or at
L<https://github.com/melmothx/pdf-cropmarks-perl/issues>. If you find
a bug, please provide a minimal example file which reproduces the
problem.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of either: the GNU General Public License as
published by the Free Software Foundation; or the Artistic License.

=cut


1;

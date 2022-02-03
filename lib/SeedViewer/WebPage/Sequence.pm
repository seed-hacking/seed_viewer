package SeedViewer::WebPage::Sequence;

use base qw( WebPage );

use FIG_Config;

use URI::Escape;

use strict;
use warnings;

use Data::Dumper;

1;

=pod

=head2 NAME

Sequence - an instance of WebPage which displays a sequence

=head2 DESCRIPTION

Display a sequence

=head2 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->application->no_bot(1);

  return 1;
}

=item * B<output> ()

Returns the html output of the Sequence page.

=cut

sub output {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;

  unless (defined($cgi->param('feature'))) {
    $application->add_message('warning', 'Sequence page called without an identifier');
    return "";
  }

  my $html = '';
  my $fig = $application->data_handle('FIG');

  # check if we have a valid fig
  unless ($fig) {
    $application->add_message('warning', 'Invalid organism id');
    return "";
  }

  my $id = $cgi->param('feature');
  my $type = $cgi->param('type') || 'dna';

  $application->menu->add_category('&raquo;Back to Annotation', "?page=Annotation&feature=$id");

  # prepare information
  my $function = $fig->function_of($id);
  my $genome = $fig->genome_of($id);
  my $genome_name = $fig->genus_species($genome);
  my $feature_location = $fig->feature_location($id);

  $self->title("Sequence for $id from $genome_name");

  my $sequence = "";

  if ($type eq 'dna') {

    # get sequence information
    $sequence = "<h2>DNA Sequence for $id from $genome_name</h2>";
    if (my $seq = $fig->dna_seq($genome,$feature_location)) {
      $sequence .= "<pre>>$id $function\n";
      for (my $i=0; ($i < length($seq)); $i += 60) {
	if ($i > (length($seq) - 60)) {
	  $sequence .= substr($seq,$i) . "\n";
	} else {
	  $sequence .= substr($seq,$i,60) . "\n";
	}
      }
      $sequence .= "</pre>";
    } else {
      $sequence .= "No DNA sequence available for $id";
    }

  } elsif ($type eq 'dna_flanking') {
    $sequence = "<h2>DNA and flanking Sequence for $id from $genome_name</h2>";
    my $additional = $cgi->param('additional') || 500;
    $sequence .= $self->start_form('sequence_form', { type => 'dna_flanking', feature => $id })."length of flanking sequence <input type='text' value='".$additional."' name='additional' size='4'>bp " . $self->button('show') . $self->end_form();
    my @loc = split /,/, $feature_location;
    my ($contig, $beg, $end) = BasicLocation::Parse($loc[0]);
    if(defined($contig) and defined($beg) and defined($end)) {
      my ( $n1, $npre );
      if ( $beg < $end ) {
	$n1 = $beg - $additional;
	$n1 = 1 if $n1 < 1;
	$npre = $beg - $n1;
      } else {
	$n1 = $beg + $additional;
	my $clen = $fig->contig_ln( $genome, $contig );
	$n1 = $clen if $n1 > $clen;
	$npre = $n1 - $beg;
      }
      $loc[0] = join( '_', $contig, $n1, $end );

      # Add to the end of the last segment:
      ( $contig, $beg, $end ) = BasicLocation::Parse($loc[-1]);
      my ( $n2, $npost );
      if ( $beg < $end ) {
	$n2 = $end + $additional;
	my $clen = $fig->contig_ln( $genome, $contig );
	$n2 = $clen if $n2 > $clen;
	$npost = $n2 - $end;
      } else {
	$n2 = $end - $additional;
	$n2 = 1 if $n2 < 1;
	$npost = $end - $n2;
      }
      $loc[-1] = join( '_', $contig, $beg, $n2 );

      my $seq = $fig->dna_seq( $genome, join( ',', @loc ) );
      if ( ! $seq ) {
	$sequence .= "No DNA sequence available for $id";
      } else {

	my $len = length( $seq );         # Get length before adding newlines
	$seq =~ s/(.{60})/$1\n/g;         # Cleaver way to wrap the sequence
	my $p1 = $npre + int( $npre/60 ); # End of prefix, adjusted for newlines
	my $p2 = $len - $npost;           # End of data,
	$p2 += int( $p2/60 );             # adjusted for newlines
	my $diff = $p2 - $p1;             # Characters of data

	$seq = substr($seq, 0, $p1) . '<span style="color:red">' . substr($seq, $p1, $diff) . '</span>' . substr($seq, $p2);

	$sequence .= "<pre>>$id $function\n$seq\n</pre>";
      }
    } else {
      $sequence .= "No DNA sequence available for $id";
    }
  } else {
    $sequence = "<h2>Protein Sequence for $id from $genome_name</h2>";
    if (my $seq = $fig->get_translation($id)) {
      $sequence .= "<pre>>$id $function\n";
      for (my $i=0; ($i < length($seq)); $i += 60) {
	if ($i > (length($seq) - 60)) {
	  $sequence .= substr($seq,$i) . "\n";
	} else {
	  $sequence .= substr($seq,$i,60) . "\n";
	}
      }
      $sequence .= "</pre>";
    } else {
      $sequence .= "No translation available for $id";
    }
  }

  return $sequence;
}

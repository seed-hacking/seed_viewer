package SeedViewer::WebPage::Regulon;

use base qw( WebPage );

use strict;
use warnings;

1;

use FIG_Config;

=pod

=head1 NAME

Regulon - an instance of WebPage which displays a regulon

=head1 DESCRIPTION

Displays regulons

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('Regulon');
  $self->application->register_component('Table', 'RegulonTable');
  $self->application->register_component('RegionDisplay', 'OperonRegion');
  $self->application->register_component('Ajax', 'RegAjax');

  return 1;
}

=item * B<output> ()

Returns the html output of the Regulon page.

=cut

sub output {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;

  my $fig = $application->data_handle('FIG');

  # check if we have a valid fig
  unless ($fig) {
    $application->add_message('warning', 'Invalid organism id');
    return "";
  }

  # create the regulon table
  my $reg_table = $application->component('RegulonTable');
  $reg_table->columns( [ { name => 'regulon' }, { name => 'regulator', filter => 1 }, { name => 'genome', filter => 1 }, { name => 'feature', filter => 1 } ] );
  $reg_table->items_per_page(25);
  $reg_table->show_select_items_per_page(1);
  $reg_table->show_top_browse(1);
  $reg_table->show_bottom_browse(1);
  if (open(FH, $FIG_Config::temp."/Regulons.csv")) {
    my $data = [];
    my $hl = <FH>;
    $hl = <FH>;
    while (<FH>) {
      my @row = split /\t/;
      push(@$data, [ qq~<a href="javascript:execute_ajax('show_operons', 'operon_cell', 'regulon=~ . $row[0] . qq~');">~.$row[0]."</a>", $row[2], "<a href='?page=Organism&organism=".$row[3]."' target=_blank>".$row[1]."</a>", "<a href='?page=Annotation&feature=".$row[4]."' target=_blank>".$row[4]."</a>" ]);
    }
    close FH;
    $reg_table->data($data);
  } else {
    $application->add_message('warning', "Could not open Regulons file: $@");
    return "";
  }

  # start the output
  my $html = "<h2>Shewanella Regulons</h2>";

  # print the ajax
  my $ajax = $application->component('RegAjax');
  $html .= $ajax->output();

  # print the regulon table
  $html .= "<table><tr>";
  $html .= "<td rowspan=2>" . $reg_table->output() . "</td>";
  
  # make space for the operon table and compared region
  $html .= "<td><span id='operon_cell'></span><br><span id='compared_region'></span></td></tr>";

  return $html;
}

sub show_operons {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;
  my $fig = $application->data_handle('FIG');

  my $regulon = $cgi->param('regulon');

  my $html = "<h3>Operon data for Regulon $regulon</h3>";
  
  $html .= "<form id='op_form'><select name='op'>";
  if (open(FH, $FIG_Config::temp."/Operons.csv")) {
    my $hl = <FH>;
    $hl = <FH>;
    while (<FH>) {
      my @row = split /\t/;
      next unless ($row[0] eq $regulon);
      $html .= "<option value='".$row[1]."~".$row[4]."'>".$row[2]." in " . $fig->genus_species($row[3]) . "</option>";
    }
  } else {
    return "<h2>Error opening operons file: $@</h2>";
  }
  $html .= qq~</select><input type='button' value='show region' onclick="execute_ajax('show_region', 'compared_region', 'op_form');"></form>~;

  return $html;
}

sub show_region {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;
  my $fig = $application->data_handle('FIG');

  my $op = $cgi->param('op');
  my ($operon, $feature) = split(/~/, $op);

  my ($seq, $score, $pos, $genome);
  if (open(FH, $FIG_Config::temp."/Sites.csv")) {
    my $hl = <FH>;
    $hl = <FH>;
    while (<FH>) {
      my @row = split /\t/;
      next unless ($row[1] eq $operon);
      $seq = $row[2];
      $score = $row[3];
      $pos = $row[4];
      $genome = $row[5];
      chomp $genome;
      last;
    }
  } else {
    return "<h2>Error opening sites file: $@</h2>";
  }

  my ($contig, $beg, $end) = $fig->boundaries_of($fig->feature_location($feature));
  my $start = $beg;
  if ($beg > $end) {
    $start -= $pos;
  } else {
    $start += $pos;
  }
  my $stop = $start + length($seq);
  my $region = $application->component('OperonRegion');
  my $feats = { $genome => [ { contig => $contig,
			       start => $start,
			       stop => $stop,
			       name => $seq,
			       type => "bs",
			       function => "Operon binding site, score $score at position $pos" } ] };
  $region->add_features( $feats );
  $region->control_form('none');
  $cgi->param('feature', $feature);
  $region->{show_genomes} = ['351745.7',
			     '323850.3',
			     '398579.3',
			     '60481.10',
			     '60480.16',
			     '326297.7',
			     '319224.13',
			     '318167.10',
			     '325240.3',
			     '211586.1',
			     '425104.3',
			     '94122.5',
			     '318161.14'];
   $cgi->param('number_of_regions', 13);

  return $region->output();
}

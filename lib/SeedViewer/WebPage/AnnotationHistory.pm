package SeedViewer::WebPage::AnnotationHistory;

use base qw( WebPage );

use FIG_Config;

use URI::Escape;

use strict;
use warnings;

use Data::Dumper;

1;

=pod

=head1 NAME

AnnotationHistory - an instance of WebPage which displays the Annotation history for
a feature and it's closest similars.

=head1 DESCRIPTION

Display information about an AnnotationHistory

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('Annotation History');
  $self->application->no_bot(1);
  $self->application->register_component('Table', 'HistoryTable');

  return 1;
}

=item * B<output> ()

Returns the html output of the AnnotationHistory page.

=cut

sub output {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;

  unless (defined($cgi->param('feature'))) {
    $application->add_message('warning', 'Feature page called without an identifier');
    return "";
  }

  my $fig = $application->data_handle('FIG');

  # check if we have a valid fig
  unless ($fig) {
    $application->add_message('warning', 'Invalid organism id');
    return "";
  }

  my $id = $cgi->param('feature');
  my $org = $fig->genome_of($id);

  # create menu
  $application->menu->add_category('&raquo;Organism');
  $application->menu->add_entry('&raquo;Organism', 'General Information', '?page=Organism&organism='.$org);
  $application->menu->add_entry('&raquo;Organism', 'Genome Browser', '?page=BrowseGenome&organism='.$org);
  $application->menu->add_entry('&raquo;Organism', 'Scenarios', '?page=Scenarios&organism='.$org);
  $application->menu->add_entry('&raquo;Organism', 'Compare Metabolic Reconstruction', '?page=CompareMetabolicReconstruction&organism='.$org);
  $application->menu->add_entry('&raquo;Organism', 'Kegg', '?page=Kegg&organism='.$org);
  $application->menu->add_entry('&raquo;Organism', 'Export', '?page=Export&organism='.$org);
  $application->menu->add_entry('&raquo;Organism', 'Other Organisms', '?page=OrganismSelect');
  $application->menu->add_category('&raquo;Feature');
  $application->menu->add_entry('&raquo;Feature', 'Feature Overview', "?page=Annotation&feature=$id");
  $application->menu->add_entry('&raquo;Feature', 'DNA Sequence', "?page=Sequence&feature=$id&type=dna");
  $application->menu->add_entry('&raquo;Feature', 'DNA Sequence w/ flanking', "?page=Sequence&feature=$id&type=dna_flanking");
  $application->menu->add_entry('&raquo;Feature', 'Protein Sequence', "?page=Sequence&feature=$id&type=protein");
#  $application->menu->add_entry('&raquo;Feature', 'Feature Evidence', '?page=Evidence&feature='.$id);
  $application->menu->add_entry('&raquo;Feature', 'Feature Evidence vs. FIG', '?page=Evidence&feature='.$id);
  $application->menu->add_entry('&raquo;Feature', 'Feature Evidence vs. all DB', '?page=Evidence&sims_db=all&feature='.$id);
  $application->menu->add_category('&raquo;Feature Tools');

  # get the list of tools to add them to the menu
  if (open(TMP,"<$FIG_Config::global/LinksToTools")) {

    $/ = "\n//\n";
    while (defined($_ = <TMP>)) {
      # allow comment lines in the file
      next if (/^#/);
      my($tool,$desc, undef, $internal_or_not) = split(/\n/,$_);
      unless (defined($internal_or_not)) {
	$internal_or_not = "";
      }
      next if ($tool eq 'General Tools');
      next if ($tool eq 'For Specific Organisms');
      next if ($tool eq 'Other useful tools');
      next if ($tool =~ /^Protein Signals/);
      next if (($tool ne 'ProDom') && ($internal_or_not eq "INTERNAL"));
      $application->menu->add_entry('&raquo;Feature Tools', $tool, "?page=RunTool&tool=$tool&feature=$id", "_blank");
    }
    close(TMP);
    $/ = "\n";

  } else {
    $application->add_message('warning', 'No tools found');
  }

  # check if this is an existing feature
  unless ($fig->is_real_feature($id)) {
    return "<div><h2>Feature Overview</h2><p><strong>You have used an invalid identifier to link to the SEED Viewer</strong>.<br>ID: $id</p><p>Valid IDs are of the form:<br/>fig|&lt;taxonomy_id&gt;.&lt;seed_version_number&gt;.peg.&lt;peg_number&gt;<br/><em>Example: fig|83333.1.peg.4</em></p><p>To search the SEED Viewer please use the <a href='?page='>start page</a>.</p>";
  }

  my $html = "<h2>Annotation History for $id and similar features</h2>";

  my $table = $application->component('HistoryTable');
  $table->items_per_page(25);
  $table->show_select_items_per_page(1);
  $table->show_top_browse(1);
  $table->show_bottom_browse(1);
  $table->columns( [ { name => 'Organism', filter => 1, sortable => 1 }, { name => 'Feature', filter => 1, sortable => 1 }, { name => 'Date', sortable => 1 }, { name => 'Annotator', filter => 1, sortable => 1, operator => 'combobox' }, { name => 'Annotation', filter => 1, sortable => 1 }]);

  my $data = [];
  my @features = ($id, $fig->related_by_func_sim($id));
  my @history = ();
  foreach my $feature (@features) {
    push(@history, $fig->feature_annotations($feature, 1));
  }
  @history = sort { $a->[1] <=> $b->[1] } @history;
  my $organism = '';
  my $feature = '';
  foreach my $history_entry (@history) {
    if ($feature ne $history_entry->[0]) {
      $feature = $history_entry->[0];
      $organism = $fig->genus_species($fig->genome_of($feature));
    }
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($history_entry->[1]);
    $year += 1900;
    $mon++;
    push(@$data, [$organism, "<a href='?page=Annotation&feature=$feature'>$feature</a>", "$year/$mon/$mday", $history_entry->[2], $history_entry->[3]]);
  }
  $table->data($data);
  $html .= $table->output();

  return $html;

}

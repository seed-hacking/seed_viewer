package SeedViewer::WebPage::ClosestNeighbors;

use base qw( WebPage );

use FIG_Config;

use URI::Escape;

use strict;
use warnings;

use Tracer;
use HTML;
use FFs;
use FIGRules;
use SeedViewer::SeedViewer;

use Data::Dumper;
use FreezeThaw qw( freeze thaw );

1;

=pod

=head1 NAME

ClosestNeighbors - show the list of neighbors from the genome directory.

=head1 DESCRIPTION

Show the list of neighbors from the genome directory.
    
=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;
  
  $self->title('Closest Neighbors');
  $self->application->register_component('Table', 'CompTable');

  return 1;
}

=item * B<output> ()

Returns the html output of the Annotation page.

=cut

sub output {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;

  my $html = '';
  my $fig = $application->data_handle('FIG');

  # check if we have a valid fig
  unless ($fig) {
    $application->add_message('warning', 'Invalid organism id');
    return "";
  }

  my $org = $cgi->param('organism');

  if ($org =~ /\d+\.\d+/)
  {
      $application->menu->add_category('&raquo;Organism');
      $application->menu->add_entry('&raquo;Organism', 'General Information', '?page=Organism&organism='.$org);
      $application->menu->add_entry('&raquo;Organism', 'Feature Table', '?page=BrowseGenome&tabular=1&organism='.$org);
      $application->menu->add_entry('&raquo;Organism', 'Genome Browser', '?page=BrowseGenome&organism='.$org);
      $application->menu->add_entry('&raquo;Organism', 'Scenarios', '?page=Scenarios&organism='.$org);
      $application->menu->add_entry('&raquo;Organism', 'Subsystems', '?page=SubsystemSelect&organism='.$org);
      $application->menu->add_entry('&raquo;Organism', 'Atomic Regulons', '?page=AtomicRegulon&regulon=all&genome='.$org);
      $application->menu->add_entry('&raquo;Organism', 'Export', '?page=Export&organism='.$org);
      $application->menu->add_category('&raquo;Comparative Tools');
      $application->menu->add_entry('&raquo;Comparative Tools', 'Function based Comparison', '?page=CompareMetabolicReconstruction&organism='.$org);
      $application->menu->add_entry('&raquo;Comparative Tools', 'Sequence based Comparison', '?page=MultiGenomeCompare&organism='.$org);
      $application->menu->add_entry('&raquo;Comparative Tools', 'Kegg Metabolic Analysis', '?page=Kegg&organism='.$org);
      $application->menu->add_entry('&raquo;Comparative Tools', 'BLAST search', '?page=BlastRun&organism='.$org);
  }


  my $table = $application->component("CompTable");

  my $dir = $fig->organism_directory($org);
  my $fh;

  my $gs = $fig->genus_species($org);

  if (!open($fh, "<", "$dir/closest.genomes"))
  {
      $html .= "No closest genomes data found for $gs ($org)";
      return $html;
  }

  my $have_scores;
  my @data;
  while (<$fh>)
  {
      if (/^(\d+\.\d+)\t(\d+)\t([^\t]*)$/)
      {
	  push(@data, [genome_link($application, $1), $2, $3]);
	  $have_scores = 1;
      }
      elsif (/^(\d+\.\d+)\t([^\t]*)$/)
      {
	  push(@data, [genome_link($application, $1), $2]);
      }
  }

  $html .= "<h2>Closest neighbors of $gs ($org)</h2>\n";
  
  $table->columns([
	       { name => "Genome ID", filter => 1, sortable => 1 },
		   ( $have_scores ? { name => "Score", filter => 1, sortable => 1 } : ()),
	       { name => "Genome Name", filter => 1, sortable => 1},
		   ]);
  
  $table->show_top_browse(1);
  $table->show_bottom_browse(1);
  $table->items_per_page(30);
  $table->show_select_items_per_page(1);
  $table->show_export_button({ title => 'export to file', strip_html => 1 });
  $table->show_clear_filter_button(1);
  $table->data(\@data);

  $html .= $table->output();

  return $html;
  
}

sub genome_link
{
    my($app, $id) = @_;
    my $url = $app->url . "?page=Organism&organism=$id";
    return "<a href='$url'>$id</a>";
}
		

1;

package SeedViewer::WebPage::CoregulatedFeatures;

use base qw( WebPage );

use FIG_Config;

use URI::Escape;

use strict;
use warnings;

use ANNOserver;
use Tracer;
use HTML;
use FFs;
use FIGRules;
use SeedViewer::SeedViewer;
use SAPserver;

use Data::Dumper;
use FreezeThaw qw( freeze thaw );

1;

=pod

=head1 NAME

CoregulatedFeatures - an instance of WebPage which displays information about the
features that appear to be coregulated with a target feature.

=head1 DESCRIPTION

Display information about the coregulated features.

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;
  
  $self->title('Coregulated Features');
  $self->application->register_component('Table', 'CoregTable');

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

  my $id = $cgi->param('feature');
  my $cutoff = $cgi->param('cutoff') || 0;
  my $org = &FIG::genome_of($id);

  # create menu

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
      $application->menu->add_entry('&raquo;Comparative Tools', 'Find this gene in an organism', '?page=SearchGeneByFeature&feature='.$id, '_blank');
      $application->menu->add_category('&raquo;Feature');
      $application->menu->add_entry('&raquo;Feature', 'Feature Overview', "?page=Annotation&feature=$id");
      $application->menu->add_entry('&raquo;Feature', 'DNA Sequence', "?page=ShowSeqs&feature=$id&Sequence=DNA Sequence", "_blank");
      $application->menu->add_entry('&raquo;Feature', 'DNA Sequence w/ flanking', "?page=ShowSeqs&feature=$id&Sequence=DNA Sequence with flanking", "_blank");
      if ($id =~ /\.peg\./) {
	  $application->menu->add_entry('&raquo;Feature', 'Protein Sequence', "?page=ShowSeqs&feature=$id&Sequence=Protein Sequence", "_blank");
      }
      $application->menu->add_entry('&raquo;Feature', 'Feature Evidence vs. FIG', '?page=Evidence&feature='. $cgi->param('feature'));
      $application->menu->add_entry('&raquo;Feature', 'Feature Evidence vs. all DB', '?page=Evidence&sims_db=all&feature='.$cgi->param('feature'));
      $application->menu->add_category('&raquo;Feature Tools');

  }

  return $self->show_coregulated($fig, $id, $cutoff);
}

sub show_coregulated
{
    my($self, $fig, $id, $cutoff) = @_;

    my $application = $self->application;

    my $sap = SAPserver->new();
    my $rel = $sap->coregulated_fids(-ids => [$id]);
    my $relH = $rel->{$id};
    my @rel = grep { $relH->{$_} > $cutoff } keys %$relH;
    @rel = sort { $relH->{$b} <=> $relH->{$a} } @rel;
    my $funcs = $fig->function_of_bulk(\@rel);

    my $regs = $fig->features_in_atomic_regulon([@rel, $id]);

    my $fn = $fig->function_of($id);
    my $furl = $application->url."?page=Annotation&feature=$id";
    my $output = "<h2>Features coregulated with <a href='$furl'>$id</a> $fn</h2>\n";
    if (defined(my $arH = $regs->{$id}))
    {
	my $ar = $arH->{regulon};
	my $u = $application->url . "?page=AtomicRegulon&feature=$id&regulon=$ar&genome=$arH->{genome}";
	$output .= "<p>This feature is in atomic regulon <a href='$u'>$ar</a>.</p>\n";
    }

    my $table_data = [ map { my $url = $application->url."?page=Annotation&feature=$_";
			     my $reg_link;
			     if (defined(my $arH = $regs->{$_}))
			     {
				 my $ar = $arH->{regulon};
				 my $g = $arH->{genome};
				 my $u = $application->url . "?page=AtomicRegulon&feature=$_&regulon=$ar&genome=$g";
				 $reg_link = "<a href='$u'>$ar</a>";
			     }
			     ["<a href='$url'>$_</a>",
			      sprintf("%.3f", $relH->{$_}),
			      $reg_link,
			      $funcs->{$_} ] } @rel ];

    my $table = $application->component('CoregTable');

    $table->columns([{name => "Feature ID", filter => 1, sortable => 1 },
		 { name => "Pearson Coefficient", filter => 1, 'operators' => [ 'less', 'more' ], sortable => 1},
		 { name => "Atomic Regulon", filter => 1, sortable => 1 },
		 { name => "Function", filter => 1, sortable => 1 } ]);
    $table->data($table_data);
    $table->show_top_browse(1);
    $table->show_bottom_browse(1);
    $table->items_per_page(25);
    $table->show_select_items_per_page(1);
    $table->show_export_button({ title => 'export to file', strip_html => 1 });
    $table->show_clear_filter_button(1);

    $output .= $table->output();
    return $output;
}

1;

package SeedViewer::WebPage::Home;

# Home - start page of the SeedViewer

# $Id: Home.pm,v 1.23 2011-06-30 19:54:31 parrello Exp $

use strict;
use warnings;

use base qw( WebPage );

use FIG_Config;
use SeedViewer::SeedViewer;
use Tracer;

1;

=pod

=head1 NAME

Home - start page of the SeedViewer

=head1 DESCRIPTION

Displays an introduction to the SEED Viewer and various search tabs

=head1 METHODS

=over 4

=item * B<init> ()

Initialise the page

=cut

sub init {
  my $self = shift;

  # set title
  $self->title('Home');

  # register components
  $self->application->register_component('OrganismSelect', 'OrganismSelect');
  $self->application->register_component('FilterSelect', 'SubsystemSelect');
  $self->application->register_component('BlastForm', 'BlastForm');
  $self->application->register_component('TabView', 'tabview');
  
}

=pod

=item * B<output> ()

Returns the html output of the Login page.

=cut

sub output {
  my ($self) = @_;

  my $application = $self->application;
  my $user = $application->session->user;
  my $cgi = $application->cgi;
  my $is_annotator = 0;
  if (user_can_annotate_genome($self->application, '*')) {
    $is_annotator = 1;
  }

  # check for private organisms
  if ($user) {
    if ($FIG_Config::rast_jobs) {
       my $rast = $application->data_handle('RAST');
       if (ref($rast)) {
 	my $jobs = $rast->Job->get_jobs_for_user($user, 'view', 1);
	unless (scalar(@$jobs) > 50) {
	  $cgi->param('organism', map { $_->genome_id } @$jobs);
	}
      }
    }
  }

  my $fig = $application->data_handle('FIG');
  Trace("FIG object of type " . ref($fig) . " acquired.") if T(3);
  my $organism_select_component = $application->component('OrganismSelect');
  $organism_select_component->width(450);  
  my $org_select_tab = "<div style='padding-left:10px;'>".$self->start_form('org_form', { 'page' => 'Organism'}) . $organism_select_component->output;
  $org_select_tab .= "<br>" . $self->button('select') . "<br>" . $self->end_form()."</div>";
  Trace("Computing statistics.") if T(3);
  my $statistics = $organism_select_component->statistics;
  Trace("Setting up subsystem search.") if T(3);
  my $subsystem_select_component = $application->component('SubsystemSelect');
  my @subsystem_names = sort($fig->all_usable_subsystems());
  @subsystem_names = grep { $fig->is_exchangable_subsystem($_) || $is_annotator } @subsystem_names;
  my @subsystem_labels = @subsystem_names;
  map { $_ =~ s/'/\&\#39\;/g } @subsystem_names;
  map { $_ =~ s/_/ /g } @subsystem_labels;
  $subsystem_select_component->values( \@subsystem_names );
  $subsystem_select_component->labels( \@subsystem_labels );
  $subsystem_select_component->name('subsystem');
  $subsystem_select_component->width(500);
  my $subsys_select_tab = "<div style='padding-left:10px;'>".$self->start_form('ss_form', { 'page' => 'Subsystems'}) . $subsystem_select_component->output;
  $subsys_select_tab .= "<br>" . $self->button('select') . "<br>" . $self->end_form()."</div>";
  Trace("Setting up ID search.") if T(3);
  my $id_search_form = "<div style='padding-left:10px;'>".$self->start_form('search_form', { 'page' => 'SearchResult', action => 'check_search' }) . qq~<input type="text" name="pattern" value="Enter ID" style="width: 440px;" onfocus="if (document.getElementById('pattern1').value=='Enter ID') { document.getElementById('pattern1').value=''; }" id="pattern1">~ . $self->button("ID Search") . qq~<br><i>(Example search: 'fig|83333.1.peg.4', 'tr|Q3K0I5', 'gi|66047296' or 'kegg|psp:PSPPH_4601')</i>~ . $self->end_form()."</div>";

  my $text_search_form = "<div style='padding-left:10px;'>".$self->start_form('search_form', { 'page' => 'SearchResult' }) . qq~<input type="text" name="pattern" value="Enter search term" style="width: 440px;" onfocus="if (document.getElementById('pattern2').value=='Enter search term') { document.getElementById('pattern2').value=''; }" id="pattern2">~ . $self->button("Text Search") . qq~<br><i>(Example search: 'EC 2.7.3.-' or 'Pantothenate kinase')</i>~ . $self->end_form()."</div>";
  Trace("Setting up BLAST search.") if T(3);
  my $blast_form = $application->component('BlastForm')->output();
  Trace("Assembling tabs.") if T(3);
  my $tab_view_component = $application->component('tabview');
  $tab_view_component->width(500);
  $tab_view_component->height(210);
  $tab_view_component->add_tab('Organisms', $org_select_tab);
  $tab_view_component->add_tab('Subsystems', $subsys_select_tab);
  $tab_view_component->add_tab('ID Search', $id_search_form);
  $tab_view_component->add_tab('Text Search', $text_search_form);
  $tab_view_component->add_tab('BLAST', $blast_form);
  Trace("Generating help content.") if T(3);

  my $content = "";
  $content .= '<div style="font-size: 13px; text-align: justify; margin: 20px; width: 70%;">
<p>The SEED is a framework to support comparative analysis and annotation of genomes. The SEED Viewer allows you to explore the curated genomes that have been produced by a cooperative effort that includes Fellowship for Interpretation of Genomes (FIG), Argonne National Laboratory, the University of Chicago and teams from a number of other institutions.</p>
<p>We currently have '.$statistics->{Archaea}.' Archaea, '.$statistics->{Bacteria}.' Bacteria, '.$statistics->{Eukaryota}.' Eukaryota, '.$statistics->{Plasmid}.' Plasmids and '.$statistics->{Virus}.' Viruses in our database.</p>
<p>To get started, either select an <em>Organism</em>, a subsystem from the <em>Subsystem</em> tab, enter an id in the <em>ID Search</em> tab, or type a search word into the <em>Text Search</em> tab.</p>
</div>';
  
  $content .= '<div style="margin: 20px;">' . $tab_view_component->output . '</div>';
  Trace("Robot check.") if T(3);
  if ($application->bot()) {
    
    $content .= "You will find the list of available organisms on the <a href='".$application->url."?page=OrganismSelect'>Organism Select</a> page.<br>";
    $content .= "You will find the list of curated subsystems on the <a href='".$application->url."?page=SubsystemSelect'>Subsystem Select</a> page.<br>";
    
  }
  Trace("Returning content.") if T(3);
  return $content;
}

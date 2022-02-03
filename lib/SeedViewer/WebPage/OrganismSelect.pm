package SeedViewer::WebPage::OrganismSelect;

use base qw( WebPage );

1;

use strict;
use warnings;

use FIG;
use FIGV;

=pod

#TITLE OrganismSelectPagePm

=head1 NAME

OrganismSelect - an instance of WebPage which lets the user select an organism

=head1 DESCRIPTION

Display an organism select box

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('Organism Selection');
  $self->application->register_component('OrganismSelect', 'OrganismSelect');

  return 1;
}

=item * B<output> ()

Returns the html output of the OrganismSelect page.

=cut

sub output {
  my ($self) = @_;

  # fetch application, cgi and fig
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $user = $application->session->user;

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

  # create the select organism component
  my $organism_select_component = $application->component('OrganismSelect');
  $organism_select_component->width(500);

  # contruct introductory text
  my $html = "<h2>Select Organism</h2>";
  $html .= "<div style='text-align: justify; width: 800px;'>The SEED provides access to a large number public organisms. For each of these organisms, we provide a number of services:<ul style='list-style-type: disc;'><li>The first page you will see is the <b>General Information</b> page, where you will find some statistical information about the organism. Notice that from the menu <i>'Organism'</i> you will have access to multiple functions.</li><li>The <b>Genome Browser</b> will allow both tabular and graphical browsing of the genome.</li><li>You can access the <b>Scenarios</b>, which provide insight about the presence or absence of metabolic pathways.</li><li>You can <b>Compare Metabolic Reconstruction</b> of the chosen organism to another, e.g. to examine the differences in metabolism to a close relative.</li><li>Finally, you can <b>Export</b> our annotations in a format of your choice.</li></ul>Select from the list below to display the according organism page.</div>";

  if ($application->bot()) {
    
    my $genome_info = $fig->genome_info();
    foreach my $genome (@$genome_info) {
      $html .= "Detailed information about the $genome->[3] $genome->[1] ($genome->[0]) can be found on its organism overview page: <a href='".$application->url()."?page=Organism&organism=$genome->[0]'>$genome->[1]</a>. It has $genome->[2] basepairs, $genome->[4] protein encoding genes and belongs to the taxonomy line $genome->[7].<br>";
    }
  } else {

    # create select organism form
    $html .= $self->start_form( 'organism_select_form', { 'page' => 'Organism' } );
    $html .= $organism_select_component->output();
    $html .= "<br>" . $self->button('display') . "<br><br>";
    $html .= $self->end_form();
  }
  
  return $html;
}

sub supported_rights {
  return [ [ 'view', 'genome', '*' ] ];
}

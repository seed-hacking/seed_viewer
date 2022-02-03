package SeedViewer::WebPage::SubsystemSelect;

use strict;
use base qw( WebPage );

1;

use FIG;
use SeedViewer::SeedViewer;

=pod

=head2 NAME

SubsystemSelect - an instance of WebPage which displays Subsystems to select

=head2 DESCRIPTION

Display a Subsystem selection

=head2 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('Subsystem Selection');
  $self->application->register_component('FilterSelect', 'SubsystemSelect');

  return 1;
}

=item * B<output> ()

Returns the html output of the Subsystem page.

=cut

sub output {
  my ($self) = @_;

  my $application = $self->application();

  my $cgi = $application->cgi();
  my $fig = $application->data_handle('FIG');
  my $user = $application->session->user;

  $application->menu->add_category('&raquo;Subsystem');
  
  # check if there is an organism parameter
  my $org = "";
  if ($cgi->param('organism')) {
    $org = "<input type='hidden' name='organism' value='".$cgi->param('organism')."'>";
  }

  my $is_annotator = 0;
  if (user_can_annotate_genome($self->application, "*")) {
    $is_annotator = 1;
  }

  my $html = "<h2>Subsystem Overview</h2>";

  my $subsystem_select_component = $application->component('SubsystemSelect');
  my @subsystem_names = sort($fig->all_usable_subsystems());
  @subsystem_names = grep { $fig->is_exchangable_subsystem($_) || $is_annotator } @subsystem_names;
  my @subsystem_labels = @subsystem_names;
  map { $_ =~ s/_/ /g } @subsystem_labels;
  $subsystem_select_component->values( \@subsystem_names );
  $subsystem_select_component->labels( \@subsystem_labels );
  $subsystem_select_component->name('subsystem');
  $subsystem_select_component->width(600);

  my $number_of_subsystems = scalar(@subsystem_names);

  $html .= "<div style='width: 800px; text-align: justify;'><p>A subsystem is a set of functional roles that together implement a specific biological process or structural complex. Frequently, subsystems represent the collection of functional roles that make up a metabolic pathway, a complex (e.g., the ribosome), or a class of proteins (e.g., two-component signal-transduction proteins within Staphylococcus aureus).</p><p>The SEED currently curates <b>$number_of_subsystems</b> completed subsystems. Select from the list below to display the according subsystem page.</p></div>";

  $html .= $self->start_form('ssselect_form', { page => 'Subsystems' });
  $html .= $subsystem_select_component->output();
  $html .= "<br>" . $self->button('display') . "<br><br>";
  $html .= $org.$self->end_form();

  if ($application->bot()) {
    foreach my $ss (@subsystem_names) {
      my $ssl = $ss;
      $ssl =~ s/_/ /g;
      $html .= "To get specific information about $ssl please go to its subsystem page by following this link: <a href='".$application->url."?page=Subsystems&subsystem=$ss'>$ssl</a><br>";
    }
  }

  return $html;
}

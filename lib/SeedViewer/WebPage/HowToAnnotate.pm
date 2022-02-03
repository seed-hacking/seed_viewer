package SeedViewer::WebPage::HowToAnnotate;

use base qw( WebPage );

1;

use strict;
use warnings;

use Data::Dumper;

=pod

=head1 NAME

HowToAnnotate - an instance of WebPage which displays a tutorial on how to annotate

=head1 DESCRIPTION

Display a tutorial on how to annotate and give the possibility to activate annotation
capabilities for the organisms the current user owns.

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('how to annotate');

  $self->application->register_action($self, 'enable_annotation', 'enable_annotation');

  return 1;
}

=item * B<output> ()

Returns the html output of the Organism page.

=cut

sub output {
  my ($self) = @_;

  # fetch application, cgi and fig
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $user = $application->session->user;
  my $master = $application->dbmaster;
  my $rast = $application->data_handle('RAST');
  my $fig;

  # check if the user has annotation capabilities turned on for their genomes
  my $edit_rights = $user->has_right_to(undef, 'edit', 'genome');
  my $annotation_rights = $user->has_right_to(undef, 'annotate', 'genome');
  my $annotation_rights_hash = {};
  foreach my $id (@$annotation_rights) {
    $annotation_rights_hash->{$id} = 1;
  }
  my $no_rights_for = [];
  foreach my $id (@$edit_rights) {

    # check if the job is available here
    my $job = $rast->Job->get_objects( { genome_id => $id } );
    next unless scalar(@$job);
    next unless $rast->Job->init( { id => $job->[0]->id } );
    next unless $job->[0]->ready_for_browsing;
    unless (exists($annotation_rights_hash->{$id})) {
      push(@$no_rights_for, $id);
    }
  }
  my $enable_annotation = "";
  if (scalar(@$no_rights_for)) {
    $cgi->param('organism', @$no_rights_for);
    $fig = $application->data_handle('FIG');
  
    $enable_annotation = "<div style='width: 800px;'>You have access to the following genomes for which annotation has not yet been enabled. Check the genomes for which you would like to enable annotation and click 'enable' to activate the annotation capabilities.</div><br><br>".$self->start_form('activate_annotation_form', { action => 'enable_annotation' })."<table><tr><th>activate</th><th>ID</th><th>genome</th></tr>";
    foreach my $id (@$no_rights_for) {
      my $gname = $fig->genus_species($id);
      $enable_annotation .= "<tr><td align=center><input type='checkbox' name='genomes_to_enable' value='$id'></td><td>$id</td><td>$gname</td></tr>";
    }
    $enable_annotation .= "</table><input type='submit' value='enable'>".$self->end_form;
  }

  my $content = "<h2>Annotation Capabilities in the SeedViewer</h2>";

  $content .= "<p style='width: 800px;'>The annotations in the SEED are based on the manual curation effort of a group of expert biologists. They create <a href='http://www.nmpdr.org/FIG/wiki/view.cgi/FIG/Subsystem' target=_blank>subsystems</a>, a set of proteins that perform a certain function within a genome. Each individual subsystems is then examined for a functional variant in all available genomes in the SEED. Since the biologists are experts in the fields their respective subsystems cover, we consider the functional assignments they make to be highly reliable.</p><p style='width: 800px;'>The RAST server uses this data for projection onto the uploaded genomes. Assessments made based on subsystems are considered very high quality and can still be made very quickly. All remaining features are then identified by standard methods and still offer high quality automated assignments.</p><p style='width: 800px;'>The SeedViewer allows you to make two different kinds of annotations. You can manually change annotations by typing them in, based on your own assessment of relevant biological information provided by our tools or other sources. We also provide the possibility to use projection techniques to assign functions to features in your genome. If you want to take full advantage of our subsystem based approach, we highly recommend to use the provided tools for annotation projection. Only annotations that exactly match a <a href='http://www.nmpdr.org/FIG/wiki/view.cgi/FIG/FunctionalRole' target=_blank>functional role</a> of a subsystem can be used by our system to complete a subsystem. This will provide valuable information about the metabolic functions of your genome.</p><p style='width: 800px;'>Once you have enabled annotation capabilities for a genome, you will have access to annotation functions on the annotation details page of each feature, on the feature evidence page and on the subsystem pages. If you have uploaded several genomes to the RAST server, we also offer capabilities for consistent annotation across your entire set. The chromosomal clusters page is available for such projects and can be accessed from the compared regions graphic on the bottom of each annotation details page via the button 'annotate clusters'.</p><p style='width: 800px;'>When your genome is uploaded to the RAST server, we automatically compute the <a href='http://www.nmpdr.org/FIG/wiki/view.cgi/FIG/Similarity' target=_blank>similarities</a> to all public genomes in the SEED database. These computations are neccessary to display the compared regions for your private genome. If you have several private genomes, these computations have to be executed for the organisms of your choice. You can access your current list of peers on the <a href='?page=PrivateOrganismPreferences' target=_blank>private organism peers</a> page.</p>";

  $content .= $enable_annotation;

  return $content;
}

sub enable_annotation {
  my ($self) = @_;

  # get some objects
  my $application = $self->application;
  my $cgi = $application->cgi;
  my $master = $application->dbmaster;

  # get the ids to enable
  my @ids = $cgi->param('genomes_to_enable');

  # get the current user
  my $user = $application->session->user;
  
  # iterate through the ids and check whether they should be enabled
  foreach  my $id (@ids) {
    if ($user && $user->has_right(undef, 'edit', 'genome', $id)) {

      # the user has the edit right, make sure he does not yet have the annotate right
      if ($user->has_right(undef, 'annotate', 'genome', $id)) {
	$application->add_message('warning', "The annotation capabilities for $id were already enabled for you.");
      } else {
	$master->Rights->create( { granted => 1,
				   delegated => 0,
				   data_type => 'genome',
				   name => 'annotate',
				   data_id => $id,
				   scope => $user->get_user_scope } );
	$application->add_message('info', "The annotation capabilities for $id have been enabled for you.");
      }
    }
  }

  return;
}

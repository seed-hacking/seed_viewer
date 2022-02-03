package SeedViewer::WebPage::ModelViewer;

use base qw( WebPage );

1;

use strict;
use warnings;

use FIGMODEL;
use FIGV;
use UnvSubsys;

=pod

=head1 NAME

ModelViewer

=head1 DESCRIPTION

An instance of a WebPage in the SEEDViewer which displays information about the genome-scale models in the SEED database.

=head1 METHODS

=over 4

=item * B<init> ()

Initialise the page

=cut

sub init {
  my $self = shift;

  $self->title('Model Viewer');

  # register components
  $self->application->register_component('ModelSelectTable', 'ModelSelect');
}

=item * B<output> ()

Returns the html output of the Reaction Viewer page.

=cut

sub output {
	my ($self) = @_;

	my $application = $self->application();
	my $user = $application->session->user();
	my $cgi = $application->cgi();
	my $fig = $application->data_handle('FIG');

	my $SelectedModel = $cgi->param('model');
	if (!defined($SelectedModel) || length($SelectedModel) == 0) {
		$SelectedModel = "NONE";
	}
	my $CompareModels = $cgi->param('compare');
	if (!defined($CompareModels) || length($CompareModels) == 0) {
		$CompareModels = "NONE";
	}
	my $CheckedModels;
	if ($CompareModels ne "NONE") {
		push(@{$CheckedModels},split(/,/,$CompareModels));
	} else {
		$CheckedModels = "NONE";
	}

	my $ModelSelect = $application->component('ModelSelect');
	my $html = $ModelSelect->output($SelectedModel,$CheckedModels);
	return $html;
}
package SeedViewer::WebPage::GeneViewer;

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

  $self->title('Gene Viewer');

  # register components
  $self->application->register_component('GeneTable', 'GeneListTable');
}

=item * B<output> ()

Returns the html output of the Reaction Viewer page.

=cut

sub output {
	my ($self) = @_;

	my $application = $self->application();
	my $user = $application->session->user();
	my $cgi = $application->cgi();

	my $IDList = $cgi->param('id');

	my $GeneTable = $application->component('GeneListTable');
	my $html = $GeneTable->output(1200,$IDList);
	return $html;
}

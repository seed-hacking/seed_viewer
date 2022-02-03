package SeedViewer::WebPage::IntervalViewer;

use base qw( WebPage );

1;

use strict;
use warnings;
use FIGMODEL; # Fig subset of FigModel
use UnvSubsys;

=pod

=head1 NAME

IntervalViewer

=head1 DESCRIPTION

View or create interval knockouts for an organism.

=head1 METHODS

=over 4

=item * B<init> ()

Initialise the page

=cut

sub init {
	my $self = shift;

	$self->title('Interval Viewer');
	$self->application->register_component('IntervalView', 'interval_view');
	$self->application->register_component('IntervalTable', 'interval_table');
}


=item * B<output> ()

Returns the html output of the ReAction Viewer page.

=cut
sub output {
  my ($self) = @_;
  
	my $app = $self->application();
	my $model = $app->data_handle('FIGMODEL');
	my $cgi = $app->cgi();
	my $interval_view = $app->component('interval_view');
  
	my $html;
	my $Action = $cgi->param( 'act' );
	my $interval = $cgi->param( 'id' ) || undef;
    my $intervalModel = $model->database()->GetDBTable("INTERVAL TABLE");
    my $realInterval = $intervalModel->get_row_by_key($interval, "ID");
    
	if (defined($Action) && $Action eq 'NEW') { # create new interval
	} elsif (defined($Action) && $Action eq 'SUBMIT') { # save form-passed interval
	} elsif (defined($interval) && defined($realInterval)) {
  		$html .= $interval_view->output();
	} else {
        my $interval_table = $app->component('interval_table');
        $html .= $interval_table->output(1200, 0);
    }
	return $html;
}


package SeedViewer::WebPage::Regions;

use base qw( WebPage );

use FIG_Config;

use URI::Escape;

use strict;
use warnings;
use Tracer;
use HTML;

use Data::Dumper;

1;

=pod

=head1 NAME

Regions - an instance of WebPage which displays the graphical compared regions

=head1 DESCRIPTION

Displays regions graphically

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('Regions');
  $self->application->register_component('RegionDisplay','ComparedRegions');
  $self->application->register_component('Ajax', 'ComparedRegionsAjax');
  $self->application->register_component('ToggleButton', 'toggle1');

  return 1;
}

=item * B<output> ()

Returns the html output of the Regions page.

=cut

sub output {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;

  unless (defined($cgi->param('feature'))) {
    $application->add_message('warning', 'Regions page called without a feature identifier');
    return "";
  }

  my $fig = $application->data_handle('FIG');

  # check if we have a valid fig
  unless ($fig) {
    $application->add_message('warning', 'Invalid organism id');
    return "";
  }

  my @features = $cgi->param('feature');

  my $html = '';
  $html .= "<div><h2>Feature Chromosomal Regions</h2>";

  $html .= $application->component('ComparedRegionsAjax')->output();
  
  $html .= qq~<script> function toggle (index, id, value, action) {

  // get the objects
  var toggle_hidden = document.getElementById('togglevalue_'+id);
  var all_buttons = document.getElementsByName('toggle_'+id);
  var selected_button = document.getElementById('toggle_'+index+'_'+id);
  
  // unselect all buttons
  for (i=0;i<all_buttons.length;i++) {
    all_buttons[i].className = 'toggle_unselected';
  }

  // select selected button
  selected_button.className = 'toggle_selected';

  if (action==undefined) {
    // set the hidden value
    toggle_hidden.value = value;
  } else {
    // if this is an action, execute it
    action(value);
  }

  return;
}
</script>
~;

  my $args = join("&", map{"feature=$_"} @features);

  my $txt = join(' ', 'The regions are centered on the input features which are always displayed pointing right, even if located on the minus strand.',
		      'Sets of genes with similar sequence are grouped with the same number and color.',
		      'Genes whose relative position is conserved in at least four other species are functionally coupled and have gray background boxes.', 
		      'The size of the region and coloring cutoff score may be reset.',
		 'Click on any arrow in the display to view specific information about that feature.');

  $html .= "<div style='width: 800px; text-align: justify;'>$txt</div>\n";
  unless ($application->bot()) {
    $html .= "<br /><div id='cr'><img src=\"$FIG_Config::cgi_url/Html/clear.gif\" onload='execute_ajax(\"compared_region\", \"cr\", \"$args\");'></div><br>";
  }

  $html .= "<br><br><br><br>";

  return $html;
}

sub compared_region {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;
  Trace("Processing compared region.") if T(3);

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

  my $cr = $self->application->component('ComparedRegions');
  $cr->fig($fig);

  return $cr->output();
}

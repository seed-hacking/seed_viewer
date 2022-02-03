package SeedViewer::WebPage::LinkError;

use base qw( WebPage );

1;

use strict;
use warnings;
use URI::Escape;
use FIGRules;

=pod

=head1 NAME

LinkError - an instance of WebPage which displays what went wrong with linking into the SeedViewer

=head1 DESCRIPTION

Display information errors while linking into the SeedViewer

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->application->no_bot(1);

  return 1;
}

=item * B<output> ()

Returns the html output of the LinkError page.

=cut

sub output {
  my ($self) = @_;

  # fetch application, cgi and fig
  my $application = $self->application();
  my $cgi = $application->cgi();

  my @warnings = split /~/, uri_unescape($cgi->param('warnings'));

  $self->title('Link Error');

  my $html = "<div id='content'><h1>Unable to link to the SeedViewer</h1>";
  $html .= "<p>You are using an incorrect url to link to the SeedViewer.</p>";
  $html .= "<p><em>".join('<br/>', @warnings)."</em></p>";
  $html .= "<p>Please read our documentation for more information about ";
  if (FIGRules::nmpdr_mode($cgi)) {
	$html .= "<a href=$FIG_Config::cgi_url/wiki/view.cgi/FIG/LinkingToTheSeedViewer>Linking to the NMPDR</a>";
  } else {
	$html .= "<a href='http://www.theseed.org/www.theseed.org/wiki/index.php/Glossary#Linking_to_the_SEED' ";
	$html .= "target='_blank'>how to link to the Seed Viewer</a>.</p>";
  }
  $html .= "</div>";

  $html .= $self->start_form('id_form', { page => 'SearchResult',
					  action => 'check_search' });
  $html .= "Enter ID <input type='text' name='pattern'>" . $self->button();
  $html .= $self->end_form();

  return $html;
}

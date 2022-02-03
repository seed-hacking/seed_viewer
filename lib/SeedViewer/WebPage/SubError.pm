package SeedViewer::WebPage::SubError;

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

Returns the html output of the SubError page.

=cut

sub output {
  my ($self) = @_;

  # fetch application, cgi and fig
  my $application = $self->application();
  my $cgi = $application->cgi();

  my $fig = $application->data_handle('FIG');
  my $name = $cgi->param('sub');



  $self->title("Can't find subsystem");

  $name =~ s/_/ /g;
  my $html = "<div id='content'><h1>The subsystem $name no longer exists. </h1>"; 
  
   my @subsystem_names = sort($fig->all_usable_subsystems());

  
  my $f = 0;
  foreach my $sub (@subsystem_names) {
	  $sub =~ s/_/ /g;
  	if (&intersection($name, $sub) > 2) {
		  if ($f == 0) {
			  $html .= "<p>However, you may be interested in one of the following subsystems: </p>";
			  $f = 1;
		  }
		$html .= "<a href=\"?page=Subsystems&subsystem=$sub\">$sub</a><br>";
  }
  }
  
  	$html .= "You can look at all our Subsystems <a href=\"?page=SubsystemSelect\">here</a><br>";

  $html .= "<br></div>";


  return $html;
}

sub intersection {
	my ($sub1, $sub2) = @_;

	my @union = my @isect = ();
	my %union = my %isect = ();

	my @a = split /\s+/,$sub1;
	my @b = split /\s+/, $sub2;

	foreach my $e (@a) { $union{$e} = 1}

	foreach my $e (@b) {
	        if ($union{$e}) {$isect{$e} = 1}
		}

	@isect = keys %isect;

	return scalar(@isect);
}

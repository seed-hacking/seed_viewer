package SeedViewer::WebPage::Test;

use strict;
use warnings;

use base qw( WebPage );

use Data::Dumper;

1;

sub init {
    my ($self) = @_;

    $self->title('Test the Toast');

    $self->application->register_component('SearchMetagenome', "s");

}

sub output {	
  my ($self) = @_;

  my $application = $self->application();
  my $cgi = $application->cgi();

  my $s = $application->component('s');

  my $content = "";

  $content .= $s->output();

  return $content;

}

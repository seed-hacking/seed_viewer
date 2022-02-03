package SeedViewer::WebPage::Disambiguation;

use strict;
use warnings;

use base qw( WebPage );

use FIG_Config;

use Data::Dumper;

1;

sub init {
    my ($self) = @_;

    $self->title('Ambiguous linkin');
    $self->application->register_component('Table', 'ResultTable');
}

sub output {	
  my ($self) = @_;
  
  my $application = $self->application();
  my $cgi = $application->cgi;

  my $param_string = $cgi->param('possibles');
  my @entries = split /\|\|/, $param_string;
  my $orig_id = shift @entries;
  my $orig_org = shift @entries;
  my $data = [];
  while (scalar(@entries)) {
    my $id = shift @entries;
    my $org = shift @entries;
    push(@$data, [ $org, "<a href='".$application->url."?page=Annotation&feature=$id'>$id</a>" ]);
  }

  my $t = $application->component('ResultTable');
  $t->columns( [ "Organism", "ID" ] );
  $t->data($data);

  my $content = "<h2>Ambiguous linkin</h2><p style='width: 800px;'>The organism $orig_org of the requested ID $orig_id was not found in our database. However, the following essentially identical genes in other organisms are present. You can click on any of the IDs in the following table to get to its detail page.</p>";

  $content .= $t->output();

  return $content;

}

package SeedViewer::WebPage::ModelKegg;

use base qw( WebPage );

1;

use strict;
use warnings;

use URI::Escape;

use FIG_Config;

use SeedViewer::SeedViewer qw( get_menu_metagenome get_menu_organism get_public_metagenomes );

=pod

=head1 NAME

Kegg - an instance of WebPage which maps organism data onto a KEGG map

=head1 DESCRIPTION

Map organism data onto a KEGG map

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('KEGG map');
  

  return 1;
}

=item * B<output> ()

Returns the html output of the Organism page.

=cut

sub output {
    my ($self) = @_;

   
}



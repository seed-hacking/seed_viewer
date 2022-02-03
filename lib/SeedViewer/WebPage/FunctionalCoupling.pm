package SeedViewer::WebPage::FunctionalCoupling;

use base qw( WebPage );

use strict;
use warnings;

use HTML;

1;

=pod

=head1 NAME

FunctionalCoupling - an instance of WebPage which displays the functionally coupled features for a single feature

=head1 DESCRIPTION

Display information about an functional coupling of a feature

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('Functional Coupling');
  $self->application->register_component( 'Table', 'FunctionalCouplingTable' );

  return 1;
}

=item * B<output> ()

Returns the html output of the Annotation page.

=cut

sub output {
  my ($self) = @_;

  # get some variables
  my $application = $self->application;
  $self->{ 'cgi' } = $application->cgi;
  $self->{ 'fig' } = $application->data_handle('FIG');

  # check if we have a feature parameter
  unless ( defined( $self->{ 'cgi' }->param('feature' ) ) ) {
    $application->add_message('warning', "Functional Coupling page called without an input feature.");
    return "";
  }
  # check if we have a to parameter
  unless ( defined( $self->{ 'cgi' }->param('feature' ) ) ) {
    $application->add_message('warning', "Functional Coupling page called without an input feature.");
    return "";
  }

  $self->{ 'fid' } = $self->{ 'cgi' }->param('feature');

  # check if the feature is valid
  unless ( $self->{ 'fig' }->is_real_feature( $self->{ 'fid' } ) ) {
    $application->add_message('warning', "invalid feature id: $self->{ 'fid' }");
    return "";
  }

  my $content = "<H1>Functional Coupling for ".$self->{ 'fid' }." to ".$self->{ 'cgi' }->param( 'to' )."</H1>";
  my $tab = $self->show_coupling_evidence();
  $content .= $tab;
  return $content;
}


sub show_coupling_evidence {
  my ( $self ) = @_;

  my $html = "";

  my $userObject = $self->application->session->user;
  my $user = (defined $userObject ? $userObject->login : "");
  my $to   = $self->{ 'cgi' }->param( 'to' );
  my @coup = grep { $_->[1] eq $to } $self->{ 'fig' }->coupling_and_evidence( $self->{ 'fid' }, 5000, 1.0e-10, 4, 1 );

  if ( @coup != 1 ) {
    $self->application->add_message( 'warning', "Sorry, no evidence that $self->{ 'fid' } is coupled to $to</h1><BR>");
  }
  else {


  # create table headers
    my $table_columns = [ { name => 'Feature 1', filter => 1, sortable => 1 },
			  { name => 'Function 1', filter => 1, sortable => 1 },
			  { name => 'Feature 2', filter => 1, sortable => 1 },
			  { name => 'Function 2', filter => 1, sortable => 1 },
			  { name => 'Organism', filter => 1, sortable => 1 }
			];
    
    my $tbl_data;

    foreach my $pair (@{$coup[0]->[2]}) {

      my ( $peg1, $peg2 ) = @$pair;
      next if ( $self->{ 'fig' }->is_deleted_fid( $peg1 ) );
      next if ( $self->{ 'fig' }->is_deleted_fid( $peg2 ) );

      my $link1 = "<a href='".$self->application->url."?page=Annotation&feature=$peg1'>$peg1</a>";
      my $link2 = "<a href='".$self->application->url."?page=Annotation&feature=$peg2'>$peg2</a>";
      my $func1 = $self->{ 'fig' }->function_of( $peg1, $user );
      my $func2 = $self->{ 'fig' }->function_of( $peg2, $user );
      my $org1 = $self->{ 'fig' }->org_of( $peg1 );
      push( @$tbl_data, [ $link1,
			  $func1,
			  $link2,
			  $func2,
			  $org1
			]
	  );
    }
    
    my $table = $self->application->component( 'FunctionalCouplingTable' );
    $table->columns( $table_columns );
    $table->data( $tbl_data );
    $table->show_top_browse( 1 );
    $table->show_select_items_per_page( 1 );
    $table->show_export_button( { strip_html => 1,
				  title      => 'Export plain data to Excel' } );

    return $table->output();
  }
}

package SeedViewer::WebPage::NewFeature;

use strict;
use warnings;
use URI::Escape;
use HTML;
use Data::Dumper;

use FIG;

use base qw( WebPage );

1;

##############################################################
# Method for registering components etc. for the application #
##############################################################
sub init {
  my ( $self ) = @_;
  $self->application->register_component( 'Info', 'CommentInfo' );
}

#################################
# File where Javascript resides #
#################################
sub require_javascript {

  return [ './Html/showfunctionalroles.js' ];

}

##############################################
# Website content is returned by this method #
##############################################
sub output {
  my ( $self ) = @_;

  $self->{ 'fig' } = $self->application->data_handle('FIG');
  $self->{ 'cgi' } = $self->application->cgi;

  my ( $error, $comment ) = ( "", "" );

  #########
  # TASKS #
  #########
  my $content = "<H1>Create new feature</H1>";

  if ( $self->{ 'cgi' }->param( 'CREATE' ) ) {
    ( $comment, $error ) = $self->create_feature();
  }
  else {
    ##############################
    # Construct the page content #
    ##############################
    
    $content .= $self->start_form( 'form' );
    $content .= "<TABLE><TR>";
    $content .= "<TD>Genome:</TD><TD><INPUT TYPE=TEXT SIZE=100 NAME='genome'></TD>";
    $content .= "</TR><TR>";
    $content .= "<TD>Type:</TD><TD><INPUT TYPE=TEXT SIZE=100 NAME='type'></TD>";
    $content .= "</TR><TR>";
    $content .= "<TD>Location:</TD><TD><INPUT TYPE=TEXT SIZE=100 NAME='location'></TD>";
    $content .= "</TR><TR>";
    $content .= "<TD>Annotation:</TD><TD><INPUT TYPE=TEXT SIZE=100 NAME='fr'></TD>";
    $content .= "</TR></TABLE>";
    $content .= "<INPUT TYPE=SUBMIT VALUE='CREATE' NAME='CREATE'>";
    $content .= $self->end_form();
  }


  ####################
  # Display comments #
  ####################
  if ( defined( $comment ) && $comment ne '' ) {
    my $info_component = $self->application->component( 'CommentInfo' );
    
    $info_component->content( $comment );
    $info_component->default( 0 );
    $content .= $info_component->output();
  } 
  

  ##################
  # Display errors #
  ##################
  
  if ( defined( $error ) && $error ne '' ) {
    $self->application->add_message( 'warning', $error );
  }

  return $content;
}

sub create_feature {

  my ( $self ) = @_;

  my $funcrole = $self->{ 'cgi' }->param( 'fr' );
  my $genome = $self->{ 'cgi' }->param( 'genome' );
  my $type = $self->{ 'cgi' }->param( 'type' );
  my $location = $self->{ 'cgi' }->param( 'location' );

  my $func_role = $funcrole;
  $funcrole =~ s/\_/ /g;
  
  # look if someone is logged in and can write the subsystem #
  $self->{ 'can_alter' } = 0;
  my $user = $self->application->session->user;
  
  if (user_can_annotate_genome($self->application, $genome)) {
    $self->{ 'seeduser' } = $user->login();
    $self->{ 'can_alter' } = 1;
  }

  if ( ! $self->{ 'can_alter' } ) {
    return ( '', "You don't have the right to create a feature in this genome!<BR>" );
  }
  if ( !defined( $funcrole ) ) {
    return ( '', "You have not stated an annotation for the new feature!<BR>" );
  }
  if ( !defined( $genome ) ) {
    return ( '', "You have not stated an genome for the new feature!<BR>" );
  }
  if ( !defined( $type ) ) {
    return ( '', "You have not stated type for the new feature!<BR>" );
  }
  if ( !defined( $location ) ) {
    return ( '', "You have not stated location for the new feature!<BR>" );
  }
  my $newfid = $self->{ 'fig' }->add_feature( $self->{ 'seeduser' }, $genome, $type, $location, '' );
  $self->{ 'fig' }->assign_function( $newfid, $self->{ 'seeduser' }, $funcrole );
  return ( "The feature $newfid was created.<BR>", '' );
}

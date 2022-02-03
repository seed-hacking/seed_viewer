package SeedViewer::WebPage::DisplayNMPDRStatistics;

use strict;
use warnings;
use URI::Escape;
use HTML;
use Data::Dumper;
use LWP;
use SubsystemEditor::SubsystemEditor qw( fid_link );

use FIG;

use base qw( WebPage );

1;

##############################################################
# Method for registering components etc. for the application #
##############################################################
sub init {
  my ( $self ) = @_;

  $self->application->register_component( 'Table', 'table_out'  );
  $self->application->register_component( 'Table', 'table_err'  );
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
  my $time = time;


  # needed objects #
  $self->{ 'fig' } = $self->application->data_handle( 'FIG' );
  $self->{ 'cgi' } = $self->application->cgi;
  $self->{ 'can_alter' } = 0;

  $self->{ 'seeduser' } = '';

  my $user = $self->application->session->user;
  # look if someone is logged in and can write the subsystem #
  if ( $user ) {
    if ( $user->has_right(undef, 'annotate', 'genome', '*' ) ) {
      $self->{ 'can_alter' } = 1;
    }
  }

  ################
  # Get the data #
  ################

  if ( $self->{ 'can_alter' } ) {
    my ( $table_out, $table_err ) = $self->get_data();
  
    ##############################
    # Construct the page content #
    ##############################
    
    $self->title( 'Literature NMPDR Statistics' );
    my $content .= "<H1>NMPDR Literature Statistics</H1>";
    
    $content .= "<H2>Summary</H2>";
    $content .= "<P>Counts of PubMed IDs in the NMPDR genomes. The class of genomes and its total counts is shown in the first two columns. The third and fourth columns show the strains and their single counts.</P>";
    $content .= $table_err->output();
    
    $content .= "<H2>Publications per CDS</H2>";
    $content .= "<P>PubMedIds for each CDS in an NMPDR genome. </P>";
    $content .= $table_out->output();
    print STDERR $time." TIME\n";
    return $content;
    
  }
  else {
    $self->title( 'Literature NMPDR Statistics' );
    my $content .= "<H1>NMPDR Literature Statistics</H1>";
    $content .= "You are not logged in or do not have the right to see this information<BR>\n";
    return $content;
  }
}


sub get_data {

  my ( $self ) = @_;

  my $table_out = $self->application->component( 'table_out' );
  my $table_err = $self->application->component( 'table_err' );

  my %class_of;
  my %classes;
  my %counts_by_genome;
  my %counts_by_group;
  my $out_data;
  my $err_data;

  foreach my $genome ( sort(  $self->{ 'fig' }->genomes( 'complete' ) ) ) {    
    if ( -e "$FIG_Config::organisms/$genome/NMPDR" ) {    
      my @tmp = map { $_ =~ /(\S.*\S)/; $1 } `cat $FIG_Config::organisms/$genome/NMPDR`;
      my $class = $tmp[0];
      $class_of{ $genome } = $class;
      $classes{ $class }->{ $genome } = 1;
    }
  }
  
#  open( DLIT,"<$FIG_Config::data/Dlits/dlit.ev.codes") || die "aborted";
#  while ( defined( $_ = <DLIT> ) ) {
#    if ( ( $_ =~ /^(fig\|(\d+\.\d+)\.peg\.\d+)\tevidence_code\tdlit\((\d+)/ ) && $class_of{$2} ) {
#     my $peg = $1;
#      my $peg_link = fid_link( $self, $peg );
#      $peg_link = "<A HREF='$peg_link' target=_blank>$peg</A>";
#      my $genome = $2;
#     my $pubmed = $3;
#      my $gs = $self->{ 'fig' }->genus_species( $genome );
#      push @$out_data, [ $gs, $peg_link, $pubmed ];
#      $counts_by_genome{ $genome }++;
#      $counts_by_group{ $class_of{ $genome } }++;
#    }
#  }
#  close( DLIT );

  my $counter = 0;

  my $dlits = $self->{ 'fig' }->all_dlits_status( 'D' );
  my $dlitss = $self->{ 'fig' }->all_dlits_status( 'S' );
  push @$dlits, @$dlitss;
  my %pegs;
  foreach my $hallo ( @$dlits ) {
    my ( $status, $md5, $pubmed, $curator ) = @$hallo;
    $counter++;

    next unless ( $status eq 'D' || $status eq 'S' );
    my $gs = '';
    my @pegs = $self->{ 'fig' }->pegs_with_md5( $md5 );
    foreach my $peg ( @pegs ) {
      next unless ( $peg =~ /fig/ );
      my $peg_link = fid_link( $self, $peg );
      $peg_link = "<A HREF='$peg_link' target=_blank>$peg</A>";
      my $genome = $self->{ 'fig' }->genome_of( $peg );
      next if ( !defined( $class_of{ $genome } ) );
      my $gs = $self->{ 'fig' }->genus_species( $genome );
      $pegs{ $peg } = [ $gs, $peg_link, $pubmed, $status ];
      $counts_by_genome{ $genome }++;
      $counts_by_group{ $class_of{ $genome } }++;
    }
  }

  my @tmparr = keys %pegs;
  my %subsystems_hash = $self->{ 'fig' }->subsystems_for_pegs( \@tmparr );
  foreach my $p ( keys %pegs ) {
    if ( defined( $subsystems_hash{ $p } ) ) {
      push @{ $pegs{ $p } }, join ( ', ', map { $_->[1] } @{ $subsystems_hash{ $p } } );
    }
    else {
      push @{ $pegs{ $p } }, join ( '' );
    }
    push @$out_data, $pegs{ $p };
  }
  
  foreach my $class ( sort keys( %counts_by_group ) ) {
    foreach my $genome ( sort { $counts_by_genome{ $b } <=> $counts_by_genome{ $a } } keys( %counts_by_genome ) ) {
      if ( $class_of{ $genome } eq $class ) {
	push @$err_data, [ $class, $counts_by_group{ $class }, $self->{ 'fig' }->genus_species( $genome ), $counts_by_genome{ $genome } ];
      }
    }
  }
  
  $table_out->columns( [ { name => 'Genome', sortable => 1, filter => 1 }, 
			 { name => 'Feature', sortable => 1, filter => 1 },
			 { name => 'PubMedId', sortable => 1, filter => 1 },
			 { name => 'Status', sortable => 1, filter => 1 },
			 { name => 'Subsystem', sortable => 1, filter => 1 } ] );
  $table_out->data( $out_data );
  $table_out->items_per_page( 20 );
  $table_out->show_top_browse( 20 );
  $table_out->show_export_button( 1 );

  $table_err->columns( [ { name => 'Genome Class', sortable => 1, filter => 1 }, 
			 { name => 'PubMedIds Total', sortable => 1 },
			 { name => 'Genome', sortable => 1, filter => 1 },
			 { name => 'PubMedIds Genome', sortable => 1 } ] );
  $table_err->data( $err_data );
  $table_err->items_per_page( 20 );
  $table_err->show_top_browse( 20 );
  $table_err->show_export_button( 1 );
  
  return ( $table_out, $table_err );
}

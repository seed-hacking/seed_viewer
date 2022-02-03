package SeedViewer::WebPage::ShowACLHComp;

use base qw( WebPage );

1;

use strict;
use warnings;
use Tracer;
use Data::Dumper;
use SOAP::Lite;


=pod

=head1 NAME

Organism - an instance of WebPage which displays information about an Organism

=head1 DESCRIPTION

Display information about an Organism

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title( 'ACLH Comparison' );
  $self->application->no_bot(1);
  $self->application->register_component( 'Table', 'CompTable' );

  return 1;
}

=item * B<output> ()

Returns the html output of the Organism page.

=cut

sub output {
  my ( $self ) = @_;

  # fetch application, cgi and fig
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $fig = $application->data_handle( 'FIG' );

  # check if we have a valid fig
  unless ( $fig ) {
    $application->add_message( 'warning', 'Invalid organism id' );
    return "";
  }

  # get cgi params
  my $genome = $cgi->param( 'organism' );
  my $genome_name = $fig->genus_species( $genome );
  my $firstpeg = $cgi->param( 'firstpeg' );
  if ( !defined( $firstpeg ) ) {
    $firstpeg = 'fig|'. $genome.'.peg.1';
  }

  my @pegs = $fig->pegs_of( $genome ); 
  my $allpegsnum = scalar( @pegs );
  
  my ( $lastpeg, $ca ) = make_comp_table( $fig, $cgi, $application, \@pegs, $firstpeg );
  my $comptable = $application->component( 'CompTable' );

  unless ( defined( $genome ) ) {
    $application->add_message( 'warning', 'ACLH Comparison called without an organism id' );
    return 0;
  }

  my $html = "<H2>ACLH Comparison for $genome_name</H2>";

  $html .= $self->start_form( 'form', { organism => $genome,
				        firstpeg => $lastpeg } );

  if ( $ca < $allpegsnum ) {
    $html .= $self->button('NEXT', id => 'NEXT', name => 'NEXT');
  }

  $html .= $comptable->output();

  if ( $ca < $allpegsnum ) {
    $html .= $self->button('NEXT', id => 'NEXT', name => 'NEXT');
  }

  $html .= $self->end_form();

  return $html;
}

sub make_comp_table {
  my ( $fig, $cgi, $application, $pegs, $firstpeg ) = @_;

  my $tbcols = [ 'ID',
		 'Annotation NMPDR', 
		 'Annotation Clearing House' ];

  my @rows;
  my @pegsarr;
  my $counter = 0;
  my $ispeg = 0;
  my $preturn;

  my $countall = 0;
  foreach my $p ( sort { &FIG::by_fig_id( $a, $b ) } @$pegs ) {
    $countall++;
    if ( !$ispeg ) {
      if ( $p eq $firstpeg ) {
	$ispeg = 1;
      }
      else {
	next;
      }
    }
    
    $counter ++;
    
    push @pegsarr, $p;
    $preturn = $p;

    last if ( $counter > 50 );
  }

  my $backhash = getannotables( \@pegsarr );
  my $url = $application->url;
  Trace("Looping through pegs using URL $url.") if T(3);
  foreach my $pe ( @pegsarr ) {
    my $func = $fig->function_of( $pe );
    
    my $plink = "<A HREF='".$application->url."?page=Annotation&feature=$pe'>$pe</A>";
    push @rows, [ $plink, $func, $backhash->{ $pe } ];
  }

  my $comptable = $application->component( 'CompTable' );
  $comptable->columns( $tbcols );
  $comptable->data( \@rows ); 

  return ( $preturn, $countall );
}

sub getannotables {
  my ( $pegs ) = @_;

  my %tabs;

  my $result = SOAP::Lite
    -> uri('http://www.nmpdr.org/AnnoClearinghouse_SOAP')
      -> proxy('http://clearinghouse.nmpdr.org/aclh-soap.cgi')
	-> get_annotations( $pegs )
	  ->result;

  my $result_user = SOAP::Lite
    -> uri('http://www.nmpdr.org/AnnoClearinghouse_SOAP')
      -> proxy('http://clearinghouse.nmpdr.org/aclh-soap.cgi')
	-> get_user_annotations( $pegs )
	  ->result;

  foreach my $p ( @$pegs ) {
    my $tab = "<TABLE>";

    if ( ref( $result ) ) {
      foreach my $rid ( @{ $result->{ $p } } ) {
	my $id = $rid->[0];
	my $func = $rid->[2];
	my $link = getlink( $rid->[0] );
	if ( !defined( $func ) ) {
	  $func = '';
	}
	$tab .= "<TR><TD>$link</TD><TD>$func</TD></TR>";
      }
    }

    if ( ref( $result_user ) ) {
      foreach my $rid ( @{ $result_user->{ $p } } ) {
	my $id = $rid->[0];
	my $func = $rid->[1];
	my $link = getlink( $rid->[0] );
	$tab .= "<TR STYLE='background-color: #00ff00;' ><TD>$link</TD><TD>$func</TD></TR>";
      }
    }

    $tab .= "</TABLE>";
    $tabs{ $p } = $tab;
  }

  return \%tabs;
}

sub getlink {

  my ( $extident ) = @_;
  if ( $extident =~ /^sp\|(.*)/ ) {
    $extident = "<A HREF='http://ca.expasy.org/uniprot/$1' target='_blank'>$extident</A>";
  }
  elsif ( $extident =~ /^tr\|(.*)/ ) {
    $extident = "<A HREF='http://ca.expasy.org/uniprot/$1' target='_blank'>$extident</A>";
  }
  elsif ( $extident =~ /^kegg\|(.*)/ ) {
    $extident = "<A HREF='http://www.genome.jp/dbget-bin/www_bget?$1' target='_blank'>$extident</A>";
  }
  elsif ( $extident =~ /^gi\|(.*)/ ) {
    $extident = "<A HREF='http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi?db=protein&id=$1' target='_blank'>$extident</A>";
  }
  elsif ( $extident =~ /^img\|(.*)/ ) {
    $extident = "<A HREF='http://img.jgi.doe.gov/cgi-bin/pub/main.cgi?section=GeneDetail&page=geneDetail&gene_oid=$1' target='_blank'>$extident</A>";
  }
  elsif ( $extident =~ /^fig\|(.*)/ ) {
    $extident = "<A HREF='http://seed-viewer.theseed.org/index.cgi?action=ShowAnnotation&prot=fig|$1' target='_blank'>$extident</A>";
  }
  elsif ( $extident =~ /^tigrcmr\|(.*)/ ) {
    $extident = "<A HREF='http://cmr.tigr.org/tigr-scripts/CMR/shared/GenePage.cgi?locus=$1' target='_blank'>$extident</A>";
  }
  
  return $extident;
}

sub required_rights {
  my ($self) = @_;
  
  my $rights = [];

  my $app = $self->application();
  my $o = $app->cgi->param('feature') || $app->cgi->param('organism');
  $o =~ /^fig\|(\d+\.\d+)\..+\.\d+$/;
  if ($1) {
    $o = $1;
  }
  my $dbm = $app->dbmaster;
  if ( $o and scalar(@{$dbm->Rights->get_objects({ name => 'view',
						   data_type => 'genome',
						   data_id => $o, 
						 })
		     })
     ) {
    push @$rights, [ 'view', 'genome', $o ];
  }
  
  return $rights;
}

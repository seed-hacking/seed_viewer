package SeedViewer::WebPage::SearchGeneByFeature;

use strict;
use warnings;
use URI::Escape;
use HTML;
use Data::Dumper;
use FIG;
use FIG_Config;
use SeedViewer::SeedViewer;

use gjoparseblast  qw( next_blast_hsp );

use base qw( WebPage );

1;

##############################################################
# Method for registering components etc. for the application #
##############################################################
sub init {
  my ( $self ) = @_;

  $self->application->register_component( 'FilterSelect', 'OrganismSelect' );
  $self->application->register_component( 'GenomeDrawer', 'GenomeDrawer' );
  $self->title('Search Gene');
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
  
  # subsystem name and 'nice name' #
  my $genome = $self->{ 'cgi' }->param( 'organism' );
  my $feature = $self->{ 'cgi' }->param( 'feature' );
  if ( !defined( $feature ) ) {
    $feature = '';
  }

  # look if someone is logged in and can write the subsystem #
  $self->{ 'can_alter' } = 0;
  my $user = $self->application->session->user;

  my $dbmaster = $self->application->dbmaster;
  my $ppoapplication = $self->application->backend;
  
  # get a seeduser #
  my $seeduser = '';
  if ( defined( $user ) && ref( $user ) ) {
    my $preferences = $dbmaster->Preferences->get_objects( { user => $user,
							     name => 'SeedUser',
							     application => $ppoapplication } );
    if ( defined( $preferences->[0] ) ) {
      $seeduser = $preferences->[0]->value();
      $self->{ 'seeduser' } = $seeduser;
    }
  }

  my @private_labels;
  my @private_values;
  if ( $user ) {
    $self->{ 'can_alter' } = 1;
    $self->{ 'fig' }->set_user( $seeduser );
    $self->{ 'seeduser' } = $seeduser;
    
    # get a rast master
    # This isn't needed - the proper set of genomes
    # gets included in the FIGM by the FIGM code.
    #
    if ($FIG_Config::rast_jobs && 0) {
      my $rast = $self->application->data_handle('RAST');	
      if (ref($rast)) {
	my @jobs = $rast->Job->get_jobs_for_user_fast($user, 'view', 1);
	@jobs = sort { $a->{genome_name} cmp $b->{genome_name} } @jobs;
	foreach my $job (@jobs) {
	  my $orgname = "";
	  $orgname = "Private: ".$job->{genome_name}." (".$job->{genome_id}.")";
	  push(@private_values, $job->{genome_id});
	  push(@private_labels, $orgname);
	}
      }
    }
  }

  my ( $error, $comment ) = ( "", "" );

  my $genomes = $self->{ 'fig' }->genome_info();
  my @genomessorted = sort { $a->[1] cmp $b->[1] } @$genomes;
  my @genomelabels = map { $_->[1] . '( '. $_->[0].' )' } @genomessorted;
  my @genomevalues = map { $_->[0] } @genomessorted;
  unshift(@genomelabels, @private_labels);
  unshift(@genomevalues, @private_values);

  # create the select organism component
  my $organism_select_component = $self->application->component( 'OrganismSelect' );
  $organism_select_component->labels( \@genomelabels );
  $organism_select_component->values( \@genomevalues );
  $organism_select_component->name( 'organism' );
  if ( defined( $genome ) ) {
    $organism_select_component->default( $genome );
  }

  $organism_select_component->width(500);

  my $found_tblastn = undef;

  ########
  # TASK #
  ########
  if ( $self->{ 'cgi' }->param( 'SUBMIT' ) ) {
    $feature = $self->{ 'cgi' }->param( 'template_gene' );
    $found_tblastn = $self->get_tblastn_table( {}, $feature, $genome );
  }

  ###########
  # CONTENT #
  ###########
  my $content = "<H1>Search Gene By Organism and Feature</H1>\n";
  $content .= "<H2>Select an Organism</H2>";
  $content .= $self->start_form( 'organism_select_form' );
  $content .= $organism_select_component->output();

  $content .= "<H2>Type in a feature to search for:</H2>";
  $content .= "<INPUT TYPE=INPUT ID='template_gene' NAME='template_gene' VALUE='$feature'>";

  $content .= "<INPUT TYPE=SUBMIT NAME='SUBMIT'>";
  $content .= $self->end_form();

  if ( $found_tblastn ) {
    $content .= "<H2>Result</H2>";
    my $in = 0;
    foreach my $ftbn ( @$found_tblastn ) {
      $content .= $ftbn;
      $in = 1;
    }
    if ( !$in ) {
      $content .= "Nothing found.\n";
    }
  }

  return $content;
}

sub get_tblastn_table {

  my ( $self, $genes_in_sub, $closestpeg, $org ) = @_;

  my $tmp_seq = "$FIG_Config::temp/run_blast_tmp$$.seq";
  my $query = $closestpeg;
  

  my @locs;
  if ( ( @locs = $self->{ 'fig' }->feature_location( $query ) ) && ( @locs > 0 ) ) {

    my $seq = $self->{ 'fig' }->dna_seq( $self->{ 'fig' }->genome_of( $query ), @locs );
    $seq = $self->{ 'fig' }->get_translation( $query );

    $seq =~ s/\s+//g;

    open( SEQ, ">$tmp_seq" ) || die "run_blast could not open $tmp_seq";
    print SEQ ">$query\n$seq\n";
    close( SEQ );
    
    if (! $ENV{"BLASTMAT"}) { $ENV{"BLASTMAT"} = "$FIG_Config::blastmat" }
    my $blast_opt = $self->{ 'cgi' }->param( 'blast_options' ) || '';
    
    my $rawgenome = $org;
    if ( $org =~ /(\d+\.\d+)\:(.*)/ ) {
      $rawgenome = $1;
    }

    my $db = $self->{ 'fig' }->organism_directory($org)."/contigs";
    &verify_db( $db, "n" );                               ### fix to get all contigs
    
    my @out = execute_blastall( 'tblastn', $tmp_seq, $db, $blast_opt );
    unlink( $tmp_seq );

    my @bg = $self->blast_graphics( $genes_in_sub, $org, \@out );
    return \@bg;
  }
  return 0;
}

sub verify_db {
    my($db,$type) = @_;

    if ($type =~ /^p/i)
    {
        if ((! -s "$db.psq") || (-M "$db.psq" > -M $db))
        {
            system "$FIG_Config::ext_bin/formatdb -p T -i $db";
        }
    }
    else
    {
        if ((! -s "$db.nsq") || (-M "$db.nsq" > -M $db))
        {
            system "$FIG_Config::ext_bin/formatdb -p F -i $db";
        }
    }
}       

sub execute_blastall
{
    my( $prog, $input, $db, $options ) = @_;

    my $blastall = "$FIG_Config::ext_bin/blastall";

    my @args = ( '-p', $prog, '-i', $input, '-d', $db, split(/\s+/, $options) );
    my $bfh;
    my $pid = open( $bfh, "-|" );
    if ( $pid == 0 )
    {
        exec( $blastall,  @args );
        die join( " ", $blastall, @args, "failed: $!" );
    }

    <$bfh>
}


sub blast_graphics {
  my ( $self, $genes_in_sub, $genome, $out ) = @_;
  
  my $window_size = 12000;
  my $rawgenome = $genome;
  my $loc;
  my ( $loc_c, $loc_start, $loc_stop );

  if ( $genome =~ /(\d+\.\d+)\:(.*)/ ) {
    $rawgenome = $1;
    $loc = $2;
    ( $loc_c, $loc_start, $loc_stop ) = $self->{ 'fig' }->boundaries_of( $loc );
  }


  my $e_min = 0.1;
  my $gg = [];
  my @html = ();
  my $gs = $self->{ 'fig' }->genus_species( $rawgenome );
  
  #  Changed to use standalone parsing function, not shell script -- GJO
  
  my $outcopy = [ @$out ];
  my $lines = [];
  
  while ( $_ = &gjoparseblast::next_blast_hsp( $outcopy ) ) {
    my ( $qid, $qlen, $contig, $slen ) = @$_[0, 2, 3, 5 ];
    my ( $e_val, $n_mat, $n_id, $q1, $q2, $s1, $s2 ) = @$_[ 7, 10, 11, 15, 16, 18, 19 ];

    if ( defined( $loc ) ) {
      next if ( $contig ne $loc_c || $s1 < $loc_start ||$s2 > $loc_stop );
    }

    next if $e_val > $e_min;
    my ( $genes, $min, $max ) = $self->hsp_context( $genes_in_sub, $genome,
					     $e_val, 100 * $n_id / $n_mat,
					     $qid,    $q1, $q2, $qlen,
					     $contig, $s1, $s2, $slen
					   );
    if ( $min && $max ) {
      # reset window size if default is too small #
      my $this_window_size = $max - $min;
      if ( $this_window_size > $window_size ) {
	$window_size = $this_window_size;
      }

      push @$gg, [ substr( $contig, 0, 18 ), $min, $max, $genes ];
    }
    
    my $line_config = { 'title' => "$genome\: $gs",
			'short_title' => $contig,
			'title_link' => 'http://www.google.de',
			'basepair_offset' => $min,
			'line_height' => 22 };
    
    my $line_data = [];
    foreach my $g ( @$genes ) {
      my $start = $g->[0];
      my $stop = $g->[1];
      if ( $g->[2] eq 'leftArrow' ) {
	$start = $g->[1];
	$stop = $g->[0];
      }

      my $colorthis = get_app_color( $g->[3] );
      
      my $thislinedata = { 'start' => $start, 'end' => $stop, 'type' => 'arrow', 'label' => $g->[4], 'color' => $colorthis, 'title' => 'Feature', 'description' => $g->[6] };

      if ( defined( $g->[5] ) ) {
	$thislinedata->{ 'onclick' } = "window.open( '".$g->[5]."' );";
      }

      push @$line_data, $thislinedata;
      
    }
    my $newlines = $self->resolve_overlays( $line_data );
    
    my $in = 0;
    foreach my $nl ( @$newlines ) {
      if ( !$in ) {
	push @$lines, [ $nl, $line_config ];
	$in = 1;
      }
      else {
	push @$lines, [ $nl, { 'line_height' => 24, 'no_middle_line' => 1, 'basepair_offset' => $min, 'line_height' => 22 } ];
      }
    }
    push @$lines, [ [], { 'line_height' => 24, 'no_middle_line' => 1 } ];
  }
  
  if ( @$gg ) {
    my $space = "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
    my $legend = "<TABLE>\n"
      . "    <TR>\n"
	. "        <TD>Q = Query sequence$space</TD>\n"
	  . "        <TD Bgcolor='#F69090'>$space</TD><TD>Frame 1$space</TD>\n"
	    . "        <TD Bgcolor='#90EE90'>$space</TD><TD>Frame 2$space</TD>\n"
	      . "        <TD Bgcolor='#AAAAFF'>$space</TD><TD>Frame 3$space</TD>\n"
		. "        <TD Bgcolor='#FF0000'>$space</TD><TD Bgcolor='#00A000'>$space</TD><TD Bgcolor='#0000FF'>$space</TD><TD>Gene is in subsystem$space</TD>\n"
		  . "        <TD Bgcolor='#C0C0C0'>$space</TD><TD>Untranslated feature</TD>\n"
		    . "    </TR>\n"
		      . "</TABLE><P />";
    
    my $gd = $self->application->component( 'GenomeDrawer' );
    
    $gd->width(600);
    $gd->show_legend(1);
    $gd->window_size( $window_size );
    $gd->display_titles(1);
    
    foreach my $line ( @$lines ) {
      $gd->add_line( $line->[0], $line->[1] );
    }
    
    push @html, $legend;
    push @html, $gd->output;
  }
  
  return @html;
}

sub get_app_color {
  my ( $old ) = @_;
  if ( $old eq 'color19' ) {
    return [ 150, 150, 255 ];
  }
  if ( $old eq 'color9' ) {
    return [ 255, 150, 150 ];
  }
  if ( $old eq 'color11' ) {
    return [ 150, 255, 150 ];
  }
  if ( $old eq 'blue' ) {
    return [ 50, 50, 255 ];
  }
  if ( $old eq 'red' ) {
    return [ 255, 50, 50 ];
  }
  if ( $old eq 'color12' ) {
    return [ 50, 155, 50 ];
  }
  if ( $old eq 'ltgrey' ) {
    return [ 50, 50, 50 ];
  }

}

sub hsp_context {
    my( $self, $genes_in_sub, $genome, $e_val, $pct_id,
        $qid,    $q1, $q2, $qlen,
        $contig, $s1, $s2, $slen ) = @_;
    my $half_sz = 5000;

    my( $from, $to, $features, $fid, $beg, $end );
    my( $link, $lbl, $isprot, $function, $uniprot, $info, $prot_query );

    my $sprout = $self->{ 'cgi' }->param( 'SPROUT' ) ? '&SPROUT=1' : '';

    my @genes  = ();

    #  Based on the match position of the query, select the context region:

    ( $from, $to ) = ( $s1 <= $s2 ) ? ( $s1 - $half_sz, $s2 + $half_sz )
                                    : ( $s2 - $half_sz, $s1 + $half_sz );
    $from = 1      if ( $from < 1 );
    $to   = $slen  if ( $to > $slen );

    #  Get the genes in the region, and adjust the ends to include whole genes:

    ( $features, $from, $to ) = $self->{ 'fig' }->genes_in_region( $genome, $contig, $from, $to, undef, ['rna', 'peg'] );

    #  Fix the end points if features have moved them to exclude query:

    if ( $s1 < $s2 ) { $from = $s1 if $s1 < $from; $to = $s2 if $s2 > $to }
    else             { $from = $s2 if $s2 < $from; $to = $s1 if $s1 > $to }

    #  Add the other features:

    foreach $fid ( @$features )
    {
        my $contig1;
        ( $contig1, $beg, $end ) = $self->{ 'fig' }->boundaries_of( $self->{ 'fig' }->feature_location( $fid ) );
        next if $contig1 ne $contig;

        $link = "";
        if ( ( $lbl ) = $fid =~ /peg\.(\d+)$/ ) {
            $link = "?page=Annotation&feature=$fid";
            $isprot = 1;
        } elsif ( ( $lbl ) = $fid =~ /\.([a-z]+)\.\d+$/ ) {
            $lbl = uc $lbl;
            $isprot = 0;
        } else {
            $lbl = "";
            $isprot = 0;
        }

        $function = $self->{ 'fig' }->function_of( $fid );

        $uniprot = join ", ", grep { /^uni\|/ } $self->{ 'fig' }->feature_aliases( $fid );

	$info = [ { 'title' => 'ID', 'value' => $fid },
		  { 'title' => 'Contig', 'value' => $contig, },
		{ 'title' => 'Begin', 'value' => $beg },
		{ 'title' => 'End', 'value' => $end },
		{ 'title' => 'Function', 'value' => $function },
		{ 'title' => 'Uniprot ID', 'value' => $uniprot }];

        push @genes, [ feature_graphic( $beg, $end, $isprot, $fid, $genes_in_sub ),
                       $lbl, $link, $info,
                       $isprot ? () : ( undef, "Feature information" )
                     ];
    }
    
    my $genomeof = $self->{ 'fig' }->genome_of( $qid );
    my $genomestring = $self->{ 'fig' }->genus_species( $genomeof );

    $info = [ { 'title' => 'Query', 'value' => $qid },
	      { 'title' => 'Query genome', 'value' => $genomestring },
	      { 'title' => 'Length', 'value' => $qlen },
	      { 'title' => 'E-value', 'value' => $e_val, },
	      { 'title' => 'Identity', 'value' => sprintf( "%.1f", $pct_id ) },
	      { 'title' => 'Region of similarity', 'value' => "$q1 &#150; $q2" } ];


    $prot_query = ( 1.7 * abs( $q2 - $q1 ) < abs( $s2 - $s1 ) ) ? 1 : 0;

    if ( $prot_query )    {
      if ($FIG_Config::anno3_mode) {
	$link = "SubsysEditor.cgi?page=ProposeNewPeg&genome=$genome&covering=${contig}_${s1}_${s2}";
      } else {
	my $fig = $self->{fig};
	my $user = $self->application->session->user;
	if (user_can_annotate_genome($self->application, $genome)) {
	  $link = "?page=ProposeNewPeg&organism=$genome&covering=${contig}_${s1}_${s2}";
	} else {
	  $link = undef;
	}
      }
    }

    push @genes, [ feature_graphic( $s1, $s2, $prot_query, 'query' ),
                   'Q', $link, $info, undef, 'Query and match information'
                 ];

    return \@genes, $from, $to;
}


sub feature_graphic {
    my ( $beg, $end, $isprot, $peg, $genes_in_sub ) = @_;

    my ( $min, $max, $symb ) = ( $beg <= $end ) ? ( $beg, $end, "rightArrow" )
                                             : ( $end, $beg, "leftArrow" );

    #  Color proteins by translation frame

    my $color = $isprot ? qw( color19 color9 color11 )[ $beg % 3 ] : 'ltgrey';
    my $color2 = $isprot ? qw( 1 2 3 )[ $beg % 3 ] : '4';

    if ( defined( $genes_in_sub->{ $peg } ) || $peg eq 'query' ) {
      $color = $isprot ? qw( blue red color12 )[ $beg % 3 ] : 'ltgrey';
      $color2 = $isprot ? qw( 5 6 7 )[ $beg % 3 ] : '4';
    }

    return ( $min, $max, $symb, $color );
}

sub resolve_overlays {
  my ($self, $features) = @_;

  my $lines = [ [ ] ];
  foreach my $feature (@$features) {
    my $resolved = 0;
    my $fs = $feature->{start};
    my $fe = $feature->{end};
    if ($fs > $fe) {
      my $x = $fs;
      $fs = $fe;
      $fe = $x;
    }
    foreach my $line (@$lines) {
      my $conflict = 0;
      foreach my $item (@$line) {
	my $is = $item->{start};
	my $ie = $item->{end};
	if ($is > $ie) {
	  my $x = $is;
	  $is = $ie;
	  $is = $x;
	}
	if ((($fs <= $ie) && ($fs >= $is)) || (($fe <= $ie) && ($fe >= $is)) || (($fs <= $is) && ($fe >= $ie))){
	  $conflict = 1;
	  last;
	}
      }
      unless ($conflict) {
	push(@$line, $feature);
	$resolved = 1;
	last;
      }
    }
    unless ($resolved) {
      push(@$lines, [ $feature ]);
    }
  }

  return $lines;
}


sub in_genome {
    my ( $self, $genome, $fid ) = @_;

    if ($genome =~ /^(\d+\.\d+)(:(\S+)_(\d+)_(\d+))?$/) {
	my $just_genome = $1;
	my($contig,$beg,$end) = $2 ? ($3,$4,$5) : (undef,undef,undef);
	my $fidG = $self->{fig}->genome_of($fid);
	if (! $contig) { return ($just_genome eq $fidG) }
	my $loc = $self->{ 'fig' }->feature_location($fid);
	my($contig1,$beg1,$end1) = $self->{ 'fig' }->boundaries_of($loc);
	return (($contig1 eq $contig) && 
		&FIG::between($beg,$beg1,$end) && 
		&FIG::between($beg,$end1,$end));
    }
    else
    {
	return 0;
    }
}

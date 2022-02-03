package SeedViewer::WebPage::SearchGene;

use strict;
use warnings;
use URI::Escape;
use HTML;
use Data::Dumper;
use SeedViewer::SeedViewer;

use gjoparseblast  qw( next_blast_hsp );

use base qw( WebPage );

1;

##############################################################
# Method for registering components etc. for the application #
##############################################################
sub init {
  my ( $self ) = @_;

  $self->title('Find Gene for Role');
  $self->application->register_component( 'Hover', 'TableHoverComponent' );
  $self->application->register_component( 'Table', 'HitsTable' );
  $self->application->register_component( 'Table', 'GenesWithMotifTable' );
  $self->application->register_component( 'GenomeDrawer', 'GenomeDrawer' );
}

##############################################
# Website content is returned by this method #
##############################################
sub output {
  my ( $self ) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;
  my $dbmaster = $application->dbmaster;
  my $user = $application->session->user;

  $self->{ 'fig' } = $application->data_handle('FIG');
  $self->{ 'cgi' } = $cgi;
  
  # subsystem name and 'nice name' #
  my $name = $self->{ 'cgi' }->param( 'subsystem' );
  my $ssname = $name;
  $ssname =~ s/\_/ /g;

  my $subsystem = $self->{fig}->get_subsystem($name);

  my $funcrole = uri_unescape($cgi->param( 'fr' ));
  my $genome = $cgi->param( 'organism' );
  my $frabbk = $cgi->param( 'frabbk' );

  if ( defined( $frabbk ) && !defined( $funcrole ) ) {
    $funcrole = $subsystem->get_role_from_abbr( $frabbk );
  }
  elsif ( defined( $funcrole ) && !defined( $frabbk ) ) {
    $frabbk = $subsystem->get_abbr_for_role( $funcrole );
  }
  my $func_role = $funcrole;
  $funcrole =~ s/\_/ /g;
  $self->{funcrole} = $funcrole;

  # look if someone is logged in and can write the subsystem #
  $self->{ 'can_alter' } = user_can_annotate_genome($application, $genome);

  #########
  # TASKS #
  #########

  my $cptobe;
  if ( $self->{ 'cgi' }->param( 'template_gene' )) {
    $cptobe = $self->{ 'cgi' }->param( 'template_gene' );
  } elsif ( $self->{ 'cgi' }->param( 'TAKEGENE' ) ) {
    my $cptobefull = $self->{ 'cgi' }->param( 'SEARCHBOX' );
    if ( $cptobefull =~ /.* : (.*)/ ) {
      $cptobe = $1;
    }
  }

  if ( $self->{ 'cgi' }->param( 'JUSTADD' ) ) {
    my @to_pegs = $self->{ 'cgi' }->param( 'aachecked' );

    $self->put_pegs_into_spreadsheet( $funcrole, $subsystem, \@to_pegs);
  }

  my %genes_in_sub;
  my $idx = $subsystem->get_genome_index( $genome );
  my $row = $subsystem->get_row( $idx );
  foreach my $c ( @$row ) {
    foreach my $g ( @$c ) {
      $genes_in_sub{ $g } = 1;
    }
  }
  
  my ( $idolsarr, $closestpeg ) = $self->get_idols( $subsystem, $funcrole, $genome );
  if ( defined( $cptobe ) && $cptobe =~ /^fig.*/ ) {
    $closestpeg = $cptobe;
  }
  my $found_similarities = $self->get_candidates_blast_table( $funcrole, $genome );
  my $found_tblastn = $self->get_tblastn_table( \%genes_in_sub, $closestpeg, $genome );


  ##############################
  # Construct the page content #
  ##############################
 
  my $content = qq~
<STYLE>
.hideme {
   display: none;
}
.showme {
   display: all;
}
</STYLE>
~;
  
  my $genus_species = $self->ext_genus_species( $genome );
  my $gwmtable = $self->application->component( 'GenesWithMotifTable' );
  my $hitstable = $self->application->component( 'HitsTable' );
  
  $content .= $self->start_form( 'form', { subsystem => $name,
					   fr        => $func_role, 
					   organism  => $genome,
					   frabbk    => $frabbk } );
  my $pretty_ss_name = $name;
  $pretty_ss_name =~ s/_/ /g;

  $content .= "<H2>Find a gene for $frabbk in $pretty_ss_name:<H2>\n<H2>\'$funcrole\' in $genus_species ($genome)</H2>";

  $content .= "<P style='width: 800px;'>We offer two ways of finding a gene for a role in a subsystem. First we will try to find proteins in this genome, which match proteins in other genomes, that have been annotated with this role. Then we perform a tblastn of a template gene against the genome to check if the gene has maybe not been called.</P>";

  $content .= "<H2>I: Candidate genes found by Similarity (BLAST)?</H2>";
  if ( $found_similarities ) {
    $content .= $hitstable->output();
    if ( $self->{ 'can_alter' } ) {
      $content .= "<INPUT TYPE=SUBMIT VALUE='Assign Role' ID='JUSTADD' NAME='JUSTADD'>";
    }
  }
  else {
    $content .= "<P>No genes found.</P>";
  }

  # tblastn part
  $content .= "<H2>II: Is the gene maybe not called?</H2>";
  if ( $found_tblastn ) {
    if ( defined( $closestpeg ) ) {
      my $tmpgene = "<a href='".fid_link($closestpeg)."' target=_blank>".$closestpeg."</a>";
      my $tmpgenome = $self->{ 'fig' }->genome_of( $closestpeg );
      my $tmpgenspec = $self->{ 'fig' }->genus_species( $tmpgenome );
      my $tmpgene_link = "<A HREF='$tmpgene' target=_blank>$closestpeg ($tmpgenspec)</A>";

      $content .= "<H3>Template gene used for this analysis: $tmpgene</H3>";
      my $searchbox = "<SELECT NAME='SEARCHBOX' ID='SEARCHBOX'>";
      my @options;
      foreach my $gene ( @$idolsarr ) {
	my $selected = "";
	if ($gene eq $closestpeg) {
	  $selected = " selected=selected";
	}
	my $genome = $self->{ 'fig' }->genome_of( $gene );
	my $genspec = $self->{ 'fig' }->genus_species( $genome );
	push @options, "<OPTION$selected>$genspec : $gene</OPTION>";
      }
      $searchbox .= join( "\n", sort @options );
      $searchbox .= "</SELECT>";
      $content .= $searchbox;
      $content .= "<INPUT TYPE=SUBMIT class='button' VALUE='Take this gene for tblastn search' NAME='TAKEGENE' ID='TAKEGENE'><BR><BR>";
    }
    else {
      $content .= "<H3>No template gene found.</H3>";
    }
    my $in = 0;
    foreach my $ftbn ( @$found_tblastn ) {
      $content .= $ftbn;
      $in = 1;
    }
    unless( $in ) {
      $content .= "<P>Nothing found.</P>";
    }
  }
  else {
    $content .= "<P>Nothing found.</P>";
  }

  # close the form
  $content .= $self->end_form();

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

sub get_candidates_blast_table {

  my ( $self, $role, $org ) = @_;

  my $user = $self->application->session->user;
  my $uname;
  if ($user) {
    $uname = $user->login;
  }

  my $loc;
  my $rawgenome = $org;
  if ( $org =~ /(\d+\.\d+)\:(.*)/ ) {
    $rawgenome = $1;
    $loc = $2;
  }

  my @hits = $self->{ 'fig' }->find_role_in_org( $role, $rawgenome, $uname, $self->{ 'cgi' }->param("sims_cutoff") );

  my $hitstable = $self->application->component( 'HitsTable' );

  my $colhdr;
  if ( $self->{ 'can_alter' } ) {
    $colhdr = ["Assign", "P-Sc", "CDS", "Len", "Current fn", "Matched peg", "Len", "Function"];
  }
  else {
    $colhdr = ["P-Sc", "PEG", "Len", "Current fn", "Matched peg", "Len", "Function"];
  }

  my $idol = 1;

  if ( @hits > 0) {
    my $genus_species = $self->ext_genus_species( $rawgenome );
      
    my $tbl = [];
      
    for my $hit (@hits) {
      my ( $psc, $my_peg, $my_len, $my_fn, $match_peg, $match_len, $match_fn ) = @$hit;

      if ( $idol eq '1' && defined( $my_peg ) ) {
	$idol = $my_peg;
      }

      $my_peg =~ /fig\|\d+\.\d+\.peg\.(\d+)/;
      my $n = $1;
      my $my_peg_link = fid_link( $my_peg );
      $my_peg_link = "<A HREF='$my_peg_link' target=_blank>$n</A>";

      $match_peg =~ /fig\|\d+\.\d+\.peg\.(\d+)/;
      $n = $1;
      my $match_peg_link = fid_link( $match_peg );
      $match_peg_link = "<A HREF='$match_peg_link' target=_blank>$match_peg</A>";
	
      my $checkbox = $self->{ 'cgi' }->checkbox( -name => "aachecked",
						 -value => "aacheckbox_$my_peg"."_to_$match_peg",
						 -label => "" );
	
      if ( $self->{ 'can_alter' } ) {
	push(@$tbl, [ $checkbox,
		      $psc,
		      $my_peg_link, $my_len, $my_fn,
		      $match_peg_link, $match_len, $match_fn]);
      }
      else {
	push(@$tbl, [ $psc,
		      $my_peg_link, $my_len, $my_fn,
		      $match_peg_link, $match_len, $match_fn]);
      }

    }
    $hitstable->columns( $colhdr );
    $hitstable->data( $tbl );
    return $idol;
  }
  return 0;
}

sub ext_genus_species {
  my ( $self, $genome ) = @_;
  
  my ($gsd, $gs, $c);
  if (ref($self->{ 'fig' }->genus_species_domain( $genome )) eq 'ARRAY') {
    $gsd = $self->{ 'fig' }->genus_species_domain( $genome );
    $gs = $gsd->[0];
    $c = $gsd->[1];
  } else {
    ($gs, $c) = $self->{ 'fig' }->genus_species_domain( $genome );
  }
  $c = ( $c =~ m/^Environ/i ) ? 'M' : substr($c, 0, 1);  # M for metagenomic
  return "$gs [$c]";
}

sub fid_link {
  my ( $fid ) = @_;
  my $n;
  
  if ($fid =~ /^fig\|\d+\.\d+\.([a-zA-Z]+)\.(\d+)/) {
    if ( $1 eq "peg" ) {
      $n = $2;
    }
    else {
      $n = "$1.$2";
    }
  }
  
  return "?page=Annotation&feature=$fid";
}

sub get_idols {

  my ( $self, $subsystem, $role, $genome ) = @_;

  if ( $genome =~ /(\d+\.\d+)\:(.*)/ ) {
    $genome = $1;
  }

  my $roleidx = $subsystem->get_role_index( $role );

  my $col = $subsystem->get_col( $roleidx );
  my @pegs = ();
  my $ceod = 1;
  my $closestpeg;

  foreach my $cell ( @$col ) {
    next if ( !defined( $cell->[0] ) );
    my $thisgenome = $self->{ 'fig' }->genome_of( $cell->[0] );

    if ( $thisgenome =~ /(\d+\.\d+)\:(.*)/ ) {
      $thisgenome = $1;
    }

    my $this_ceod = $self->{ 'fig' }->crude_estimate_of_distance( $genome, $thisgenome );

    if ( $this_ceod < $ceod ) {
      $closestpeg = $cell->[0];
    }
    push @pegs, @$cell;
  }
  if ( !defined( $closestpeg ) ) {
    $closestpeg = $pegs[0];
  }

  return ( \@pegs, $closestpeg );
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
  
  my $rawgenome = $genome;
  my $loc;
  my ( $loc_c, $loc_start, $loc_stop );
  if ( $genome =~ /(\d+\.\d+)\:(.*)/ ) {
    $rawgenome = $1;
    $loc = $2;
    ( $loc_c, $loc_start, $loc_stop ) = $self->{ 'fig' }->boundaries_of( $loc );
  }

  my $window_size = 12000;
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
      my $thiswindow = $max - $min;
      if ($thiswindow > $window_size) {
	$window_size = $thiswindow;
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
    $gd->window_size($window_size);
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

    ( $features, $from, $to ) = $self->{ 'fig' }->genes_in_region( $genome, $contig, $from, $to );

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

	my $len = abs($end-$beg+1);
	$info = [ { 'title' => 'ID', 'value' => $fid },
		  { 'title' => 'Contig', 'value' => $contig, },
		  { 'title' => 'Begin', 'value' => $beg },
		  { 'title' => 'End', 'value' => $end },
		  { 'title' => 'Length', 'value' => $len."bp (".int($len/3)."aa)" },
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
	      { 'title' => 'Length', 'value' => $qlen."aa" },
	      { 'title' => 'E-value', 'value' => $e_val, },
	      { 'title' => 'Identity', 'value' => sprintf( "%.1f", $pct_id ) },
	      { 'title' => 'Region of similarity', 'value' => "$q1 &#150; $q2" },
	      { 'title' => 'Hit region', 'value' => "$s1 &#150; $s2 (".(abs($s1-$s2)+1)."bp)" } ];


    $prot_query = ( 1.7 * abs( $q2 - $q1 ) < abs( $s2 - $s1 ) ) ? 1 : 0;

    if ( $prot_query )    {
      $link = "?page=ProposeNewPeg&organism=$genome&covering=${contig}_${s1}_${s2}&function=".uri_escape($self->{funcrole});
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
	if ((($fs < $ie) && ($fs > $is)) || (($fe < $ie) && ($fe > $is)) || (($fs < $is) && ($fe > $ie))){
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


sub put_pegs_into_spreadsheet {
  
  my ( $self, $role, $subsystem, $pegs ) = @_;

  return unless $self->{ 'can_alter' };

  my $user = $self->application->session->user;
  
  foreach my $ent ( @$pegs ) {
    if ( $ent =~ /^aacheckbox\_(.*)\_to\_(.*)$/ ) {
      my $to_peg = $1;
      my $from_peg = $2;
      my $from_func = $self->{ 'fig' }->function_of( $from_peg );
	
      next unless $from_func;
      my $username = $user->login;
      my $prefs = $self->application->dbmaster->Preferences->get_objects( { user => $user, name => 'SeedUser' } );
      if (scalar(@$prefs)) {
	$username = $prefs->[0]->value;
      }
      if ( $self->{ 'fig' }->assign_function( $to_peg, $username, $from_func, "" ) ) {
	$self->application->add_message('info', "Set function of $to_peg to $from_func");	  
      }
      else {
	$self->application->add_message('warning',  "Error assigning $from_func to $to_peg.");
      }
    }
  }
    
  return 1;
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

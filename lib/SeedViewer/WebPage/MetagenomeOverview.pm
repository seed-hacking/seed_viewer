package SeedViewer::WebPage::MetagenomeOverview;

# $Id: MetagenomeOverview.pm,v 1.23 2009-08-26 20:33:50 olson Exp $

use base qw( WebPage );

use strict;
use warnings;

use WebConfig;
use WebComponent::WebGD;
use GD;
use POSIX;

use SeedViewer::SeedViewer qw( get_menu_metagenome get_settings_for_dataset is_public_metagenome );
use SeedViewer::MetagenomeAnalysis;
# use Number::Format;
 
1;

=pod

=head1 NAME

MetagenomeOverview - an instance of WebPage which gives overview information about a metagenome

=head1 DESCRIPTION

Overview page about a metagenome

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('Metagenome Overview');

  # get the metagenome id
  my $id = $self->application->cgi->param('metagenome') || '';

  # set up the menu
  &get_menu_metagenome($self->application->menu, $id);

  # sanity check on job
  if ($id) { 
    my $job;
    eval { $job = $self->app->data_handle('RAST')->Job->init({ genome_id => $id }); };
    unless ($job) {
      $self->app->error("Unable to retrieve the job for metagenome '$id'.");
      return 1;
    }
    $self->data('job', $job);
  }


  # init the metagenome database
  my $job = $self->data('job');
  my $mgdb = SeedViewer::MetagenomeAnalysis->new($self->data('job'));
  unless ($mgdb) {
      #
      # See if this job is a mgrast1 job
      #
      if (-f $job->directory() . "/proc/taxa.gg.allhits")
      {
          my $g = $job->genome_id();
          my $jid = $job->id();
          my $url = "http://metagenomics.nmpdr.org/v1/index.cgi?action=ShowOrganism&initial=1&genome=$g&job=$jid";
          $self->app->error("Unable to retrieve the analysis database for metagenome '$id'. <p>" .
                            "This job appears to have been processed in the MG-RAST Version 1 server. You may " .
                            "browse the job <a href='$url'>using that system</a>.");
      }
      else
      {
	  $self->app->error("Unable to retrieve the analysis database for metagenome '$id'.");
      }
      return 1;
  }
  $mgdb->query_load_from_cgi($self->app->cgi, $self->data('dataset'));
  $self->data('mgdb', $mgdb);
  


  # register components
  $self->application->register_component('Info', 'Info');
  $self->application->register_component('TabView', 'InfoContent');
  $self->application->register_component('Hover', 'Databases');
  
  &get_settings_for_dataset($self);
  return 1;
}

=pod 

=item * B<output> ()

Returns the html output of the page.

=cut

sub output {
  my ($self) = @_;

  # get metagenome id
  my $metagenome = $self->application->cgi->param('metagenome') || '';
  unless($metagenome) {
    $self->application->redirect('MetagenomeSelect');
    $self->application->add_message('info', 'Redirected from Metagenome Overview: No metagenome id given.');
    $self->application->do_redirect(); 
    die 'cgi_exit';
  }


  # get hover box
  my $hover = $self->application->component('Databases');
  $hover->add_tooltip( 'SEED', 'SEED' );
  $hover->add_tooltip( 'RDP', 'RDP' ); 
  $hover->add_tooltip( 'Greengenes', 'Greengenes' );
  


  # add tabview
  my $info_content = $self->application->component('InfoContent');
#  $info_content->height(125);
  $info_content->width(600);
  $info_content->add_tab('Overview', '<div style="padding-left: 5px; padding-right: 5px; text-align: justify;"><p>The metagenome overview page provides basic information and a summary regarding the selected metagenome. Information includes project name, project description, metagenome name and unique id as well as sequence length and percent GC statistics. Histograms of sequence length and GC content is also provided. In order to provide a brief overview of the taxonomic distribution, a table is provided with domain distribution for RNA and protein based analysis.<p><p>The Overview is accessible through the menu via<br>
» Metagenome » <a href="?page=MetagenomeOverview&metagenome='.$metagenome.'">Overview</a></p></div>');
  $info_content->add_tab('Metabolic Analysis', '<div style="padding-left: 5px; padding-right: 5px; text-align: justify;"><p><strong>Metabolic Reconstruction:</strong> MG-RAST provides a functional classification for this metagenome using SEED Subsystem Technology. It gives you detailed view which metabolic functions or activities may be present in your sample. Views are interactive and are in graphical (pie charts) and tabular form. You can modify the parameters of the calculated profile including e-value, p-value , percent identity and minimum alignment length. This will allow you to refine the analysis to suit the sequence characteristics of your sample.</p><p>KEGG maps are also available using the metabolic functions computed by MG-RAST. Comparative tools are also available.</p><p>Available through the menu via<br/>&raquo; Metagenome &raquo; <a href="?page=MetagenomeProfile&dataset='.$self->data('dataset_select_metabolic')->[0].'&metagenome='.$metagenome.'">Sequence Profile</a> (then select Metabolic Profile)<br>&raquo; Compare Metagenomes &raquo; <a href="?page=Kegg&organism='.$metagenome.'">KEGG Map</a></p></div>');
  $info_content->add_tab('Phylogenetic Analysis', '<div style="padding-left: 5px; padding-right: 5px; text-align: justify;"><strong>Phylogenetic Classification:</strong> We provide the taxonomic classification based on a number of different ribosomal RNA databases: <a href="http://greengenes.lbl.gov">GreenGenes</a>, <a href="http://rdp.cme.msu.edu/">RDP-II</a> and <a href="http://www.psb.ugent.be/rRNA">European ribosomal RNA database</a>. In addition we compute a taxonomic profile from the protein similarities found in our underlying SEED database. You can modify the parameters of the calculated profile including e-value, p-value , percent identity and minimum alignment length. This will allow you to refine the analysis to suit the sample and sequence characteristics of your metagenome. The SEED database provides an alternative way to identify taxonomies in the sample. Protein encoding genes are BLASTed against the SEED database and the taxonomy of the best hit is used to compile taxonomies of the sample.</p><p>Views are interactive and are in graphical (pie charts) and tabular form.</p><p>Available through the menu via<br/>&raquo; Metagenome &raquo; <a href="?page=MetagenomeProfile&dataset='.$self->data('dataset_select_metabolic')->[0].'&metagenome='.$metagenome.'">Sequence Profile</a> (then select Phylogenetic Profile)</p></div>');
  $info_content->add_tab('Compare', '<div style="padding-left: 5px; padding-right: 5px; text-align: justify;"><strong>Compare Metagenomes:</strong>The comparative analysis tools can be used to align multiple metagenomes along the different classifications, e.g. show relationships of certain subsystems in different metagenomic samples. Three tools are available to perform comparisons:</p><p><strong>Heatmaps</strong> allow for metabolic or phylogentic comparison of two or more metagenomes. Absolute or normalized values can be used as well as setting the number of groups allowed. You can also modify the parameters of the calculated profile including e-value, p-value , percent identity and minimum alignment length.</p><p><strong>Recruitment Plot</strong> compares the metabolism of the metagenome to a individual bacterial organism. Again, parameters can be modified, like e-value, p-value , percent identity and minimum alignment length. This an alpha release and the tool provides qualitative results in graphical form with option to zoom in.</p><p><strong>KEGG</strong> maps and tables are provided as an alternative view of the metabolic reconstruction of the metagenome. It allows you to compare with multiple metagenomes at different levels within the metabolic pathway hierarchy. Absolute counts and percentages are provided.</p><p>Available through the menu via<br/>&raquo; Compare Metagenomes &raquo; <a href="?page=MetagenomeComparison&dataset='.$self->data('dataset_select_metabolic')->[0].'&metagenome='.$metagenome.'">Heatmap Comparison</a><br>&raquo; Compare Metagenomes &raquo; <a href="?page=MetagenomeRecruitmentPlot&metagenome='.$metagenome.'">Recruitment Plot</a><br>&raquo; Compare Metagenomes &raquo; <a href="?page=Kegg&organism='.$metagenome.'">KEGG Map</a></p></div>');

  my $job = $self->data('job');

  # write title
  my $html = "<span style='font-size: 1.6em'><b>Metagenome Overview</b></span>";
  $html .= "<span style='font-size: 1.6em'><b> for ".$job->genome_name." (".$job->genome_id.")</b></span>" if($job);
 
  # get sequence data
  my $seqs_num = $job->metaxml->get_metadata('preprocess.count_proc.num_seqs');
  my $seqs_total = $job->metaxml->get_metadata('preprocess.count_proc.total');
  my $seqlen_min = $job->metaxml->get_metadata('preprocess.count_proc.shortest_len');
  my $seqlen_max = $job->metaxml->get_metadata('preprocess.count_proc.longest_len');
  my $seqlen_avg = $job->metaxml->get_metadata('preprocess.count_proc.average'); 
  my $gc_avg     = $job->metaxml->get_metadata('preprocess.count_proc.gc_average');
 
  my $project_name = $job->project || $job->genome_name;
  my $genome_name = $job->genome_name || $job->project;
  my $project_desc = $job->metaxml->get_metadata('project.description') || 'No description available.';
  my $timestamp = $job->metaxml->get_metadata('upload.timestamp') || '';

#  my $seqs_num = $job->metaxml->get_metadata('preprocess.count_proc.num_seqs');
  unless ( $self->data('mgdb')->query_evalue ){
    $self->data('mgdb')->query_evalue('1e-5');
  }

  my $seqs_in_evidence        = $self->data('mgdb')->get_hits_count( $self->data('dataset') );
  my $seqs_matched_genomes    = $self->data('mgdb')->get_hits_count( 'SEED:seed_genome_tax' ); 

  # set alignment length for greengenes don't use any for subsystems
  unless ( $self->data('mgdb')->query_align_len ){
    $self->data('mgdb')->query_align_len('50');
  }
  my $seqs_matched_greengenes = $self->data('mgdb')->get_hits_count( 'greengenes:gg_taxonomy' );

  my $percent_matching_subsystem =  ( $seqs_in_evidence * 100 ) /  $seqs_num ;
  my $percent_matching_genomes   =  ( $seqs_matched_genomes * 100 ) /  $seqs_num ; 
  my $percent_matching_greengenes=  ( $seqs_matched_greengenes * 100 ) /  $seqs_num ;

  my $prj_overview = "";

  $prj_overview .= "<p>The $genome_name data set contains ".$self->format_number($seqs_num)." contigs totaling ".$self->format_number($seqs_total)." basepairs with an average fragment length of ".$self->format_number( sprintf("%.2f",$seqlen_avg) )." (you can <a href=\"rast.cgi?page=DownloadMetagenome&metagenome=".$job->genome_id."\">download</a> the entire data set). ";

  $prj_overview .= "A total of ".$self->format_number( $seqs_in_evidence )." sequences (".sprintf("%.2f",$percent_matching_subsystem)."%) could be matched to proteins in <a href=\"http://www.theseed.org/wiki/Glossary#Subsystem\" target=\"_blank\">SEED subsystems</a> (using an e-value cut-off of ". $self->data('mgdb')->query_evalue."), ";
  $prj_overview .= "you can explore metabolic reconstructions based on different parameters on the <a href=\"?page=MetagenomeProfile&dataset=SEED:subsystem_tax&metagenome=".$job->genome_id."\">Metabolic Reconstruction Page</a>. Based on ".$self->format_number( $seqs_matched_genomes )." hits against the SEED protein non-redundant database (".sprintf("%.2f",$percent_matching_genomes)." % of the fragments) and on the  ".$self->format_number( $seqs_matched_greengenes )." hits against the ribosomal RNA database <a href=\"http://greengenes.lbl.gov\">Greengenes</a> (".sprintf("%.2f",$percent_matching_greengenes)."%) we computed the following table (using an e-value cut-off of ".$self->data('mgdb')->query_evalue." and a minimum alignment length of  ".$self->data('mgdb')->query_align_len."bp).";
  $prj_overview .= "</p>";
  
  my $green = $self->data('mgdb')->get_group_counts( "greengenes:gg_taxonomy" , "tax_group_1" );
  my $seed  = $self->data('mgdb')->get_group_counts( "SEED:seed_genome_tax" , "tax_group_1" );
  my $mapping = $self->data('mgdb')->get_key2taxa_mapping ;
  
  my $results = {};
  foreach my $var (@$green){
    $results->{ $self->data('mgdb')->key2taxa( $var->[0] ) }->{greengene} = $var->[1] || 0;
  }

  foreach my $var (@$seed){
    $results->{ $self->data('mgdb')->key2taxa( $var->[0] ) }->{seed} = $var->[1] || 0;
  }
  
  my $total_seed              = 0;
  my $total_percent_seed      = 0;
  my $total_greengene         = 0;
  my $total_percent_greengene = 0;

  my $hover = $self->application->component('Databases');
  $hover->add_tooltip( 'SEED', 'SEED' );
  $hover->add_tooltip( 'RDP', 'RDP' ); 
  $html .= $hover->output();

  my $prj_overview_table = "";

  $prj_overview_table .="<table align=\"center\"><tr><th></th><th colspan=2 onmouseover='hover(event, \"SEED\", " . $hover->id . ");' style='cursor:default;' >Protein based</th><th colspan=2 onmouseover='hover(event, \"RDP\", " . $hover->id . ");' style='cursor:default;'><a>16s&nbsp;based</th></tr>";

  # get data for statistics table
  my @categories = ( "Archaea" , "Bacteria", "Eukaryota" , "Virus" );

  foreach my $key (sort { $a cmp $b} @categories){
    next unless( $key =~/^Bac|^Arch|^Euk|^Vir/);

    unless (ref $results->{ $key }) {
      $results->{ $key }->{ seed } = 0;
      $results->{ $key }->{ greengene } = 0;
     }

    my $seed_percent = 0;
    my $green_percent = 0;

    $seed_percent  = 100 *  $results->{ $key }->{ seed }  / $seqs_matched_genomes if ($seqs_matched_genomes);
    $green_percent = 100 *  $results->{ $key }->{ greengene } / $seqs_matched_greengenes if ( $seqs_matched_greengenes );

    $total_seed      = $total_seed      +  ($results->{ $key }->{ seed }      || 0 );
    $total_greengene = $total_greengene +  ($results->{ $key }->{ greengene } || 0 );

    $total_percent_seed      = $total_percent_seed      + ( $seed_percent  || 0 );
    $total_percent_greengene = $total_percent_greengene + ( $green_percent || 0 );
    
    $prj_overview_table .= "<tr><th>$key</th><td align=\"right\">". sprintf("%.2f",$seed_percent) ."%</td><td align=\"right\"> (". ($results->{ $key }->{ seed } || "0" ) .")</td><td align=\"right\">".sprintf("%.2f", $green_percent) ."% </td><td align=\"right\">(".($results->{ $key }->{ greengene } || "0" ) . ")</td></tr>";
  }
  my $other_percent_seed = 100 - $total_percent_seed;
  my $other_seed         = $seqs_matched_genomes - $total_seed;
  my $other_percent_greengene = 100 - $total_percent_greengene;
  my $other_greengene         = $seqs_matched_greengenes - $total_greengene;

  $prj_overview_table .= "<tr><th>Other</th><td align='right'>".sprintf("%.2f", $other_percent_seed)."%</td><td align='right'>($other_seed)</td><td align='right'>".sprintf("%.2f",$other_percent_greengene)."%</td><td align='right'>(".$other_greengene.")</td></tr>";
  $prj_overview_table .= "</table>";
 
  $prj_overview .="<p>The <a href=\"?page=MetagenomeProfile&dataset=rdp:16s_taxonomy&metagenome=".$job->genome_id."\">Phylogenetic Reconstruction</a> page will allow you to view taxonomic distributions in greater detail, change parameters and incorporate additional databases into your analysis.</p>";
 $prj_overview .="<p>The <a href='http://www.theseed.org/www.theseed.org/wiki/index.php?title=MG_RAST_v2.0_tutorial'>MG-RAST manual</a> has more pointers for working with the system.</p>";
  
  # add general organism data and info box
  $html .= "<table><tr><td style='height:15px;'></td></tr><tr><td style='padding-right: 50px;'>";

  $html .= "<table>";
  $html .= "<tr><th>Project:</th><td>".$project_name."</td></tr>";
  $html .= "<tr><th>Metagenome</th><td>".$job->genome_name."</td></tr>";
  $html .= "<tr><th>Metagenome ID:</th><td>".$job->genome_id."</td></tr>";
  $html .= "<tr><th>Description:</th><td>".$project_desc."</td></tr>";
  $html .= "<tr><th>Uploaded on:</th><td>".localtime($timestamp)."</td></tr>";
  $html .= "<tr><th>Total no. of sequences</th><td>".$self->format_number($seqs_num)."</td></tr>";
  $html .= "<tr><th>Total sequence size</th><td>".$self->format_number($seqs_total)."</td></tr>";
  $html .= "<tr><th>Shortest sequence length</th><td>$seqlen_min</td></tr>";
  $html .= "<tr><th>Longest sequence length</th><td>$seqlen_max</td></tr>";
  $html .= "<tr><th>Average sequence length</th><td>".sprintf("%.2f",$seqlen_avg)."</td></tr>"; 
  $html .= "<tr><th>Average GC content</th><td>".$gc_avg."%</td></tr>" if ($gc_avg);
  $html .= "</table>";

  $html .= "</td><td>".$info_content->output()."</td></tr></table>";
  $html .= "<h3>Summary and Statistics</h3>";
  $html .= "<table><tr><td align='justify'>$prj_overview</td><td>$prj_overview_table</td></tr>";
  $html .= "</table>";

  # check if graphs need to be computed
  $self->check_image_files;

  
  # length histogram
  $html .= "<table><tr><td style='height:20px;'></td></tr><tr><td>";
  $html .= "<h3>Sequence length histogram</h3>";
  $html .= "<p>The histogram below shows the distribution of sequence lengths for this metagenome. Each bar represents the number of sequences for a certain length range.</p>";

  # gc distribution
  $html .= "</td><td style='width:10px;'></td><td><h3>Sequence GC Distribution</h3>";
  $html .= "<p>The graph below displays the distribution of the GC percentage for the metagenome sequences. Each bar represents the number of sequences in that GC percentage range.</p></td>";
  $html .= "<tr><td>";
  $html .= "<div>\n".$self->read_png($self->data('job')->analysis_dir.'/lengths_histogram.png')."\n</div></td>\n";
  $html .= "<td style='width:10px;'></td>";
  $html .= "<td><div>\n".$self->read_png($self->data('job')->analysis_dir.'/gc_histogram.png')."\n</div></td>\n";
  
  $html .="</tr><table>";


  # meta data block
  my $has_metadata = 0;
  $html .= "<h3>Additional information on this metagenome</h3>\n";  
  $html .= "<table>";
  my @keys = $self->data('job')->metaxml->get_metadata_keys;
  foreach my $k (@keys) {
    if ($k =~ /optional_info\.(.+)/) {
      my $label = $1;
      $label =~ s/_/ /g;
      my $value = $self->data('job')->metaxml->get_metadata($k) || '';
      if (ref($value) eq 'ARRAY') {
	  $html .= "<tr><th>".$value->[0]."</th><td>".($value->[1]||'')."</td></tr>";
      }
      else {
	  $html .= "<tr><th>$label</th><td>$value</td></tr>";
      }
      $has_metadata++;
    }
  }
  unless($has_metadata) {
      $html .= "<tr><td><em>No additional information found.</em></td></tr>";
  }

  $html .= "</table>";

  return $html;

}

=pod

=item * B<read_png> (I<png_filename>)

Small helper method that reads a png from disk and embeds it as WebGD image.

=cut

sub read_png {
  my ($self, $file) = @_;

  my $img = WebGD->newFromPng($file);
  if($img) {
    return '<img src="'.$img->image_src.'">';
  }
  else {
    return '<p><em>Not yet computed.</em></p>';
  }

}


=pod 

=item * B<check_image_files> ()

Checks if the graph images shown on the overview page exist. If not they are computed 
and stored in the job analysis directory.

=cut

sub check_image_files {
  my ($self) = @_;

  my $job = $self->data('job');
  my $fn_len = $job->analysis_dir.'/lengths_histogram.png';
  my $fn_gc = $job->analysis_dir.'/gc_histogram.png';
  
  # check if already computed
  unless (-f $fn_len and -f $fn_gc) {
   
    # sequences files
    my $genome_id = $job->genome_id;
    my $sequences = $job->directory."/rp/$genome_id/contigs";
    -f $sequences || die "Unable to find sequences file $sequences.";

    # check if basic data is set in metaxml
    my $total = $job->metaxml->get_metadata('preprocess.count_raw.total') ||
      die "Unable to read preprocessing data 'count_raw.total' from metaxml.";
    my $min = $job->metaxml->get_metadata('preprocess.count_raw.shortest_len') ||
      die "Unable to read preprocessing data 'count_raw.shortest_len' from metaxml.";
    my $max = $job->metaxml->get_metadata('preprocess.count_raw.longest_len') ||
      die "Unable to read preprocessing data 'count_raw.longest_len' from metaxml.";
    my $avg = $job->metaxml->get_metadata('preprocess.count_raw.average') ||
      die "Unable to read preprocessing data 'count_raw.average' from metaxml.";
    
    # read sequence data
    my $lengths = [];
    my $gcs = [];
    
    # open file and read sequences
    open (FILE, "<$sequences")
      or die "Unable to open file: $sequences";
    
    while (my ($id, $seq) = &FIG::read_fasta_record(\*FILE)) {
      
      # sequence stats
      $$seq = uc($$seq);
      my $len = length($$seq);
      my $gc = $$seq =~ tr/GC/GC/;
      push @$lengths, $len;
      push @$gcs, sprintf("%.2f", 100/$len*$gc);
      
    }
    
    # generate histograms
    $self->create_length_histogram($lengths, $min, $max, $fn_len);
    $self->create_gc_histogram($gcs, $fn_gc);
    
  }

  return 1;

}


=pod 

=item * B<create_length_histogram> ()

Creates the length histogram of the specified parameters and writes it the file.

=cut

sub create_length_histogram {
  my ($self, $lengths, $min, $max, $file) = @_;

  # set histogram sizes
  my $width = 600;
  my $height = 250;
  my $padding_bottom = GD::gdSmallFont->height*2+2;
  my $bar_width = 17;
  my $bar_spacing = 2;
  my $font_width = GD::gdSmallFont->width();

  # set bin parameter and compute lengths binning
  my $bins = [];
  my $bin_count = int( $width / ($bar_width+$bar_spacing) );
  my $bin_range = ceil( ($max-$min) / $bin_count ) || 1;

  my $bin_max = 0;
  foreach my $l (@$lengths) {
    my $bin_no = int(($l-$min)/$bin_range);
    $bins->[$bin_no] ++;
    $bin_max = $bins->[$bin_no] unless ($bin_max > $bins->[$bin_no]);
  }

  # create the image
  my $img = GD::Image->new($width, $height+$padding_bottom);
  my $white = $img->colorResolve(255,255,255);
  my $black = $img->colorResolve(0,0,0);
  my $bar   = $img->colorResolve(70,130,180);
  my $x = 0; 
  my $y = $height-1;
  my $bar_height_mod = $height/$bin_max;
  
  for (my $b=0; $b < scalar(@$bins); $b++) {
    my $start = $min+$b*$bin_range;
    my $stop = $start+$bin_range-1;
    my $count = $bins->[$b] || 0;
    my $y2 = $y-($count*$bar_height_mod);
    
    $img->filledRectangle( $x, $y2, $x+$bar_width, $y, $bar );
    $img->string(GD::gdSmallFont, $x, $y+2+($b%2*10), $start, $black);
    my $text_y = $y2+2+length($count)*($font_width+1);
    $text_y = $y2-4 if ($text_y+length($count)*($font_width+1) > $height);
    $img->stringUp(GD::gdSmallFont,$x+2, $text_y, $count, $black) if ($count);
    $x += $bar_width+$bar_spacing;
  }

  $img->line( 0, $height-1, $width, $height-1, $black );

  # write to file
  open (PNG, ">$file") || die "Unable to write png file $file: $@";
  binmode PNG;
  print PNG $img->png;
  close (PNG);

  return 1;

}


=pod 

=item * B<create_gc_histogram> ()

Creates the gc content histogram of the specified parameters and writes it the file.

=cut

sub create_gc_histogram {
  my ($self, $gc, $file) = @_;
  
  # set histogram sizes
  my $height = 250;
  my $padding_bottom = GD::gdSmallFont->height*2+2;
  my $bar_width = 17;
  my $bar_spacing = 2;
  my $font_width = GD::gdSmallFont->width();

  # set bin parameter and compute binning
  my $bins = [];
  my $bin_range = 5;
  my $bin_count = ceil(100/$bin_range);
  my $width = $bin_count*($bar_width+$bar_spacing)+20;

  my $bin_max = 0;
  foreach my $p (@$gc) {
    my $bin_no = int($p/$bin_range);
    $bins->[$bin_no] ++;
    $bin_max = $bins->[$bin_no] unless ($bin_max > $bins->[$bin_no]);
  }

  # create the image
  my $img = GD::Image->new($width, $height+$padding_bottom);
  my $white = $img->colorResolve(255,255,255);
  my $black = $img->colorResolve(0,0,0);
  my $bar   = $img->colorResolve(70,130,180);
  my $x = 0; 
  my $y = $height-1;
  my $bar_height_mod = $height/$bin_max;

  for (my $b=0; $b <= $bin_count; $b++) {
    my $start = $b*$bin_range;
    my $stop = $start+$bin_range-1;
    my $count = $bins->[$b] || 0;
    my $y2 = $y-($count*$bar_height_mod);
    
    $img->filledRectangle( $x, $y2, $x+$bar_width, $y, $bar );
    $img->string(GD::gdSmallFont, $x, $y+2+($b%2*10), $start, $black);
    my $text_y = $y2+2+length($count)*($font_width+1);
    $text_y = $y2-4 if ($text_y+length($count)*($font_width+1) > $height);
    $img->stringUp(GD::gdSmallFont,$x+2, $text_y, $count, $black) if ($count);
    $x += $bar_width+$bar_spacing;
  }

  $img->line( 0, $height-1, $width, $height-1, $black );
  
  # write to file
  open (PNG, ">$file") || die "Unable to write png file $file: $@";
  binmode PNG;
  print PNG $img->png;
  close (PNG);

}


=pod

=item * B<required_rights>()

Returns a reference to the array of required rights

=cut

sub required_rights {
  my ($self) = @_;
  
  my $rights = [];

  my $mg  = $self->application->cgi->param('metagenome') || '';
  my $dbm = $self->application->dbmaster;

  if (&is_public_metagenome($dbm, $mg)) {
    return $rights;
  }

  if ($mg and scalar(@{$dbm->Rights->get_objects({ name => 'view',
						   data_type => 'genome',
						   data_id => $mg, 
						 })
		     })
     ) {
    push @$rights, [ 'view', 'genome', $mg ];
  }
  
  return $rights;
}


sub format_number{
  my ($self , $number) = @_;

  $number = $self unless (ref $self);

  my @reversed;
  my $counter = 3;
  
  my ($int , $float) = split( /\./ , $number); 
  my @digits = split "", $int;
  
  while ( @digits ){
    $counter--;
    my $dig = pop @digits ;
    push @reversed , $dig ;
    unless ($counter){
      push @reversed , "," if ( @digits );
      $counter = 3;
    }  
  }
  
  $int = reverse @reversed;
  $int = $int.".".$float if $float;
  
  return $int;
}

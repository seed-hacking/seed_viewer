package SeedViewer::WebPage::MetagenomeRecruitmentPlot;

use base qw( WebPage );

use strict;
use warnings;

use WebConfig;
use URI::Escape;

use FIG;
use GD;
use WebColors;
use WebComponent::WebGD;

use SeedViewer::MetagenomeAnalysis;
use SeedViewer::SeedViewer qw( get_menu_metagenome get_settings_for_dataset is_public_metagenome );

1;


=pod

=head1 NAME

MetagenomeRecruitmentPlot 

=head1 DESCRIPTION


=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('Recruitment Plot');

  # register components
  $self->application->register_component('Hover', 'Tooltips');
  $self->application->register_component('Hover', 'Legend_Tooltips');
  $self->application->register_component('Ajax', 'DisplayPlot');
  $self->application->register_component('FilterSelect', 'OrganismSelect');

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
    
    # init the metagenome database
    my $mgdb = SeedViewer::MetagenomeAnalysis->new($job);
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
    #
    # hardcoded badness
    #
    unless($self->app->cgi->param('evalue')){
      $self->app->cgi->param('evalue', '0.001');
    }
    $mgdb->query_load_from_cgi($self->app->cgi, "SEED:seed_genome_tax");
    $self->data('mgdb', $mgdb);
  }

  return 1;
}

=item * B<output> ()

Returns the html output of the page.

=cut

sub output {
  my ($self) = @_;

  # init some variables
  my $error = '';
  my $job = $self->data('job');
  my $cgi = $self->application->cgi;
  my $fig = new FIG;
  my $application = $self->application;
  my $html = "";

  # get metagenome id
  my $metagenome = $self->application->cgi->param('metagenome') || '';

  unless($metagenome) {
    $error = "<p><em>No metagenome id given.</em></p>";
    $self->application->add_message('warning', 'No metagenome id given.');
  }

  # put metagenome name together
  my $mg_name = ($job) ? $job->genome_name." (".$job->genome_id.")" : '';

  # reference genome
  my $ref_genome = $cgi->param('ref_genome') || ''; 
  unless($ref_genome){
    $html = "<p><span style='font-size: 1.6em'><b>Recruitment Plot from $mg_name</b></span></p><p style='width: 600px;'>Please select a reference genome below. The list of organisms is ordered by the number metagenome fragments that map to the organism as shown in parentheses. Note a genome will not be shown in this list unless it has at least one hit.</p>";

    # get a rast master
    my $rast = $application->data_handle('RAST');

    # create the select organism component
    my $organism_select_component = $application->component('OrganismSelect');
    
    #get genomes hit
    my $data = $self->data('mgdb')->get_taxa_counts("SEED:seed_genome_tax");
    my $genome_list = [];
    
    foreach (@$data){
      my ($taxonomy, $count) = @$_;
      my $taxa = $self->data('mgdb')->split_taxstr($taxonomy);
      my $organism = $self->data('mgdb')->key2taxa($taxa->[scalar(@$taxa)-1]);
      my $genome_id = $self->data('mgdb')->get_tax2genomeid($taxonomy);

      push(@$genome_list, [$genome_id, $organism." (".$count.")", $count]);
    }

    my @sorted_genome_list = sort {$b->[2] <=> $a->[2]} @$genome_list;
    my $org_values = [];
    my $org_labels = [];
    foreach my $line (@sorted_genome_list) {
      push(@$org_values, $line->[0]);
      push(@$org_labels, $line->[1]);
    }
    $organism_select_component->values( $org_values );
    $organism_select_component->labels( $org_labels );
    $organism_select_component->name('ref_genome');
    $organism_select_component->width(600);
    
    $html .= $self->start_form('select_comparison_organism_form', { 'metagenome' => $metagenome } );
    $html .= "<div id='org_select'>".$organism_select_component->output() . "<input type='submit' value='select'>" . $self->end_form()."</div>";
 
    return $html;
  } 

  my ($ref_genome_name, $ref_genome_length, $ref_genome_num_PEGs, $ref_genome_num_RNAs, $ref_genome_tax) = $fig->get_genome_stats($ref_genome);  

  #check if contig is specified
  my $use_contig = $cgi->param('contig') || ''; 
  
  # abort if error
  if ($error) {
    return "<h2>An error has occured:</h2>\n".$error;
  }

  #Ajax to html
  $html = $application->component('DisplayPlot')->output();

  # write title + intro
  $html .= "<span style='font-size: 1.6em'><b>Recruitment Plot </b></span>".(($mg_name) ? "<span style='font-size: 1.6em'><b>from $mg_name</b></span>" : '')."</h1>\n";

  # summarize parameters
  $html .= "<h3>Select filter options</h3>";

  #draw legendary legend
  my $legend = new WebGD(400, 100);
  my $white = $legend->colorAllocate(255,255,255);
  my $black = $legend->colorAllocate(0,0,0);
  my $alt_black = $legend->colorAllocate(59,59,59);
  my $gray = $legend->colorAllocate(211,211,211);
  my $alt_gray = $legend->colorAllocate(169,169,169);
  my $border_green = $legend->colorAllocate(93,166,104);
  my $background_green = $legend->colorAllocate(134,211,146);
  my $blue = $legend->colorAllocate(104,143,197);
  my $alt_blue = $legend->colorAllocate(100,149,237);

  my $colors;
  foreach(@{WebColors::get_palette('gradient')}){
    push(@$colors, $legend->colorAllocate($_->[0], $_->[1], $_->[2]));
  }

  $legend->transparent($white);
  $legend->interlaced('true');
  
  my $increment = 40;
  my $prev_ev = 0;
  my $x1 = 0;
  my $x2 = $x1+$increment;
  my $y1 = 15;
  my $y2 = 30;
  my $tooltip = $application->component('Legend_Tooltips');

  $legend->string(gdSmallFont, 1, 0, "Fragment e-value coloring:", $black);

  my $image_map = '<map name="legendmap">';
  foreach my $ev (@{$self->get_evalue_ranges()}){
    my ($color) = $self->get_evalue_color_key($ev);

    $legend->filledRectangle($x1, $y1, $x2, $y2, $colors->[$color]);
    $legend->rectangle($x1, $y1, $x2, $y2, $white);
    $legend->string(gdSmallFont, ($x1 + 5), ($y1 + 1), $ev, $white);
    
    my $ev_range = ($prev_ev) ? ($prev_ev . " <=> " . $ev) : ($ev . " <"); 
    $prev_ev = $ev;
    $tooltip->add_tooltip('ev_' . $x1, "<table><tr><th>e-value range</th></tr><tr><td>" . $ev_range. "</td></tr></table>");
    $image_map .= '<area shape="rect" coords="' . join(",", ($x1, $y1, $x2, $y2)). qq~" onmouseover='hover(event, "ev_~ .$x1.qq~", "~.$tooltip->id.qq~");'/>~;

    $x1 +=$increment;
    $x2 +=$increment;
  }

  $legend->string(gdSmallFont, 1, 35, "PEG (fragment mapped / no fragments mapped):", $black);
  $legend->filledRectangle(1, 50, 101, 53, $black);
  $legend->rectangle(1, 50, 100, 53, $alt_black);
  $legend->filledRectangle(103, 50, 203, 53, $gray);
  $legend->rectangle(103, 50, 203, 53, $alt_gray);

  $legend->string(gdSmallFont, 1, 65, "Contig (alternating coloring):", $black);
  $legend->filledRectangle(1, 80, 101, 86, $background_green);
  $legend->rectangle(1, 80, 100, 86, $border_green);
  $legend->filledRectangle(103, 80, 203, 86, $blue);
  $legend->rectangle(103, 80, 203, 86, $alt_blue);

  $html .= '<div><div style="float: left; padding: 0px 210px 0px 0px;"><table>';

  my @pvalue;
  for( my $i = 200; $i >= 20; $i-=10 ){
    push @pvalue, $i;
  }

  my @identity;
  for (my $i=100; $i>=40; $i-=2 ){
    push @identity, $i;
  }

  my ($alen_min, $alen_max) = $self->data('mgdb')->get_align_len_range("SEED:seed_genome_tax");
  my @alen;
  my $len50 = 0;
  for( my $i = $alen_max; $i > $alen_min; $i-=10 ){
    push @alen, $i;
    $len50 = 1 if ($i == 50);
  }
  push @alen, $alen_min;
  push @alen, 50 unless ($len50);
  @alen = sort { $a <=> $b } @alen;

  $html .= $self->start_form('mg_stats', { metagenome => $metagenome, ref_genome => $ref_genome, offset=>25, width=>1000, image_center=>500, prev_zoom=>5, zoom_level=>5, prev_start=>0});
  $html .= "<tr><th>Maximum e-value</th><td>" . 
    $cgi->popup_menu( -name => 'evalue', -default => $cgi->param("evalue") || 1e-3, 
		      -values => [1e-3, 1e-5, 1e-7, 1e-10, 1e-15, 1e-20, 1e-25, 1e-30, 1e-40, 1e-50]) . "</td></tr>";
  $html .= "<tr><th>Minimum p-value</th><td>".
    $cgi->popup_menu( -name => 'bitscore', 
		      -default => $cgi->param("bitscore") || '', -values => ['', @pvalue]);
  $html .= " <em>leave blank for all</em></td></tr>";

  $html .= "<tr><th>Minimum percent identity</th><td>". 
    $cgi->popup_menu( -name => 'identity', -default => $cgi->param('identity') || '',
		      -values => ['', @identity ]);
  $html .= " <em>leave blank for all</em></td></tr>";

  $html .= "<tr><th>Minimum alignment length</th><td>". 
    $cgi->popup_menu( -name => 'align_len', -default => $cgi->param('align_len') || '',
		      -values => [ '', @alen ]);
  $html .= " <em>leave blank for all</em></td></tr>";

  $html .= "<tr><td style='height:5px;'></td></tr><tr><td colspan='2'>".$cgi->submit(-value=>'Re-compute results', -style=>'height:35px;width:150px;font-size:10pt;').
    " &laquo; <a href='".$self->url."metagenome=$metagenome&ref_genome=$ref_genome'>click here to reset</a>  &raquo;</td></tr>";
  $html .= "</table></div><div style='height: 150px;'>".$tooltip->output."<img style='border: none;' src='" . $legend->image_src() . "' usemap='#legendmap'/> ".$image_map."</map></div>";
  $html .= $self->start_form();
 
  $html .= "<div id='plot_div'></div>";
  $html .= "<img src='./Html/clear.gif' onload='execute_ajax(\"loadPlot\", \"plot_div\", \"mg_stats\");'>";

  return $html;

}

sub loadPlot {
  my ($self) = @_;
  
  # init some variables
  my $cgi = $self->application->cgi;
  my $fig = new FIG;
  my $application = $self->application;
  my $html = "";
  my $ref_genome = $cgi->param('ref_genome');
  my $metagenome = $cgi->param('metagenome');
  my $width = $cgi->param('width') || 1000;
  my $height = $cgi->param('height') || 175;
  my $offset = 25; 
  my $image_center = $cgi->param('image_center') || ($width-($offset * 2))/2;

  # some reference genome details
  my ($ref_genome_name, $ref_genome_length, $ref_genome_num_PEGs, $ref_genome_num_RNAs, $ref_genome_tax) = $fig->get_genome_stats($ref_genome);

  #query database. returns @$ where rows are: fragment_id, peg_id, beginning, end, e-value
  my $query = $self->data('mgdb')->get_recruitment_plot_data($ref_genome);

  #if empty quit
  if(scalar @$query == 0){
    return "<p>No fragments found for <b>" . $ref_genome_name ." (" . $ref_genome . ")</b></p><p>» <a href='?page=MetagenomeRecruitmentPlot&metagenome=" . $metagenome . "'>click to select new reference genome</a></p>";
  }
  
  my %data;
  my %pegs_hit;
  foreach my $row (@$query){
    my $peg_name_start_stop = $fig->feature_location($row->[1]);
    next unless $peg_name_start_stop;
    my $contig_name = $fig->contig_of($peg_name_start_stop);

    unless(exists $data{$contig_name}->{Frag}){
      $data{$contig_name}->{Frag} = [];
    }

    unless(exists $data{$contig_name}->{Peg}){
      $data{$contig_name}->{Peg} = [];
    }


    if($peg_name_start_stop =~ /(\d+)_(\d+)$/){      
      my($peg_start,$peg_end, $peg_strand)=($1, $2, 0);
      if($peg_end < $peg_start){
	my $tmp;
	$tmp = $peg_start;
	$peg_start = $peg_end;
	$peg_end = $tmp;
	$peg_strand = 1;
      }
      unless(defined $pegs_hit{$row->[1]}){
	push(@{$data{$contig_name}->{Peg}}, [$row->[1], $peg_start, $peg_end, 1, $peg_strand]);
	$pegs_hit{$row->[1]}=1;
      }
      
      my($frag_start,$frag_end)=($row->[2], $row->[3]);
      push(@{$data{$contig_name}->{Frag}}, [$row->[0], ($frag_start + $peg_start), ($frag_end + $peg_start), $row->[4], $peg_strand]);
    }
  }

  my $total_ln = 0;
  $ref_genome_num_PEGs = 0;  
  foreach my $contig_name (keys %data){
    $data{$contig_name}->{Length} = $fig->contig_ln($ref_genome, $contig_name);
    $total_ln += ($data{$contig_name}->{Length} || 0);

    my $additional_pegs = $fig->all_features_detailed_fast($ref_genome, undef, undef, $contig_name);
    $ref_genome_num_PEGs += scalar @$additional_pegs; 
    foreach my $features (@$additional_pegs){
      if($features->[3] eq "peg"){
	next if defined $pegs_hit{$features->[0]};
	my ($peg_start, $peg_end, $peg_strand) = (undef, undef, 0);
	if($features->[1] =~ /(\d+)_(\d+)$/){
	  $peg_start = $1;
	  $peg_end = $2;
	}
	if($peg_end < $peg_start){
	  my $tmp;
	  $tmp = $peg_start;
	  $peg_start = $peg_end;
	  $peg_end = $tmp;
	  $peg_strand = 1;
	}
	push(@{$data{$contig_name}->{Peg}}, [$features->[0], $peg_start, $peg_end, 0, $peg_strand]);
      }
    }
  }

  my ($display_region, $region_start,  $region_end, $scale);

  $display_region = $total_ln;
  $region_start = 0;
  $region_end = $total_ln;
 
  my $center = $height / 2;
  my $image = new WebGD($width, $height);
  my $image_map = '<map name="plotmap">';

  $scale = (($total_ln) / ($width-($offset * 2)));
 
  my $white = $image->colorAllocate(255,255,255);
  my $black = $image->colorAllocate(0,0,0);
  my $alt_black = $image->colorAllocate(59,59,59);
  my $gray = $image->colorAllocate(211,211,211);
  my $alt_gray = $image->colorAllocate(169,169,169);
  my $blue = $image->colorAllocate(104,143,197);
  my $alt_blue = $image->colorAllocate(100,149,237);
  my $border_green = $image->colorAllocate(93,166,104);
  my $background_green = $image->colorAllocate(134,211,146);
  my $tooltip = $application->component('Tooltips');

  my $colors;
  foreach(@{WebColors::get_palette('gradient')}){
    push(@$colors, $image->colorAllocate($_->[0], $_->[1], $_->[2]));
  }
 
  $image->transparent($white);
  $image->interlaced('true');
  
  #left
  $image->rectangle($offset-1,$center-10,$offset-1, $center+10,$black);
  $image->string(gdSmallFont, ($offset-(5*(length(int($region_start))/2))), $center+15, int($region_start), $black);

  #right
  $image->rectangle($width-$offset+1, $center-10, $width-$offset+1, $center+10,$black);
  $image->string(gdSmallFont, $width-($offset+(5*(length(int($region_end))/2))), $center+15, int($region_end), $black);

  #draw 
  my $y1 = $center-3;
  my $y2 = $center+3;
  my @contig_colors = ([$border_green, $background_green], [$blue, $alt_blue]);
  my $color_flag = 0;

  my $bp_coverage = 0;
  my $num_frag = 0;

  my $contig_start = $offset;
  foreach my $contig (keys %data){ 
    my ($x1, $x2);
    
    $x1 = $contig_start;
    $x2 = $contig_start + (($data{$contig}->{Length} || 1) / $scale);

    $image->filledRectangle($x1, $y1 , $x2, $y2, $contig_colors[$color_flag]->[1]);
    $image->rectangle($x1, $y1 , $x2, $y2, $contig_colors[$color_flag]->[0]);
    
    my $tooltip_text = "<table><tr><th colspan=2><b>Contig</b></th></tr><tr><td><b>ID</b></td>" . $contig . "<td></tr>" . 
      "<tr><td><b>Organism</b></td><td>" . $ref_genome . "</td></tr>".
	"<tr><td><b>Length</b></td><td>" . $data{$contig}->{Length} . "</td></tr></table>";
    $tooltip->add_tooltip('tooltip_' . $contig, $tooltip_text);
    $image_map .= '<area shape="rect" coords="' . join(",", ($x1, $y1, $x2, $y2)) . '" href="?page=MetagenomeRecruitmentPlot&metagenome=' . $metagenome . '&ref_genome=' . $ref_genome . '&contig=' . $contig . qq~" onmouseover='hover(event, "tooltip_~ . $contig .qq~", "~.$tooltip->id. qq~");'/>~;

    foreach my $peg (sort {$a->[3] <=> $b->[3]} @{$data{$contig}->{Peg}}){
      my ($x1, $x2, $y1, $y2);
      
      $x1 = $contig_start + ($peg->[1] / $scale);
      $x2 = $contig_start + ($peg->[2] / $scale);
            
      unless($peg->[4]){
	$y1 = $center-8;
	$y2 = $center-5;
      } else {
	$y1 = $center+5;
	$y2 = $center+8;
      }
      
      my($color, $alt_color);
      if($peg->[3]){
	$color = $black;
	$alt_color = $alt_black;
      } else {
	$color = $gray;
	$alt_color = $alt_gray;
      }
      
      $image->filledRectangle($x1, $y1, $x2, $y2, $color);
      $image->rectangle($x1, $y1, $x2, $y2, $alt_color);
      

      my $function = $fig->function_of($peg->[0]);
      my $tooltip_text = "<table><tr><th colspan=2><b>Feature</b></th></tr><tr><td><b>ID</b></td>" . $peg->[0] . "<td></tr>" . 
	"<tr><td><b>Function</b></td><td>" . $function . "</td></tr>".
	  "<tr><td><b>Start</b></td><td>" . int($peg->[1]) . "</td></tr>" .
	    "<tr><td><b>Stop</b></td><td>" . int($peg->[2]) . "</td></tr></table>";
    
      $tooltip->add_tooltip('tooltip_' . $peg->[0], $tooltip_text);
      $image_map .= '<area shape="rect" coords="' . join(",", ($x1, $y1, $x2, $y2)) . qq~" onmouseover='hover(event, "tooltip_~ . $peg->[0] . qq~", "~.$tooltip->id.qq~");' href="http://www.nmpdr.org/linkin.cgi?id=~ . $peg->[0] . qq~" target="_blank"/>~;
      
    } 

    #draw fragments 
    my $prev_x2_plus = 0;
    my $prev_y1_plus = 0;
    my $prev_x2_neg = 0; 
    my $prev_y1_neg = 0;
    foreach my $frag (@{$data{$contig}->{Frag}}){
      my ($x1, $x2, $y1, $y2, $fill_y);

      $num_frag++;

      $x1 = $contig_start + ($frag->[1] / $scale);
      $x2 = $contig_start + ($frag->[2] / $scale);

      $bp_coverage += ($frag->[2] - $frag->[1]);      

      unless($frag->[4]){
	if($x1 > $prev_x2_plus){
	  $y1 = $center-25;
	  $y2 = $center-23; 
	} else {
	  $y1 = $prev_y1_plus-5;
	  $y2 = $prev_y1_plus-3;
	} 
      } else {
	if($x1 > $prev_x2_neg){
	  $y1 = $center+23;
	  $y2 = $center+25;
	} else {
	  $y1 = $prev_y1_neg+3+2;
	  $y2 = $prev_y1_neg+3+5;
	}
      }
      
      my $evalue = sprintf("%2.2e", $self->data('mgdb')->log2evalue($frag->[3]));
      my ($color) = $self->get_evalue_color_key($evalue);
      
      $image->filledRectangle($x1, $y1, $x2, $y2, $colors->[$color]); 
      
      my $tooltip_text = "<table><tr><th colspan=2><b>Fragment</b></th></tr><tr><td><b>ID</b></td>" . $frag->[0] . "<td></tr>" . 
	"<tr><td><b>Start</b></td>" . $frag->[1] . "<td></td></tr>" .
	  "<tr><td><b>Stop</b></td><td>" . $frag->[2] . "</td></tr> " .
	    "<tr><td><b>e-value</b></td><td>" . $evalue . "</td></tr></table>";
      
      $tooltip->add_tooltip('tooltip_' . $frag->[0], $tooltip_text);
      $image_map .= '<area shape="rect" coords="' . join(",", ($x1-1, $y1, $x2+1, $y2)) . qq~" onmouseover='hover(event, "tooltip_~ . $frag->[0] .qq~", "~.$tooltip->id.qq~");'/>~;    
      
      unless($frag->[4]){
	$prev_x2_plus = $x2;
	$prev_y1_plus = $y1;
      } else {
	$prev_x2_neg = $x2;
	$prev_y1_neg = $y1;
      }
    }
    


    if($color_flag){$color_flag=0;} else {$color_flag=1;}
    $contig_start = $x2;
  }

  $html .= $tooltip->output;
  
  my $display_ln = int(($region_end - $region_start) / 1000);
  if($display_ln > 1000){
    $display_ln = ($display_ln / 1000);
    $display_ln =~ s/^(\d+\.\d).*/$1 Mbp/g;
  } else {
    $display_ln .= " Kbp";
  }


  $html .= '<span style="padding-left:28px; font-size: 1.2em;"><b>Plot</b><span><br><img style="border: none;" src="' . $image->image_src() . '" usemap="#plotmap"><br>';
 $html .= $image_map . "</map>";

  #additional analysis
  my %hist_data;
  foreach my $contig (keys %data){
    foreach my $frag (@{$data{$contig}->{Frag}}){
      my ($tmp) = $self->get_evalue_color_key(sprintf("%2.2e", $self->data('mgdb')->log2evalue($frag->[3])));
      unless(exists $hist_data{$tmp}){
	$hist_data{$tmp} = 1;
      } else {
	$hist_data{$tmp} += 1;
      }
    }
  }

  #foreach (keys %hist_data){
  #  $html .= "Key: ".$_." value: ".$hist_data{$_}."<br>";
  #}

  my $genome_link = "<a href='http://www.nmpdr.org/linkin.cgi?genome=fig|" . $ref_genome . "' target='_Blank'>" . $ref_genome . "</a>"; 
  $html .= "<table style='padding-left: ".$offset. "px'>";
  $html .= '<tr><td><h3>Evalue histogram</h3><img src="' .  $self->evalue_histagram(\%hist_data) . '"></td>';
  
  my $display_ref_ln = int($ref_genome_length / 1000);
  if($display_ref_ln > 1000){
    $display_ref_ln = ($display_ref_ln / 1000);
    $display_ref_ln =~ s/^(\d+\.\d).*/$1 Mbp/g;
  } else {
    $display_ref_ln .= " Kbp";
  }
  
  my ($num_features) = (0);
  foreach my $cont (keys %data){
    map {if($_->[3] eq 1){$num_features++}} @{$data{$cont}->{Peg}};
  }

  my $percent_cov = $bp_coverage / $ref_genome_length;
  $percent_cov =~ s/^(\d+\.\d\d\d).*/$1/g;

  $html .= "<td style='width:600px;'><h3>Summary</h3><p>The reference genome " . $ref_genome_name  . " (" . $genome_link . ") contains ".$fig->number_of_contigs($ref_genome)." contig(s) and is ".$display_ref_ln. (($display_ref_ln eq $display_ln) ?  ".</p>" : " of which ".(scalar keys %data)." contig(s) and ".$display_ln. " are displayed.<p>");
  $html .= "<p>".$self->format_number($num_frag)." fragments hit ".$self->format_number($num_features)." features from the ".$ref_genome_name." genome. The genome contains ".$self->format_number($ref_genome_num_PEGs)." features in total. Combined, all of the sequence in the ".$self->data('job')->genome_name." (".$self->data('job')->genome_id.")"." metagenome is ".$self->format_number($bp_coverage)." bp, resulting in approximately ".$percent_cov."X coverage.</p>";
  
  $html .= "<p><a href=\"?page=MetagenomeSubset&metagenome=".$self->app->cgi->param('metagenome')."&genome=".$ref_genome.">View fragments</a></p>";

  $html .= "</td></tr></table>";


  return $html;
}

=pod

=item * B<evalue_histagram>()

Returns a creates a histagram from evalues data

=cut

sub evalue_histagram {
  my ($self, $data) = @_;

  my $width = 250;
  my $heigth = 200;
  my $evalue_hist = new WebGD($width, $heigth);
  my $white = $evalue_hist->colorAllocate(255,255,255);
  my $black = $evalue_hist->colorAllocate(0,0,0);
  my $blue = $evalue_hist->colorAllocate(104,143,197);

  my $colors;
  foreach(@{WebColors::get_palette('gradient')}){
    push(@$colors, $evalue_hist->colorAllocate($_->[0], $_->[1], $_->[2]));
  }

  $evalue_hist->transparent($white);
  $evalue_hist->interlaced('true');
  my @data_sorted = (sort {$data->{$b} <=> $data->{$a}} keys %$data);
  my $scale = $data->{$data_sorted[0]} / ($heigth - 30);

  $evalue_hist->rectangle(0, ($heigth-19), ((scalar keys %$data) * 20), ($heigth-19), $black);
  my ($x1, $x2, $y1, $y2) = (1, 19, 0, ($heigth - 20)); 
  foreach my $key (sort {$a <=> $b} keys %$data){
    $y1 = ($heigth - 20) - int($data->{$key} / $scale);

    
    $evalue_hist->filledRectangle($x1, $y1, $x2, $y2, $colors->[$key]);

    my $v_offset = (length($data->{$key}) * 5) + 5;
    $evalue_hist->stringUp(gdSmallFont,($x1+2),(((($heigth-30)-$y1) > ($v_offset + 10)) ? ($y1+$v_offset) : ($y1-5)),$data->{$key},$black);
    $x1 += 20;
    $x2 += 20;
  }
  return $evalue_hist->image_src();
}


=pod

=item * B<get_evalue_ranges>()

Returns a reference to an array of evalues

=cut

sub get_evalue_ranges {
  return [ 1e-50, 1e-40, 1e-30, 1e-25, 1e-20, 1e-15, 1e-10, 1e-7, 1e-5, 1e-3];
}


=pod

=item * B<get_evalue_color_key>()

Returns the evalue color key

=cut

sub get_evalue_color_key {
  my ($self, $evalue) = @_;

  my $color = 0; # start with the first color in the palette
  my $ranges = $self->get_evalue_ranges;

  for (my $i=0; $i<scalar(@$ranges); $i++) {
    if ($evalue<=$ranges->[$i]) { 
      my $key = $ranges->[$i];
      if ($i==0) {
	$key = '< '.$key;
      }
      elsif ($i==scalar(@$ranges)-1) {
	$key = '> '.$key;
      }
      else {
	$key = $key.' <==> '.$ranges->[$i-1];
      }
      return ($color+$i, $key);
    }
  }
  return ($color+scalar(@$ranges), '> 10');
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

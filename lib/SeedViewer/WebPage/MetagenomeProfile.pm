package SeedViewer::WebPage::MetagenomeProfile;

use base qw( WebPage );

use strict;
use warnings;

use WebConfig;
use URI::Escape;

use GD;

use SeedViewer::MetagenomeAnalysis;
use SeedViewer::SeedViewer qw( get_menu_metagenome get_settings_for_dataset is_public_metagenome );

1;

=pod

=head1 NAME

MetagenomeProfile - an instance of WebPage which displays metabolic/taxonomic profiles

=head1 DESCRIPTION

Display information about the taxonomic or metabolic distribution of metagenomes

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  # register components
  $self->application->register_component('HelpLink', 'FormHelp');
  $self->application->register_component('HelpLink', 'DataHelp');
  $self->application->register_component('PieChart', 'PieToplevel');
  $self->application->register_component('PieChart', 'PieDetails1');
  $self->application->register_component('PieChart', 'PieDetails2');
  $self->application->register_component('Table', 'MGTable');
  $self->application->register_component('Ajax', 'MGAjax');
  $self->application->register_component('TabView', 'Results');
  $self->application->register_component('TabView', 'Helptext');
  $self->application->register_component('Info', 'Info');
  $self->title('Sequence Profile');

  # get the metagenome id
  my $id = $self->application->cgi->param('metagenome') || '';

  # set up the menu
  &get_menu_metagenome($self->application->menu, $id);

  # load the settings for this type
  &get_settings_for_dataset($self);

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

    unless($self->app->cgi->param('evalue')){
      $self->app->cgi->param('evalue', '0.1');
    }

    $mgdb->query_load_from_cgi($self->app->cgi, $self->data('dataset'));
    $self->data('mgdb', $mgdb);
  }

  return 1;
}


=item * B<output> ()

Returns the html output of the page.

=cut

sub output {
  my ($self) = @_;

  # get metagenome id
  my $metagenome = $self->application->cgi->param('metagenome') || '';
  unless($metagenome) {
    $self->application->add_message('warning', 'No metagenome id given.');
    return "<h2>An error has occured:</h2>\n".
      "<p><em>No metagenome id given.</em></p>";
  }

  my $cgi = $self->application->cgi;
  my $job = $self->data('job');
  my $dataset =  $self->application->cgi->param('dataset');
  my $desc = $self->data('dataset_desc');

  # get sequence data
  my $seqs_num = $job->metaxml->get_metadata('preprocess.count_proc.num_seqs');
  my $seqs_in_evidence = $self->data('mgdb')->get_hits_count($dataset);
  my ($alen_min, $alen_max) = $self->data('mgdb')->get_align_len_range($dataset);

  # generate range arrays for form
  my @alen;
  my $len50 = 0;
  for( my $i = $alen_max; $i > $alen_min; $i-=10 ){
    push @alen, $i;
    $len50 = 1 if ($i == 50);
  }
  push @alen, $alen_min;
  push @alen, 50 unless ($len50);
  @alen = sort { $a <=> $b } @alen;

  my @pvalue;
  for( my $i = 200; $i >= 20; $i-=10 ){
    push @pvalue, $i;
  }

  my @identity;
  for (my $i=100; $i>=40; $i-=2 ){
    push @identity, $i;
  }
  
  my $meta_text = '';
  my $phylo_text = '';

  # write title + intro
  my $html = "<span style='font-size: 1.6em'><b>Sequence Profile </b></span>";
  $html .= "<span style='font-size: 1.6em'><b>for ".$job->genome_name." (".$job->genome_id.")</b></span>" if($job); 

  #$html .= "<p>&raquo; <a href='?page=MetagenomeOverview&metagenome=$metagenome'>".
  #"Back to Metagenome Overview</a></p>\n";
  
  $html .= "<h3>Select profile type, dataset and filter options</h3>";


  # create tiny help hoverboxes
  my $formhelp = $self->application->component('FormHelp');
  $formhelp->title('Please note:');
  $formhelp->disable_wiki_link(1);
  $formhelp->text('Please allow for a certain loading time when the charts and tables are calculated, especially if the metagenome is large.');
  $formhelp->hover_width(300);

  my $datahelp = $self->application->component('DataHelp');
  $datahelp->title($dataset);
  $datahelp->disable_wiki_link(1);
  $datahelp->hover_width(300);
  $datahelp->text($self->data('dataset_intro'));



  $meta_text .= "<div style='padding:0 5px 5px 5px; text-align: justify;'><img src=\"$FIG_Config::cgi_url/Html/metabolic.jpg\" style='width: 100; heigth: 100; float: left; padding: 5px 10px 10px 0;'><h3>Metabolic Profile with Subsystem</h3>";
  $meta_text .=  "<p>MG-RAST computes metabolic profiles based on <a href='http://www.theseed.org/wiki/Glossary#Subsystem'>Subsystems</a> from the sequences from your metagenome sample. You can modify the parameters of the calculated Metabolic Profile including e-value, p-value , percent identity and minimum alignment length. This will allow you to refine the analysis to suit the sequence characteristics of your sample. We recommend a minimal alignment length of 50bp be used with all RNA databases.</p></div>";

  $phylo_text .= "<div style='padding:0 5px 5px 5px; text-align: justify;'><img src=\"$FIG_Config::cgi_url/Html/phylogenetic.gif\" style='width: 100; heigth: 100;float: left; padding: 5px 10px 10px 0;'><h3>Phylogenetic Profile based on RDP</h3>";
  $phylo_text .= "<p>MG-RAST computes phylogenetic profiles base on various RNA databases (RDP, GREENGENES, Silva, and European Ribosomal) the SEED database. RDP is used as a default database to show the taxonomic distributions. You can modify the parameters of the calculated Metabolic Profile including e-value, p-value , percent identity and minimum alignment length. This will allow you to refine the analysis to suit the sample and sequence characteristics of your metagenome.  The SEED database provides an alternative way to identify taxonomies in the sample. Protein encoding genes are BLASTed against the SEED database and the taxonomy of the best hit is used to compile taxonomies of the sample.</p></div>";

  my $helptext = $self->application->component('Helptext');
  $helptext->width('600');
  $helptext->add_tab('Metabolic Profile', $meta_text);
  $helptext->add_tab('Phylogenetic Profile', $phylo_text);

  $html .= "<table><tr><td>";
  
  # begin form with parameters
  $html .= $self->start_form('mg_stats', { metagenome => $metagenome });
  $html .= "<div><table>";
  $html .= "<tr><th rowspan='2'>Profile type: </th><td style='vertical-align:middle;'><table><tr><td style='vertical-align:middle;'><input type='radio' ".($dataset =~ /subsystem/ ? "checked='checked'" : '')." name='type' id='metabolic_type' value='metabolic' onclick='tab_view_select(\"".$helptext->id()."\", \"0\");change_dataset_select();'></td><td style='vertical-align:middle;'></td><td style='vertical-align:middle;'><img src=\"$FIG_Config::cgi_url/Html/metabolic.jpg\" style='width: 50; heigth: 50;'></td><td style='vertical-align:middle;'><b>Metabolic Profile</b></td></tr></table></td></tr>"; 

 $html .= "<tr><td style='vertical-align:middle;'><table><tr><td style='vertical-align:middle;'><input type='radio' name='type' value='phylogenetic' ".($dataset =~ /subsystem/ ? '' : "checked='checked'")." onclick='tab_view_select(\"".$helptext->id()."\", \"1\");change_dataset_select();'></td><td style='vertical-align:middle;'><img src=\"$FIG_Config::cgi_url/Html/phylogenetic.gif\" style='width: 50; heigth: 50;'></td><td style='vertical-align:middle;'><b>Phylogenetic Profile</b></td></tr></table></td></tr>";

  my $labels = $self->data('dataset_labels');
  $html .= qq~<script>
function change_dataset_select () {
   var select = document.getElementById("dataset_select");
   var radio_meta = document.getElementById("metabolic_type");
   var options_meta = ["~.join('", "', @{$self->data('dataset_select_metabolic')}).qq~"];
   var labels_meta = ["~;
  foreach(@{$self->data('dataset_select_metabolic')}){
    $html .= $labels->{$_} . '", "';
  }
  $html .= qq~"];
   var options_phylo = ["~.join('", "', @{$self->data('dataset_select_phylogenetic')}).qq~"];
   var labels_phylo = ["~;
  foreach(@{$self->data('dataset_select_phylogenetic')}){
    $html .= $labels->{$_} . '", "';
  }
  $html .= qq~"]; 
   var options_used = [];
   var labels_used = [];

   if(radio_meta.checked){
      options_used = options_meta;
      labels_used = labels_meta;
   } else {
      options_used = options_phylo;
      labels_used = labels_phylo;
   }

   select.options.length = 0;
   for(i=0; i<options_used.length; i++){
       select.options[i] = new Option(labels_used[i], options_used[i]);
   } 
} </script>~;


  $html .= "<tr><th>Dataset: </th><td>";
  $html .= $cgi->popup_menu( -id => 'dataset_select', -name => 'dataset', -default => $dataset,
			     -values => $self->data('dataset_select'),
			     ($labels ? (-labels => $labels) : ()));
  $html .= "</td></tr>";
  $html .= "<tr><th>Maximum e-value</th><td>";
  $html .= $cgi->popup_menu( -name => 'evalue', -default => $cgi->param('evalue') || '',
			     -values => [ '0.1', '0.01', '1e-05', '1e-10', '1e-20', '1e-30', 
					  '1e-40', '1e-50', '1e-60' ]);
  $html .= "</td></tr>";
  $html .= "<tr><th>Minimum p-value</th><td>";
  $html .= $cgi->popup_menu( -name => 'bitscore', -default => $cgi->param('bitscore') || '',
			     -values => [ '', @pvalue ]);
  $html .= " <em>leave blank for all</em></td></tr>";
  $html .= "<tr><th>Minimum percent identity</th><td>";
  $html .= $cgi->popup_menu( -name => 'identity', -default => $cgi->param('identity') || '',
			     -values => [ '', @identity ]);
  $html .= " <em>leave blank for all</em></td></tr>";
  $html .= "<tr><th>Minimum alignment length</th><td>";
  $html .= $cgi->popup_menu( -name => 'align_len', -default => $cgi->param('align_len') || '',
			     -values => [ '', @alen ]);
  $html .= " <em>leave blank for all</em></td></tr>";
  #$html .= "<tr><th>No. of sequences with hits</th><td>$seqs_in_evidence</td></tr>";
  $html .= "<tr><td style='height:5px;'></td></tr><tr><td colspan='2'>".$self->button('Re-compute results', style=>'height:35px;width:150px;font-size:10pt;').
    " &laquo; <a href='".$self->url."metagenome=$metagenome&dataset=$dataset'>click here to reset</a>  &raquo;</td></tr>";
  $html .= "</table></div>\n";
  
  $html .= "</td><td style='padding-left: 50px;'>";

  $html .= $helptext->output;

  
  $html .= "</td></tr></table>";#$info->output().

  # add ajax output
  my $ajax = $self->application->component('MGAjax');
  $html .= $ajax->output;

  # add parse count data code
  $html .= count_data_js();
  
  if($dataset){
    # add div for charts
    $html .= "\n<h3>Profile results:</h3>\n";
    $html .= "<p>This ".($dataset =~ /subsystem/ ? 'Metabolic' : "Phylogenetic")." profile has been generated with the following parameters:";

    $html .= "<table>";
    $html .= "<tr><th>Dataset:</th><td>".$labels->{$dataset}."</td></tr>";
    $html .= "<tr><th>Number of sequences:</th><td>".$seqs_num."</td></tr>";
    $html .= "<tr><th>E-value:</th><td>".($cgi->param('evalue') || '0.1')."</td></tr>"; 
    $html .= "<tr><th>P-value:</th><td>".$cgi->param('bitscore')."</td></tr>" if $cgi->param('bitscore');
    $html .= "<tr><th>Percent identity:</th><td>".$cgi->param('identity')."</td></tr>"  if $cgi->param('identity');
    $html .= "<tr><th>Alignment length :</th><td>".$cgi->param('align_len')."</td></tr>" if $cgi->param('align_len');
    $html .= "</table>";

    $html .= "<p style='width:800px;'>Clicking on a category below will display a pie-chart of the distribution in the subcategory. In the tabular view, each category is linked to a table of the subset. Those subsets allow <b>downloading</b> in FASTA format. The organisms in the tabular view are linked to a <b>recruitment plot</b>. To download the entire dataset, please go to the <a href='rast.cgi?page=DownloadMetagenome&metagenome=$metagenome'>download page</a>.</p>";
    if($dataset =~ /subsystem/){
      $html .= "<p>The pie charts provide actual counts of sequences that hit a given functional role based on the Subsystem database from the SEED.  You can select a given subsystem group to get more detailed information up to 3 levels. These selections are represented in the Tabular View.</p>";
    } else {
      $html .= "<p>The pie charts provide actual counts of sequences that hit a given taxonomy based on a given database.  You can select a given group to get more detailed information up to 3 levels. These selections are represented in the Tabular View.</p>";
    }
    $html .= "<p>\n".$self->create_classified_vs_non_bar($seqs_num, $seqs_in_evidence)."\n</p>\n";
    
    # charts
    my $charts =  "<table><tr>\n";
    $charts .= "<td><div id='chart_0'>computing data...</div></td>";
    $charts .= "<td><div id='chart_1'></div></td>";
    $charts .= "<td><div id='chart_2'></div></td></tr>";
    $charts .= "<tr><td><div id='chart_3'></div></td>";
    $charts .= "<td><div id='chart_4'></div></td>";
    $charts .= "<td><div id='chart_5'></div></td>";
    $charts .= "</tr></table>\n\n";
    
    # table
    my $table = "<div id='table'>";
    $table .= "<img src='".IMAGES."clear.gif' onLoad='execute_ajax(\"load_table\",\"table\",\"mg_stats\",\"Loading table...\");' />";
    $table .= "</div>";
    
    
    # put them into tabs
    my $results = $self->application->component('Results');
    $results->width('100%');
    $results->add_tab('Charts', $charts);
    $results->add_tab('Tabular View', $table);
    $html .= $results->output;
  }
  
  return $html;

}


=pod

=item * B<create_classified_vs_non_bar> (I<total>, I<classified>

This method returns a horizontal bar chart of classified vs. unclassified counts.
It expects the total number of counts I<total> and the number of classified ones
I<classified>.

=cut

sub create_classified_vs_non_bar {
  my ($self, $total, $classified) = @_;
  
  # set graphic
  my $bar_height = 20;
  my $bar_width  = 500;
  my $legend_height = GD::gdSmallFont->height+5;
  my $font_width = GD::gdSmallFont->width();
  my $font_height = GD::gdSmallFont->height();

  my $perc = 100/$total*$classified;

  # create the image
  my $img = WebGD->new($bar_width, $bar_height+$legend_height);
  my $white = $img->colorResolve(255,255,255);
  my $black = $img->colorResolve(0,0,0);
  my $class = $img->colorResolve(70,130,180);
  my $non = $img->colorResolve(176,196,222);

  $img->string(GD::gdSmallFont, 0, 0, "Classified sequences vs. non-classified:", $black);
  $img->filledRectangle( 0, $legend_height+1, $bar_width/100*$perc, $legend_height+1+$bar_height, $class );
  $img->filledRectangle( $bar_width/100*$perc+1, $legend_height+1, $bar_width, $legend_height+1+$bar_height, $non );
  my $key1 = sprintf("%.2f%%",$perc)." ($classified)";
  my $key2 = sprintf("%.2f%%",100-$perc)." (".($total-$classified).")";
  my $key_y = $legend_height+1+(int(($bar_height-$font_height)/2));
  my $key1_x = $font_width;
  my $key2_x = $bar_width-((length($key2)+1)*$font_width);
  $img->string(GD::gdSmallFont, $key1_x, $key_y, $key1, $black);
  $img->string(GD::gdSmallFont, $key2_x, $key_y, $key2, $black);

  return '<img src="'.$img->image_src.'">';

}


=pod 

=item * B<load_table> ()

Returns the table. This method is invoked by an AJAX call.

=cut

sub load_table {
  my $self = shift;

  # start the timer
  my $time = time;

  # define columns and fetch best hits by dataset
  my $dataset = $self->data('dataset');
  my $desc = $self->data('dataset_desc');
  my $data;
  
  my $columns = [];
  if ($desc eq 'phylogenetic classification')
  {
    $columns = [ { name => 'Domain', filter => 1, operator => 'combobox',
		   visible => 0, show_control => 1 },
		 { name => '', filter => 1, operator => 'combobox', sortable => 1 },
		 { name => '', filter => 1, operator => 'combobox' },
		 { name => '', filter => 1, operator => 'combobox' },
		 { name => '', filter => 1, operator => 'combobox' },
		 { name => 'Organism Name', filter => 1 },
		 { name => '# Hits', sortable => 1 }
	       ];

    $data = $self->data('mgdb')->get_taxa_counts($dataset);
    
  }
  elsif ($desc eq 'metabolic reconstruction')
  {
    $columns = [ { name => 'Subsystem Hierarchy 1', filter => 1, operator => 'combobox', sortable => 1 },
		 { name => 'Subsystem Hierarchy 2', filter => 1, operator => 'combobox' },
		 { name => 'Subsystem Name', filter => 1, sortable => 1 },
		 { name => '# Hits', sortable => 1 }, 
	       ];

    $data = $self->data('mgdb')->get_subsystem_counts($dataset);

  }
  else {
    die "Unknown dataset in ".__PACKAGE__.": $dataset";
  }

  # set url string for params
  my $url_params = join('&', map { $_.'='.uri_escape($self->app->cgi->param($_)) } 
			qw( dataset metagenome evalue bitscore align_len identity )
			);

  # store the data
  my $table_data = [];
  my $count_data = '';

  if ($desc eq 'phylogenetic classification') {
    # expand data
    my $expanded_data = [];
    my $rank_0 = {};
    my $kids_0 = {};
    my $rank_1 = {};
    my $kids_1 = {};
    my $rank_2 = {};
    my $kids_2 = {};
    my $rank_3 = {};
    my $kids_3 = {};
    my $rank_4 = {};
    my $kids_4 = {};
    my $rank_5 = {};
    foreach (@$data) {
      my ($taxonomy, $count) = @$_;
      my $taxa = $self->data('mgdb')->split_taxstr($taxonomy);
      my $organism = $self->data('mgdb')->key2taxa($taxa->[scalar(@$taxa)-1]);
      
      push @$expanded_data, [ $self->data('mgdb')->key2taxa($taxa->[0]) || '',
			      $self->data('mgdb')->key2taxa($taxa->[1]) || '',
			      $self->data('mgdb')->key2taxa($taxa->[2]) || '',
			      $self->data('mgdb')->key2taxa($taxa->[3]) || '',
			      $self->data('mgdb')->key2taxa($taxa->[4]) || '',
			      $organism,
			      $count,
			      $taxonomy ];
    }
    @$expanded_data = sort { $a->[1] cmp $b->[1] || $a->[2] cmp $b->[2] || $a->[3] cmp $b->[3] || $a->[4] cmp $b->[4] || $a->[5] cmp $b->[5] } @$expanded_data;
    
    # do counts
    foreach my $row (@$expanded_data) {
      if (exists($rank_0->{$row->[0]})) {
	$rank_0->{$row->[0]} += $row->[6];
      } else {
	$rank_0->{$row->[0]} = $row->[6];
      }
      if (exists($rank_1->{$row->[1]})) {
	$rank_1->{$row->[1]} += $row->[6];
      } else {
	$rank_1->{$row->[1]} = $row->[6];
      }
      if (exists($rank_2->{$row->[2]})) {
	$rank_2->{$row->[2]} += $row->[6];
      } else {
	$rank_2->{$row->[2]} = $row->[6];
      }
      if (exists($rank_3->{$row->[3]})) {
	$rank_3->{$row->[3]} += $row->[6];
      } else {
	$rank_3->{$row->[3]} = $row->[6];
      }
      if (exists($rank_4->{$row->[4]})) {
	$rank_4->{$row->[4]} += $row->[6];
      } else {
	$rank_4->{$row->[4]} = $row->[6];
      }
      if (exists($rank_5->{$row->[5]})) {
	$rank_5->{$row->[5]} += $row->[6];
      } else {
	$rank_5->{$row->[5]} = $row->[6];
      }
      $kids_0->{$row->[0]}->{$row->[1]} = 1;
      $kids_1->{$row->[1]}->{$row->[2]} = 1;
      $kids_2->{$row->[2]}->{$row->[3]} = 1;
      $kids_3->{$row->[3]}->{$row->[4]} = 1;
      $kids_4->{$row->[4]}->{$row->[5]} = 1;
    }

    # store the counts in a html-data structure
    my $rank_0_string = join('^', map { $_ . '#' . $rank_0->{$_} } keys(%$rank_0));
    my $rank_1_string = join('^', map { $_ . '#' . $rank_1->{$_} } keys(%$rank_1));
    my $rank_2_string = join('^', map { $_ . '#' . $rank_2->{$_} } keys(%$rank_2));
    my $rank_3_string = join('^', map { $_ . '#' . $rank_3->{$_} } keys(%$rank_3));
    my $rank_4_string = join('^', map { $_ . '#' . $rank_4->{$_} } keys(%$rank_4));
    my $rank_5_string = join('^', map { $_ . '#' . $rank_5->{$_} } keys(%$rank_5));
    $rank_5_string =~ s/'//g;
    my $kids_0_string = join('^', map { $_ . '#' . join('#', keys(%{$kids_0->{$_}})) } keys(%$kids_0));
    my $kids_1_string = join('^', map { $_ . '#' . join('#', keys(%{$kids_1->{$_}})) } keys(%$kids_1));
    my $kids_2_string = join('^', map { $_ . '#' . join('#', keys(%{$kids_2->{$_}})) } keys(%$kids_2));
    my $kids_3_string = join('^', map { $_ . '#' . join('#', keys(%{$kids_3->{$_}})) } keys(%$kids_3));
    my $kids_4_string = join('^', map { $_ . '#' . join('#', keys(%{$kids_4->{$_}})) } keys(%$kids_4));
    $kids_4_string =~ s/'//g;
    $count_data = qq~
<input type='hidden' id='rank_0' value='~.$rank_0_string.qq~'>
<input type='hidden' id='rank_1' value='~.$rank_1_string.qq~'>
<input type='hidden' id='rank_2' value='~.$rank_2_string.qq~'>
<input type='hidden' id='rank_3' value='~.$rank_3_string.qq~'>
<input type='hidden' id='rank_4' value='~.$rank_4_string.qq~'>
<input type='hidden' id='rank_5' value='~.$rank_5_string.qq~'>
<input type='hidden' id='kids_0' value='~.$kids_0_string.qq~'>
<input type='hidden' id='kids_1' value='~.$kids_1_string.qq~'>
<input type='hidden' id='kids_2' value='~.$kids_2_string.qq~'>
<input type='hidden' id='kids_3' value='~.$kids_3_string.qq~'>
<input type='hidden' id='kids_4' value='~.$kids_4_string.qq~'>
<img src=\"$FIG_Config::cgi_url/Html/clear.gif\" onload='parse_count_data();'>~;
    
    foreach my $row (@$expanded_data) {
      my $base_link = "?page=MetagenomeSubset&".$url_params."&get=".uri_escape($row->[7]);

      if($dataset eq "SEED:seed_genome_tax"){
	push @$table_data, [ $row->[0],
			     '<a href="'.$base_link.'&rank=1">'.$row->[1]."</a>",
			     '<a href="'.$base_link.'&rank=2">'.$row->[2]."</a>",
			     '<a href="'.$base_link.'&rank=3">'.$row->[3]."</a>",
			     '<a href="'.$base_link.'&rank=4">'.$row->[4]."</a>",
			     '<a href="?page=MetagenomeRecruitmentPlot&ref_genome='.$self->data('mgdb')->get_genome_id($row->[7]).'&metagenome='.$self->application->cgi->param('metagenome').'">'.$row->[5]."</a>",
			     $row->[6],
			   ];
      } else {
	push @$table_data, [ $row->[0],
			     '<a href="'.$base_link.'&rank=1">'.$row->[1]."</a>",
			     '<a href="'.$base_link.'&rank=2">'.$row->[2]."</a>",
			     '<a href="'.$base_link.'&rank=3">'.$row->[3]."</a>",
			     '<a href="'.$base_link.'&rank=4">'.$row->[4]."</a>",
			     '<a href="'.$base_link.'&rank=4">'.$row->[5]."</a>",
			     $row->[6],
			   ];
      }
    }
  } elsif ($desc eq 'metabolic reconstruction') {
    # expand data
    my $expanded_data = [];
    my $rank_0 = {};
    my $kids_0 = {};
    my $rank_1 = {};
    my $kids_1 = {};
    my $rank_2 = {};

    foreach (@$data) {
      my ($h1, $h2, $subsystem, $taxonomy, $count) = @$_;
      
      push @$expanded_data, [ $self->data('mgdb')->key2taxa($h1) || 'Unclassified',
			      $self->data('mgdb')->key2taxa($h2) || $self->data('mgdb')->key2taxa($h1) || 'Unclassified',
			      $self->data('mgdb')->key2taxa($subsystem) || '',
			      $count,
			      $taxonomy
			    ];
      
    }
    @$expanded_data = sort { $a->[1] cmp $b->[1] || $a->[2] cmp $b->[2] || $a->[3] cmp $b->[3] } @$expanded_data;

    # do counts
    foreach my $row (@$expanded_data) {
      if (exists($rank_0->{$row->[0]})) {
	$rank_0->{$row->[0]} += $row->[3];
      } else {
	$rank_0->{$row->[0]} = $row->[3];
      }
      if (exists($rank_1->{$row->[1]})) {
	$rank_1->{$row->[1]} += $row->[3];
      } else {
	$rank_1->{$row->[1]} = $row->[3];
      }
      if (exists($rank_2->{$row->[2]})) {
	$rank_2->{$row->[2]} += $row->[3];
      } else {
	$rank_2->{$row->[2]} = $row->[3];
      }
      $kids_0->{$row->[0]}->{$row->[1]} = 1;
      $kids_1->{$row->[1]}->{$row->[2]} = 1;
    }

    # store the counts in a html-data structure
    my $rank_0_string = join('^', map { $_ . '#' . $rank_0->{$_} } keys(%$rank_0));
    my $rank_1_string = join('^', map { $_ . '#' . $rank_1->{$_} } keys(%$rank_1));
    my $rank_2_string = join('^', map { $_ . '#' . $rank_2->{$_} } keys(%$rank_2));
    my $kids_0_string = join('^', map { $_ . '#' . join('#', keys(%{$kids_0->{$_}})) } keys(%$kids_0));
    my $kids_1_string = join('^', map { $_ . '#' . join('#', keys(%{$kids_1->{$_}})) } keys(%$kids_1));
    $rank_0_string =~ s/'//g;
    $rank_1_string =~ s/'//g;
    $rank_2_string =~ s/'//g;
    $kids_0_string =~ s/'//g;
    $kids_1_string =~ s/'//g;
    $count_data = qq~
<input type='hidden' id='rank_0' value='~.$rank_0_string.qq~'>
<input type='hidden' id='rank_1' value='~.$rank_1_string.qq~'>
<input type='hidden' id='rank_2' value='~.$rank_2_string.qq~'>
<input type='hidden' id='kids_0' value='~.$kids_0_string.qq~'>
<input type='hidden' id='kids_1' value='~.$kids_1_string.qq~'>
<img src=\"$FIG_Config::cgi_url/Html/clear.gif\" onload='parse_count_data();'>~;

    my $seenGroup = {};
    foreach my $row (@$expanded_data) {
      next if $seenGroup->{$row->[2]};
      $seenGroup->{$row->[2]}++;
      my $base_link = "?page=MetagenomeSubset&".$url_params."&get=".uri_escape($row->[4]);

      push @$table_data, [ '<a href="'.$base_link.'&rank=0">'.$row->[0]."</a>" || '',
			   '<a href="'.$base_link.'&rank=1">'.$row->[1]."</a>" || '',
			   '<a href="'.$base_link.'&rank=2">'.$row->[2]."</a>" || '',
			   $rank_2->{$row->[2]}
			 ];
    }
  } else {
    die "Unknown dataset in ".__PACKAGE__.": $dataset";
  }

  # create table
  my $table = $self->application->component('MGTable');
  $table->show_export_button({ strip_html => 1 });
  $table->show_clear_filter_button(1);
  if (scalar(@$data) > 50) {
    $table->show_top_browse(1);
    $table->show_bottom_browse(1);
    $table->items_per_page(50);
    $table->show_select_items_per_page(1);
  }
  $table->columns($columns);
  $table->data($table_data);
  
  my $html = $table->output();
  $html .= "<p class='subscript'>Data generated in ".(time-$time)." seconds.</p>";
  $html .= $count_data;

  return $html;

}

sub load_chart {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;

  my @data = split(/\^/, $cgi->param('data'));
  my $rank = $cgi->param('rank') + 1;
  my $group = $cgi->param('group');
  my $last = 6;
  my $ss = $cgi->param('ss');
  if (($group eq 'Group') ||($ss)) {
    $ss = "ss=1&";
    $last = 3;
  } else {
    $ss = '';
  }

  unless (scalar(@data)) {
    return "";
  }

  # generate a data array with the counts and write color key
  my $chart_key = '<table>';
  my $chart_data = [];
  my $total = 0;
  map { my ($key, $value) = split(/#/, $_); $total += $value; } @data;
  foreach my $d (@data) {

    my ($key, $value) = split(/#/, $d);
    my $percent = $value / $total * 100;
    $percent = sprintf("%.2f%%", $percent);
    my $color = WebColors::get_palette('many')->[ scalar(@$chart_data) ];
    $chart_key .= "<tr><td style='width: 15px; background-color: rgb(".join(',',@$color).")';&nbsp</td>";
    my $val = "$key $percent ($value)";
    if ($rank < $last) {
      $val = qq~<a style='cursor: pointer; color: blue; text-decoration: underline;' onclick='clear_ranks("~.$rank.qq~");execute_ajax("load_chart","chart_~.$rank.qq~","~.$ss.qq~rank=~.$rank.qq~&data="+get_count_data("rank_~.$rank.qq~", "~.$key.qq~")+"&group=~.uri_escape($key).qq~","Loading chart...");'>$val</a>~;
    }
    $chart_key .= "<td>$val</td></tr>";

    push @$chart_data, { data => $value, title => $key };

  }
  $chart_key .= '</table>';

  # fill the pie chart
  my $chart = $self->application->component('PieToplevel');
  $chart->size(250);
  $chart->data($chart_data);

  # output
  my $html = "<table>";
  $html .= "<tr><th>$group</th></tr><tr><td>".$chart->output()."<br/>".$chart_key."</td></tr>";
  $html .= "</table>";

  return $html;
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

sub count_data_js {
  return qq~<script>
var rank_1_counts = new Array();
var rank_0_kids = new Array();
var rank_2_counts = new Array();
var rank_1_kids = new Array();
var rank_3_counts = new Array();
var rank_2_kids = new Array();
var rank_4_counts = new Array();
var rank_3_kids = new Array();
var rank_5_counts = new Array();
var rank_4_kids = new Array();

function parse_count_data () {
  var rank_str_1 = document.getElementById('rank_1').value;
  var rank_array_1 = rank_str_1.split('^');
  for (h=0;h<rank_array_1.length;h++) {
    var r = rank_array_1[h].split('#');
    rank_1_counts[r[0]] = r[1];
  }
  var rank_str_2 = document.getElementById('rank_2').value;
  var rank_array_2 = rank_str_2.split('^');
  for (h=0;h<rank_array_2.length;h++) {
    var r = rank_array_2[h].split('#');
    rank_2_counts[r[0]] = r[1];
  }
  if (document.getElementById('rank_3')) {
    var rank_str_3 = document.getElementById('rank_3').value;
    var rank_array_3 = rank_str_3.split('^');
    for (h=0;h<rank_array_3.length;h++) {
      var r = rank_array_3[h].split('#');
      rank_3_counts[r[0]] = r[1];
    }
    var rank_str_4 = document.getElementById('rank_4').value;
    var rank_array_4 = rank_str_4.split('^');
    for (h=0;h<rank_array_4.length;h++) {
      var r = rank_array_4[h].split('#');
      rank_4_counts[r[0]] = r[1];
    }
    var rank_str_5 = document.getElementById('rank_5').value;
    var rank_array_5 = rank_str_5.split('^');
    for (h=0;h<rank_array_5.length;h++) {
      var r = rank_array_5[h].split('#');
      rank_5_counts[r[0]] = r[1];
    }
  }
  var kids_str_0 = document.getElementById('kids_0').value;
  var kids_array_0 = kids_str_0.split('^');
  for (h=0;h<kids_array_0.length;h++) {
    var r = kids_array_0[h].split('#');
    var key = r.shift();
    rank_0_kids[key] = r;
  }
  var kids_str_1 = document.getElementById('kids_1').value;
  var kids_array_1 = kids_str_1.split('^');
  for (h=0;h<kids_array_1.length;h++) {
    var r = kids_array_1[h].split('#');
    var key = r.shift();
    rank_1_kids[key] = r;
  }
  var group = 'Group';
  var ss = 0;
  if (document.getElementById('kids_2')) {
    group = 'Domain';
    var kids_str_2 = document.getElementById('kids_2').value;
    var kids_array_2 = kids_str_2.split('^');
    for (h=0;h<kids_array_2.length;h++) {
      var r = kids_array_2[h].split('#');
      var key = r.shift();
      rank_2_kids[key] = r;
    }
    var kids_str_3 = document.getElementById('kids_3').value;
    var kids_array_3 = kids_str_3.split('^');
    for (h=0;h<kids_array_3.length;h++) {
      var r = kids_array_3[h].split('#');
      var key = r.shift();
      rank_3_kids[key] = r;
    }
    var kids_str_4 = document.getElementById('kids_4').value;
    var kids_array_4 = kids_str_4.split('^');
    for (h=0;h<kids_array_4.length;h++) {
      var r = kids_array_4[h].split('#');
      var key = r.shift();
      rank_4_kids[key] = r;
    }
  } else {
    ss = 1;
  }
  execute_ajax("load_chart","chart_0","group="+group+"&rank=0&data="+encodeURIComponent(document.getElementById('rank_0').value),"Loading chart...");
}

function get_count_data (rank, item) {
  var ret = new Array();
  if (rank == 'rank_1') {
    var kids = rank_0_kids[item];
    for (i=0;i<kids.length;i++) {
      ret[ret.length] = kids[i] + "#" + rank_1_counts[kids[i]];
    }
  } else if (rank == 'rank_2') {
    var kids = rank_1_kids[item];
    for (i=0;i<kids.length;i++) {
      ret[ret.length] = kids[i] + "#" + rank_2_counts[kids[i]];
    }    
  } else if (rank == 'rank_3') {
    var kids = rank_2_kids[item];
    for (i=0;i<kids.length;i++) {
      ret[ret.length] = kids[i] + "#" + rank_3_counts[kids[i]];
    }
  } else if (rank == 'rank_4') {
    var kids = rank_3_kids[item];
    for (i=0;i<kids.length;i++) {
      ret[ret.length] = kids[i] + "#" + rank_4_counts[kids[i]];
    }
  } else if (rank == 'rank_5') {
    var kids = rank_4_kids[item];
    for (i=0;i<kids.length;i++) {
      ret[ret.length] = kids[i] + "#" + rank_5_counts[kids[i]];
    }
  }
  return encodeURIComponent(ret.join('^'));
}

function clear_ranks (rank) {
  for (i=rank;i<6;i++) {
    if (document.getElementById('chart_'+i)) {
      document.getElementById('chart_'+i).innerHTML = '';
    }
  }
}
</script>~;
}

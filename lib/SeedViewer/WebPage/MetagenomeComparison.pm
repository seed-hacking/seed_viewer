package SeedViewer::WebPage::MetagenomeComparison;

use base qw( WebPage );

1;

use strict;
use warnings;

use WebConfig;
use WebColors;
use GD;
use WebComponent::WebGD;
use URI::Escape;

use POSIX qw(ceil);

use SeedViewer::MetagenomeAnalysis;
use SeedViewer::SeedViewer qw( get_menu_metagenome get_settings_for_dataset dataset_is_phylo dataset_is_metabolic is_public_metagenome get_public_metagenomes );

=pod

=head1 NAME

MetagenomeComparison - an instance of WebPage to compare multiple metagenome to 
each other

=head1 DESCRIPTION

Comparison of multiple metagenome profiles

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('Compare Metagenomes');
  $self->application->register_component('Table', 'MGTable');
  $self->application->register_component('TabView', 'Helptext');
  $self->application->register_component('Ajax', 'MGAjax');
  $self->application->register_component('HelpLink', 'DataHelp');
  $self->application->register_component('DisplayListSelect', 'MGSelect');
  $self->application->register_component('Ajax', 'SelectLevelAjax');

  # get metagenome id(s)
  my $id = $self->application->cgi->param('metagenome') || '';
  my $metagenome_selected = [];

  # load select mg component to get and load the jobs for the selected metagenomes
  my $MGSelect = $self->application->component('MGSelect');
  $MGSelect->metadata( $self->column_metadata );
  my $component_content = $MGSelect->output();

  push @$metagenome_selected, $id;
  push @$metagenome_selected, split (/~/, $MGSelect->new_columns)
      if ($MGSelect->new_columns);

  # set up the menu
  &get_menu_metagenome($self->application->menu, $id);

  # load the settings for this type
  &get_settings_for_dataset($self);
  
  # init the metagenome database
  foreach my $id (@$metagenome_selected) {
    my $job;
    eval { $job = $self->app->data_handle('RAST')->Job->init({ genome_id => $id }); };
    unless($job) {
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
    $self->data("job_$id", $job);

    my $mgdb = SeedViewer::MetagenomeAnalysis->new($job);
    unless($mgdb) {
      $self->app->error("Unable to retrieve the analysis database for metagenome '$id'.");
      return 1;
    }

    $mgdb->query_load_from_cgi($self->app->cgi, $self->data('dataset'));
    $self->data("mgdb_$id", $mgdb);

  }
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

  my $error = '';

  # get metagenome id(s)
  my $metagenome = $self->application->cgi->param('metagenome') || '';

  # write title and intro
  my $job = $self->data('job');
  my $html = "<span style='font-size: 1.6em'><b>Metagenome Heat Map for ".$job->genome_name." (".$job->genome_id.")</b></span>";

  # abort if error
  if ($error) {
    $html .= $error;
    return $html;
  }

  $html .= "<h3>Select comparison type, dataset, filter option, and metagenomes</h3>";

  my $datahelp = $self->application->component('DataHelp');
  $datahelp->title($self->data('dataset'));
  $datahelp->disable_wiki_link(1);
  $datahelp->hover_width(300);
  $datahelp->text($self->data('dataset_intro'));

  # init arrays for form 
  my @evalue = ( '0.1', '0.01', '1e-05', '1e-10', '1e-20', '1e-30', '1e-40', '1e-50', '1e-60' );

  my @pvalue;
  for( my $i = 200; $i >= 20; $i-=10 ){
    push @pvalue, $i;
  }

  my @identity;
  for (my $i=100; $i>=40; $i-- ){
    push @identity, $i;
  }

  my @alen;
  for( my $i = 10; $i <= 200; $i+=10 ){
    push @alen, $i;
  }

  my $labels = $self->data('dataset_labels');
  $html .= qq~<script>
function set_clicked(max_cols){
   document.getElementById('select_box').style.cursor="wait";
//   if (level != null){
//      var select = document.getElementById("last_clicked");
//      select.value = level;
//      clearfield(level+1);
//      add_new_list(level);
//      display_org_toggle();
//      show_column(0,level-1);
//   }
//   else{
      var select_obj = document.getElementById('select_level');
      var select = document.getElementById("last_clicked");
      var level = select_obj.value;
      select.value = level;
      if (max_cols == 5){
         display_org_toggle1();
      }
      else {
         display_org_toggle1('metabolic');
      }
      for (var i=level-1;i>=1;i--){
	  show_column(0,i);
      }
      for (var i=level;i<max_cols;i++){
	  hide_column(0,i);
      }
     
      // show or hide the corresponding venn diagram
      for (var i=1;i<=max_cols;i++){
         if (i==level){
            document.getElementById('venn_' + i).style.visibility = 'visible';
            document.getElementById('venn_' + i).style.display = 'block';
         }
         else{
            document.getElementById('venn_' + i).style.visibility = 'hidden';
            document.getElementById('venn_' + i).style.display = 'none';
         }
      }
//   }
   document.getElementById('select_box').style.cursor="default";
}
function add_new_list(last_clicked){
    var new_field = last_clicked+1;
    var next_box = document.getElementById('level' + new_field);
    var box = document.getElementById('level' + last_clicked);
    var selLength = box.length;

    var new_box_options = new Array();
    for(i=selLength-1; i>=0; i--)
    {
	if(box.options[i].selected){
	    var box_options = document.getElementById(box.options[i].value).value;
	    var tmp = box_options.split("\~");
	    for (var j=0;j<tmp.length;j++){
		new_box_options[new_box_options.length] = tmp[j];
	    }
	}
    }
    new_box_options.sort;
    //clearfield(new_field);
    for (var i=0; i<new_box_options.length;i++){
	var newOpt = new Option(new_box_options[i] + ' (' + document.getElementById(new_box_options[i] + '_count').value + ')', new_box_options[i]);
	next_box.options[i] = newOpt;
    }
}
function clearfield (field){
    for (var j=field;j<=5;j++){
        if (j<5){
	   hide_column(0,j-1);
       }
	var box = document.getElementById('level'+j);
	var selLength = box.length;
	for(i=selLength-1; i>=0; i--)
	{
	    box.options[i] = null;
	}
    }
}
function display_org_toggle (){
    var checkboxid = document.getElementById('display_org');
    var qty = document.getElementById('mg_selected_qty').value;
    var select = document.getElementById("last_clicked").value;
    if (checkboxid.checked){
	show_column(0,4);
	for (var i=0;i<=qty-1;i++){
	    var adder = (i*10)+5;
	    for (var j=0;j<8;j++){
		hide_column(0,j+adder);
	    }
	    show_column(0,adder+8);
	    show_column(0,adder+9);
	}
	uncollapse_rows();
    }
    else{
	hide_column(0,4);
	for (var i=0;i<=qty-1;i++){
           var adder = (i*10)+5;
            for(var j=0;j<10;j++){
		hide_column(0,j+adder);
            }

	   if (select == 1){
	       show_column(0,adder);
	       show_column(0,adder+1);
	   }
	   else if (select == 2){
	       show_column(0,adder+2);
	       show_column(0,adder+3);	       
	   }
	   else if (select == 3){
	       show_column(0,adder+4);
	       show_column(0,adder+5);
	   }
	   else if (select == 4){
	       show_column(0,adder+6);
	       show_column(0,adder+7);
	   }
       }
	collapse_rows(select-1);
    }
}
function display_org_toggle1 (is_metabolic){
    var checkboxid = document.getElementById('display_absolute');
    var qty = document.getElementById('mg_selected_qty').value;
    var select = document.getElementById("last_clicked").value;
    if (is_metabolic == null){
	var precols = 5;
	var max = 10;
        for (var i=0;i<=qty-1;i++){
	  var adder = (i*max)+precols;
	  for(var j=0;j<max;j++){
	    hide_column(0,j+adder);
	  }
        }
	collapse_rows(select-1);
    }
    else{
	var precols = 3;
	var max = 6;
        for (var i=0;i<=qty-1;i++){
	  var adder = (i*max)+precols;
	  for(var j=0;j<max;j++){
	    hide_column(0,j+adder);
	  }
        }
        collapse_rows(select-1,is_metabolic);
    }

    for (var i=0;i<=qty-1;i++){
	var adder = (i*max)+precols;
	
	if (select == 1){
	    if (checkboxid.checked){
		show_column(0,adder+1);
	    }
	    else{
		show_column(0,adder);
	    }
	}
	else if (select == 2){
	    if (checkboxid.checked){
		show_column(0,adder+3);
	    }
	    else{
		show_column(0,adder+2);	       
	    }
	}
	else if (select == 3){
	    if (checkboxid.checked){
		show_column(0,adder+5);
	    }
	    else{
		show_column(0,adder+4);
	    }
	}
	else if (select == 4){
	    if (checkboxid.checked){
		show_column(0,adder+7);
	    }
	    else{
		show_column(0,adder+6);
	    }
	}
	else if (select == 5){
	    if (checkboxid.checked){	    
		show_column(0,adder+9);
	    }
	    else{
		show_column(0,adder+8);
	    }
	}

    }

}

function collapse_rows(level,metabolic) {
    var col;
    var col_diff;
    var col_class;
    if (metabolic == null){
       col_class = 10;
       col_diff = 0;
    }
    else{
       col_class = 6;
       col_diff = 2;
    }

    table_reset_filters(0);
    var qty = document.getElementById('mg_selected_qty').value;
    if (level == 0){
	col = 6-col_diff;
    } else if (level == 1){
	col = 8-col_diff;
    } else if (level == 2){
	col = 10-col_diff;
    } else if (level == 3){
	col = 12-col_diff;
    } else if (level == 4){
	col = 14-col_diff;
    }

    for (var i=0;i<qty;i++){
	var new_col = col + (i*col_class);
	var operator = document.getElementById('table_0_operator_' + new_col);
	var operand =  document.getElementById('table_0_operand_' + new_col);

	operator.value = 'unequal';
	operator.selectedIndex=1;
	operand.value = '-1';
    }
    table_filter(0);

}
function uncollapse_rows(){
    var i=0;
    while (document.getElementById('cell_0_0_' + i) != null){
	document.getElementById('0_row_' + i).style.display = 'table-cell';
	i++;
    }
    reload_table(0);
}
function clear_table_filters(id,max){
   for (var i=1;i<=max;i++){
       var filter = document.getElementById('table_' + id + '_operand_' + i);
       filter.text = 'all';
       filter.selectedIndex = 0;
       filter.value = '';
   }
   check_submit_filter2("0");
}
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

  my $meta_text .= "<div style='padding:0 5px 5px 5px; text-align: justify;'><img src=\"$FIG_Config::cgi_url/Html/metabolic.jpg\" style='width: 100; heigth: 100; float: left; padding: 5px 10px 10px 0;'><h3>Metabolic Comparison with Subsystem</h3>";
  $meta_text .=  "<p>MG-RAST computes metabolic profiles based on <a href='http://www.theseed.org/wiki/Glossary#Subsystem'>Subsystems</a> from the sequences from your metagenome sample. You can modify the parameters of the calculated Metabolic Profile including e-value, p-value , percent identity and minimum alignment length. This will allow you to refine the analysis to suit the sequence characteristics of your sample. We recommend a minimal alignment length of 50bp be used with all RNA databases.</p></div>";

  my $phylo_text .= "<div style='padding:0 5px 5px 5px; text-align: justify;'><img src=\"$FIG_Config::cgi_url/Html/phylogenetic.gif\" style='width: 100; heigth: 100;float: left; padding: 5px 10px 10px 0;'><h3>Phylogenetic Comparison based on RDP</h3>";
  $phylo_text .= "<p>MG-RAST computes phylogenetic profiles base on various RNA databases (RDP, GREENGENES, Silva, and European Ribosomal) the SEED database. RDP is used as a default database to show the taxonomic distributions. You can modify the parameters of the calculated Metabolic Profile including e-value, p-value , percent identity and minimum alignment length. This will allow you to refine the analysis to suit the sample and sequence characteristics of your metagenome.  The SEED database provides an alternative way to identify taxonomies in the sample. Protein encoding genes are BLASTed against the SEED database and the taxonomy of the best hit is used to compile taxonomies of the sample.</p></div>";


   my $helptext = $self->application->component('Helptext');
  $helptext->width('600');
  $helptext->add_tab('Metabolic Comparison', $meta_text);
  $helptext->add_tab('Phylogenetic Comparison', $phylo_text);
  # start form
  my $cgi = $self->application->cgi;
  my $dataset = $self->data('dataset');
  $html .= $self->start_form('mg_heatmap', {metagenome=>$metagenome});
  $html .= "<table><tr><td><table>";
  $html .= "<tr><th rowspan='2'>Comparison type: </th><td style='vertical-align:middle;'><table><tr><td style='vertical-align:middle;'><input type='radio' ".($dataset =~ /subsystem/ ? "checked='checked'" : '')." name='type' id='metabolic_type' value='metabolic' onclick='tab_view_select(\"".$helptext->id()."\", \"0\");change_dataset_select();'></td><td style='vertical-align:middle;'></td><td style='vertical-align:middle;'><img src='./Html/metabolic.jpg' style='width: 50; heigth: 50;'></td><td style='vertical-align:middle;'><b>Metabolic Comparison</b></td></tr></table></td></tr>"; 
# onLoad='change_dataset_select();'
  $html .= "<tr><td style='vertical-align:middle;'><table><tr><td style='vertical-align:middle;'><input type='radio' name='type' value='phylogenetic' ".($dataset =~ /subsystem/ ? '' : "checked='checked'")." onclick='tab_view_select(\"".$helptext->id()."\", \"1\");change_dataset_select();'></td><td style='vertical-align:middle;'><img src='$FIG_Config::cgi_url/Html/phylogenetic.gif' style='width: 50; heigth: 50;' ></td><td style='vertical-align:middle;'><b>Phylogenetic Comparison</b></td></tr></table></td></tr>";
#onLoad='change_dataset_select();'

  $html .= "<tr><th>Dataset: </th><td>";
  $labels = $self->data('dataset_labels');
  $html .= $cgi->popup_menu(-id => 'dataset_select', -name => 'dataset', -default => $self->data('dataset'),
			     -values => $self->data('dataset_select'),
			     ($labels ? (-labels => $labels) : ()));
  $html .= "</td></tr>";
  $html .= "<tr><th>Maximum e-value</th><td>";
  $html .= $cgi->popup_menu( -name => 'evalue', -default => $cgi->param('evalue') || '',
			     -values => \@evalue );
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
  $html .= "</table></td><td>".$helptext->output()."</td></tr><tr><td style='height:10'></td></tr><tr><td>";
  
 # $html .= "<p><strong>Note:</strong> Please allow for a certain loading time when the comparison is calculated, especially if the metagenomes are large or if you are comparing several metagenomes at the same time.</p>\n";

  $html .= "<table>";
  $html .= "<tr><th>Please choose some metagenomes to compare:</th><tr>\n";
  $html .= "<tr><td>";

  # load select mg component
  my $MGSelect = $self->application->component('MGSelect');
  $MGSelect->metadata( $self->column_metadata );
  $MGSelect->filter_out(1);
  $html .= $MGSelect->output();

  $html .= "</td></tr>\n</table></td><td>";

  $html .= "<p>The following options can be used to adjust the display of the comparison:</p>";
  $html .= "<table>";
  $html .= "<tr><th>Apply 'heat map' style coloring:</th><td>";
  $html .=  $cgi->checkbox( -name => 'colouring', -checked => $cgi->param('colouring') || 1,
			    -value => 1, -label => '').
  " <em></em></td></tr>";
  $html .= "<tr><th>Number of groups used in coloring:</th><td>";
  $html .= $cgi->popup_menu( -name => 'groups', -default => $cgi->param('groups') || 10,
			     -values => [ '4', '5', '6', '7', '8', '9', '10' ]);
  $html .= "</td></tr>";
  $html .= "<tr><th>Effective raw score maximum:</th><td>";
  $html .= $cgi->popup_menu( -name => 'effective_max', -default => $cgi->param('effective_max') || '0.3',
			     -values => [ '0.01', '0.1', '0.2', '0.3', '0.4', '0.5' ]);
  $html .= " <em>choose a maximum relative score as upper limit for the coloring</em></td></tr>";
#  $html .= "<tr><th>Show absolute values</th><td>";
#  $html .=  $cgi->checkbox( -name => 'absolute_scores',  -value => 1, -label => '',
#			    -checked => $cgi->param('absolute_scores') || 0 ).
#    " <em>check to view raw counts instead of relative abundance</em></td></tr>";
  $html .= "</table></td></tr><tr><td><table>";
  $html .= "<tr><td colspan='2'>".$self->button('Re-compute results', style => 'height:35px;width:150px;font-size:10pt;') .
    " &laquo; <a href='".$self->url."'>click here to reset</a>  &raquo;</td></tr>";
  $html .= "</table></td></tr></table>";
  $html .= $self->end_form();

  # add ajax output
  $html .= $self->application->component('MGAjax')->output;

  $self->application->register_component('HelpLink', 'VennHelp');
  my $VennHelp = $self->application->component('VennHelp');
  $VennHelp->hover_width(300);
  $VennHelp->disable_wiki_link(1);
  $VennHelp->title('Distribution & Venn Diagram');
  $VennHelp->text('The table and Venn diagram below shows the classification distribution of the metagenomes. You can select to which hierarchical level you wish to see the classification distribution. The Venn diagram is used as a visual aid in comparing multiple metagenomes. The diagram is currently enabled when comparing two or three metagenomes. The points in each of the sections of the diagram represent classified metagenomic sequences against phylogeny or metabolic data (depending on the dataset selected). You can select which section of the Venn diagram to view on the table below by selecting the appropiate section in this dropdown menu.');
  $html .= "<h3>Classification distribution diagram and table " . $VennHelp->output() . "</h3>";


#  $html .= "<p>You can select which section to view on the table below by selecting the appropiate section in the dropdown menu next to diagram.</p>";
  $html .= "<div id='table'>";
  $html .= "<img src='".IMAGES."clear.gif' onLoad='execute_ajax(\"load_table\",\"table\",\"mg_heatmap\",\"Loading table...\");' />";
  $html .= "</div>";

  return $html;

}


=pod 

=item * B<load_table> ()

Returns the table. This method is invoked by an AJAX call.

=cut

sub load_table {
  my $self = shift;

  my $time = time;

  # get metagenome id(s)
  my $metagenome = $self->application->cgi->param('metagenome') || '';
  my $metagenome_selected = [];
  push @$metagenome_selected, $self->application->cgi->param('metagenome');

  # load select mg component
  my $MGSelect = $self->application->component('MGSelect');
#  $MGSelect->metadata( $self->get_mg_comparison_table_metadata );
  $MGSelect->metadata( $self->column_metadata );
  my $component_content = $MGSelect->output();

  push @$metagenome_selected, split (/~/, $MGSelect->new_columns)
    if ($MGSelect->new_columns);

  unless (scalar(@$metagenome_selected )) {
    return "<p><em>No metagenomes selected.</em></p>";
  }

  # collect the data for each metagenome 
  my $dataset = $self->data('dataset');
  my $desc = $self->data('dataset_desc');
  my $data = {};
  my $url_params = {};
  my $labels = $self->data('dataset_labels');
  my $job_description = {};

  foreach my $id (@$metagenome_selected ) {
    my $job = $self->data("job_$id");
    $job_description->{$id} = $job->genome_name;
    $data->{$id} = {} unless (exists $data->{$id});
    $data->{$id}->{sequence_count} = $job->metaxml->get_metadata('preprocess.count_proc.total');
    $data->{$id}->{fullname} = $job->genome_name." (".$job->genome_id.")";

    # set url string for params
    $url_params->{$id} = join('&', map { $_.'='.uri_escape($self->app->cgi->param($_)) }
			      qw( dataset evalue bitscore align_len identity )
			     );
    $url_params->{$id} .= '&metagenome=' . $id;

    # fetch best hits by dataset
    if (dataset_is_phylo($desc)) {
      
      $data->{$id}->{data} = $self->data("mgdb_$id")->get_taxa_counts($dataset);
  
    }
    elsif (dataset_is_metabolic($desc)) {

      $data->{$id}->{data} = $self->data("mgdb_$id")->get_subsystem_counts($dataset);

    }
    else {
      die "Unknown dataset in ".__PACKAGE__.": $dataset $desc";
    }
    
  }

  # define the columns for the table
  my $columns = [];
  my $class_cols = 0;
  my $linked_columns = {};

  if (dataset_is_phylo($desc)) {
    $columns = [ { name => 'Domain', filter => 1, operator => 'combobox', visible => 1 },
		 { name => '', filter => 1, operator => 'combobox', sortable => 1, width => 150, visible => 1 },
		 { name => '', filter => 1, operator => 'combobox', width => 150, visible => 0 },
		 { name => '', filter => 1, operator => 'combobox', width => 150, visible => 0 },
		 { name => 'Organism Name', filter => 1, visible => 0 },
	       ];
    $class_cols = 5;
    $linked_columns->{0} = {'max_level'=>1, 'add_block' =>10, 'start_col' => 6, 'first_stat' => 6};
    $linked_columns->{1} = {'level_1' => 1, 'max_level'=>2, 'add_block' =>10, 'start_col' => 6, 'first_stat' => 8};
    $linked_columns->{2} = {'level_1' => 1, 'level_2' => 2, 'max_level'=>3, 'add_block' =>10, 'start_col' => 6, 'first_stat' => 10};
    $linked_columns->{3} = {'level_1' => 1, 'level_2' => 2, 'level_3'=>3, 'max_level'=>4, 'add_block' =>10, 'start_col' => 6, 'first_stat' => 12};
    $linked_columns->{4} = {'level_1' => 1, 'level_2' => 2, 'level_3'=>3, 'level_4'=>4, 'max_level'=>5, 'add_block' =>10, 'start_col' => 6, 'first_stat' => 14};
  }
  elsif (dataset_is_metabolic($desc)) {
    $columns = [ { name => 'Subsystem Hierarchy 1', filter => 1, operator => 'combobox', width => 150, sortable => 1, visible=> 1 },
		 { name => 'Subsystem Hierarchy 2', filter => 1, width => 150, visible => 1  },
		 { name => 'Subsystem Name', filter => 1, sortable => 1,  width => 150, visible => 0  },
	       ];
    $class_cols = 3;
    $linked_columns->{0} = {'max_level'=>1, 'add_block' => 6, 'start_col' => 4, 'first_stat' => 4};
    $linked_columns->{1} = {'level_1' => 1, 'max_level'=>2, 'add_block' => 6, 'start_col' => 4, 'first_stat' => 6};
    $linked_columns->{2} = {'level_1' => 1, 'level_2' => 2, 'max_level'=>3, 'add_block' => 6, 'start_col' => 4, 'first_stat' => 8};
  }
  else {
    die "Unknown dataset in ".__PACKAGE__.": $dataset";
  }

  my $add_cols = 1;
  # add column for each metagenome in comparison
  foreach my $id (keys(%$data)) {
    for (my $i=1;$i<=$class_cols;$i++){
      my $visible;
      if ($i == 2){ $visible = 1} else {$visible=0}
      push @$columns, { name => $id,
			filter => 1,
			sortable => 1,
			width => 150,
			visible => $visible,
			hide_filter => 1,
			tooltip => $data->{$id}->{fullname}
		      };

      my $hash = { name => $id,
			filter => 1,
			sortable => 1,
			hide_filter => 1,
			width => 150,
			visible => 0,
			tooltip => $data->{$id}->{fullname}
		      };
      if ($i == 2) {
	$hash->{operand} = -1;
	$hash->{operator} = 'unequal';
      }
      push @$columns, $hash;
    }
  
#    $linked_columns->{$id} = $class_cols+$add_cols;
    $add_cols++;
  }

  # get the counts for the different levels of taxonomy
  my $level_counts={};
  my $all_data;
  if (dataset_is_phylo($desc)) {
    foreach my $id (keys(%$data)) {
      my $db = $self->data("mgdb_$id");
      push @$all_data, @{$data->{$id}->{data}};
      foreach my $d (@{$data->{$id}->{data}}) {
	my $taxonomy = $d->[0];
	my $taxa = $db->split_taxstr($taxonomy);
	for (my $level=0;$level<=3;$level++){
	  # get the count
	  $level_counts->{$id}->{$db->key2taxa($taxa->[$level])} += $d->[scalar(@$d)-1];
	}
	$level_counts->{$id}->{$db->key2taxa($taxa->[scalar(@$taxa)-1])} = $d->[scalar(@$d)-1];
      }
    }
  }
  elsif (dataset_is_metabolic($desc)){
    foreach my $id (keys(%$data)) {
      my $db = $self->data("mgdb_$id");
      push @$all_data, @{$data->{$id}->{data}};
      foreach my $d (@{$data->{$id}->{data}}) {
	my $taxonomy = $d->[3];
	my $top_level = ($db->key2taxa($d->[0]) || 'Unclassified');
	my $second_level = ($db->key2taxa($d->[1]) || 'Unclassified');
	my $third_level = $db->key2taxa($d->[2]);
	$level_counts->{$id}->{$top_level} += $d->[scalar(@$d)-1];
	$level_counts->{$id}->{$top_level . '~' . $second_level} += $d->[scalar(@$d)-1];
	$level_counts->{$id}->{$top_level . '~' . $second_level . '~' . $third_level} += $d->[scalar(@$d)-1];
      }
    }
  }
  else {
    die "Unknown dataset in ".__PACKAGE__.": $dataset";
  }
  
  # build hash over all data samples
  my $join = {};
  my $i = $class_cols; 
  my $vennData = {};
  #  my $levels={};
  my $seen_taxa={};

  foreach my $id (keys(%$data)) {
    # total count of matches
    my $total = 0;
    map { $total += $_->[ scalar(@$_)-1 ] } @{$data->{$id}->{data}};
    $data->{$id}->{total} = $total;
    
    # start the group data for the venn Diagram
    my $groupData = {};
    for (my $group=0;$group< $class_cols;$group++){
      push @{$groupData->{$group}}, $id;
    }

    my (@send_array, $seen_row);
    
    # read all data from each sample
    my $array = [];
    push @$array, @$all_data;
    
    foreach my $d (@$array){
      my $db = $self->data("mgdb_$id");
      
      # get the classification
      my @c; my $key; my $taxonomy; my $rank;
      if (dataset_is_phylo($desc)) {
	
	$taxonomy = $d->[0];
	my $taxa = $db->split_taxstr($taxonomy);
	next if ($seen_row->{$db->key2taxa($taxa->[scalar(@$taxa)-1])});
	$seen_row->{$db->key2taxa($taxa->[scalar(@$taxa)-1])}++;
	
	$rank = scalar(@$taxa) - 2;
	push @c, $db->key2taxa($taxa->[0]), 
	  $db->key2taxa($taxa->[1]), 
	  $db->key2taxa($taxa->[2]),
          $db->key2taxa($taxa->[3]),
	  $db->key2taxa($taxa->[scalar(@$taxa)-1]);
	
	$key = join(',', @c);
	@send_array = @c;

#	my $parent='Root';
#	foreach my $l (@$taxa){
#	  push(@{$levels->{$parent}->{children}}, $db->key2taxa($l));
#	  $levels->{$parent}->{count}++;
#	  $parent = $db->key2taxa($l);
#	}
	
      }
      elsif (dataset_is_metabolic($desc)) {
	
	$taxonomy = $d->[3];

	next if ($seen_row->{$db->key2taxa($d->[2])});
	$seen_row->{$db->key2taxa($d->[2])}++;

	$rank = 2;
	push @c, ($db->key2taxa($d->[0]) || 'Unclassified'), 
	   ($db->key2taxa($d->[1]) || 'Unclassified'), 
	   $db->key2taxa($d->[2]);

	@send_array = ($c[0], $c[0].'~'.$c[1], join('~', @c));
	
#	@c=();
#        push @c, {'data' => ($db->key2taxa($d->[0]) || 'Unclassified'), 'highlight' => '#FFFFFF'},
#    	   {'data' => ($db->key2taxa($d->[1]) || 'Unclassified'), 'highlight' => '#FFFFFF'},
#	   {'data' => $db->key2taxa($d->[2]), 'highlight' => '#FFFFFF'};

	$key = join(',', @c);
	
      }
      else {
	die "Unknown dataset in ".__PACKAGE__.": $dataset";
      }
      
      # init join hash for that key
      # get the count
      unless (exists($join->{$key})) {
	$join->{$key} = [];
	push @{$join->{$key}}, @c;
      }

      push @{$join->{$key}}, &load_count_cells(\@send_array, $level_counts, $id,$total,$seen_taxa);
      
      # write in the stats for the initial taxonomy levels (domain, phyla, etc)
      for (my $l=0;$l<$class_cols;$l++){
	# get the count
	my $col_num = scalar (@{$join->{$key}}) - (($class_cols*2)-($l*2)) +1;
	my $absolute_score = $join->{$key}->[$col_num];
	next if ($absolute_score <= 0);
	my $score = sprintf("%.4f",$absolute_score/$total);
	my $base_link = "?page=MetagenomeSubset&".$url_params->{$id}."&get=".uri_escape( $taxonomy );
	
	my $mult = $l*2;
	$join->{$key}->[$col_num-1] = { 'data' => '<a href="' . $base_link . '&rank=' . $l . '">' . $score . '</a>'};
	$join->{$key}->[$col_num] = { 'data' => '<a href="' . $base_link . '&rank=' . $l . '">' . $absolute_score . '</a>'};

	# gather the data for the venn diagram
#	push (@$groupData,  $c[scalar(@c) - 1]);
	$linked_columns->{$l}->{$id} = $col_num;
	push @{$groupData->{$l}}, $c[$l] ;
	
	# apply colouring
	if ($self->app->cgi->param('colouring') and $absolute_score) {
	  my $c = ceil( ($absolute_score*$self->app->cgi->param('groups'))/($total*$self->app->cgi->param('effective_max')) );
	  $c = $self->app->cgi->param('groups') if ($c > $self->app->cgi->param('groups'));
	  $join->{$key}->[$col_num-1]->{highlight} = 'rgb('.join(',',@{WebColors::get_palette('vitamins')->[$c-1]}).')';
	  $join->{$key}->[$col_num]->{highlight} = 'rgb('.join(',',@{WebColors::get_palette('vitamins')->[$c-1]}).')';
	}
      }
    }
    for (my $group=0;$group<$class_cols;$group++){
      push @{$vennData->{$group}}, $groupData->{$group};
    }
  }

  # transform to array of array expected by table component
  my $table_data = [];
  foreach my $key (sort(keys(%$join))) {
    push @$table_data, $join->{$key};
  }

  # create table
  my $table = $self->application->component('MGTable');
  $table->show_export_button({strip_html => 1, hide_invisible_columns => 1});
#  $table->show_clear_filter_button(1);
  if (scalar(@$table_data) > 50) {
    $table->show_top_browse(1);
    $table->show_bottom_browse(1);
    $table->items_per_page(50);
    $table->show_select_items_per_page(1);
  }
  $table->columns($columns);
  $table->data($table_data);

  my $html;

  # create the Venn Diagram figure for each stat level
  my $vennDiagrams = {};
  for (my $group=0;$group<$class_cols;$group++){
    $self->application->register_component('VennDiagram', 'metagenome' . $group);
    my $vennD = $self->application->component('metagenome' . $group);
    $vennD->width(400);
    $vennD->height(400);
    $vennD->linked_component($table);
    $vennD->linked_columns($linked_columns->{$group});
    $vennD->data($vennData->{$group});
    my $visible = "";
    if ($group+1 == 2){
      $visible .= "style='visibility:visible;display:block'";
    }
    else{
      $visible .= "style='visibility:hidden;display:none;'";      
    }
    $html .= qq~<div name='venn_~ . ($group+1) . qq~' id='venn_~ . ($group+1) . qq~' $visible>~;
    $html .= $vennD->output() if (defined $vennD->output);
    $html .= qq~</div>~;
  }
  my $cgi = $self->application->cgi;
  
  $html .= "<div id='select_box'><table>";
  my $bg_colors = {'1'=>[230, 230, 250], '2'=>[255, 228, 225], '3'=>[240, 230, 140]};
  my $colorcount = 1;
  foreach my $id (keys(%$data)) {
      if (defined $bg_colors->{$colorcount}){
	  $html .= "<tr><th style='background-color:rgb(" . join(",", @{$bg_colors->{$colorcount}}) . ")'>" . $job_description->{$id} . " ($id)</th><td><em>Found ".$data->{$id}->{total}." matches in ".
	  scalar(@{$data->{$id}->{data}})." " . $labels->{$dataset} . " classifications.</td></tr>";
      }
      else{
	  $html .= "<tr><th>" . $job_description->{$id} . " ($id)</th><td><em>Found ".$data->{$id}->{total}." matches in ".
	  scalar(@{$data->{$id}->{data}})." " . $labels->{$dataset} . " classifications.</td></tr>";
      }
      $colorcount++;
  }
  $html .= "<tr><th>Color key:</th><td>".
    $self->create_color_code($self->app->cgi->param('groups'), $self->app->cgi->param('effective_max')).'</td></tr>'
      if ($self->app->cgi->param('colouring'));


  # create a help button for the table statistics
  $self->application->register_component('HelpLink', 'SelectHelp');
  my $selectHelp = $self->application->component('SelectHelp');
  $selectHelp->hover_width(200);
  $selectHelp->disable_wiki_link(1);
  
  my ($checkbox_js, $select_labels, $select_values);
  if (dataset_is_phylo($desc)){
    $selectHelp->title('Metagenome Phylogeny Statistics');
    $selectHelp->text('Select on a phylogeny level to see the statistics of your metagenome against the database selected.');

    $select_labels = {1=>'Domain', 2=>'Level 2', 3=>'Level 3', 4=>'Level 4', 5=>'Organism Level' };
    $select_values = ['1','2','3','4','5'];
    $html .= "<tr><th>Select Taxonomy Level Display:</th>";
    $checkbox_js = qq~<label><input type='checkbox' name='display_absolute' id='display_absolute' onClick='javascript:display_org_toggle1();'><b>Display Absolute Values</b></label>~;
  }
  elsif (dataset_is_metabolic($desc)){
    $selectHelp->title('Metagenome Metabolic Statistics');
    $selectHelp->text('Select on a subsystem hierarchy level to see the statistics of your metagenome against the database selected.');
    $select_labels = {1=>'Subsystem Hierarchy 1', 2=>'Subsystem Hierarchy 2', 3=>'Subsystem'};
    $select_values = ['1','2','3'];
    $html .= "<tr><th>Select Subsystem Hierarchy Level to Display:</th>";
    $checkbox_js = qq~<label><input type='checkbox' name='display_absolute' id='display_absolute' onClick='javascript:display_org_toggle1("metabolic");'><b>Display Absolute Values</b></label>~;
  }
  $html .= "<td>" . $cgi->popup_menu(-name=> 'select_level',
				     -id=> 'select_level',
				     -labels=> $select_labels,
				     -values=> $select_values,
				     -onChange=>"javascript:set_clicked($class_cols);",
				     -default=> '2') . $selectHelp->output();; 
  $html .= "&nbsp;" x 10 . $checkbox_js;
  $html .= "</td></tr>";

  $html .= "</table></div><br>";

      
  $html .= $self->start_form('mg_select_level', {metagenome=>$metagenome});
  $html .= $cgi->button(-id=>'clear_all_filters', -class=>'button',
			-name=>'clear_all_filters',
			-value=>'clear all filters',
			-onClick=>'javascript:clear_table_filters(0,' . $class_cols . ');');
  $html .= $cgi->hidden(-id=>'last_clicked',
			-name=>'last_clicked',
			-value=>2);
  $html .= $cgi->hidden(-id=>'mg_selected_qty',
			-name=>'mg_selected_qty',
			-value=> scalar @$metagenome_selected);

=head3
  foreach my $taxa (keys %$levels){
      my  %saw;
      my @out = grep(!$saw{$_}++, @{$levels->{$taxa}->{children}});
      @{$levels->{$taxa}->{children}} = @out;

      $html .= $cgi->hidden(-name  => $taxa,
			    -id => $taxa,
			    -value => join ("~", sort @out));
       $html .= $cgi->hidden(-name  => $taxa . '_count',
			     -id => $taxa . '_count',
			     -value => $levels->{$taxa}->{count});
  }

  if (dataset_is_phylo($desc)){
      #my $org_select_html = $self->application->component('SelectLevelAjax')->output();
      my $labels = {1=>'Domain', 2=>'Level 2', 3=>'Level 3', 4=>'Level 4', 5=>'Organism Level' };
      my $org_select_html = "<br><div id='select_div0'><table><tr>";
      $org_select_html .= "<th>Select Taxonomy Level Display:</th>";
      $org_select_html .= "<td>" . $cgi->popup_menu(-name=> 'select_level',
						    -id=> 'select_level',
						    -labels=> $labels,
						    -values=> ['1','2','3','4','5'],
						    -onChange=>"javascript:set_clicked();",
						    -default=> '1') . "</td></tr></table></div>"; 
      $org_select_html .= "<br><div id='select_div'><table><tr>";
      $org_select_html .= "<th></th><th>Domain</th><th>Level 2</th><th>Level 3</th><th>Level 4</th><th>Organisms Level</th></tr>";
      $org_select_html .= "<td>" . $cgi->scrolling_list(-name => 'level1',
							-id => 'level1',
							-values => ['Root'],
							-size => 5,
							-default => 'Root',
							-style => 'width:150px;font-size:90%;',
							-onClick => "javascript:set_clicked(1);",
							-labels => {'Root' => 'Root'}) . "</td>";
      
      my $list_values = {};
      foreach my $member (@{$levels->{'Root'}->{children}}){
	  $list_values->{$member} = $member . " (" . $levels->{$member}->{count} . ")"; 
      }
      
      $org_select_html .= "<td>" .  $cgi->scrolling_list(-name => 'level2',
							 -id => 'level2',
							 -values => $levels->{'Root'}->{children},
							 -size => 5,
							 -multiple => 1,
							 -style => 'width:150px;font-size:90%;',
							 -labels => $list_values,
							 -onChange => "javascript:set_clicked(2);") .
							     "</td>";
      
      $org_select_html .= "<td>" .  $cgi->scrolling_list(-name => 'level3',
							 -id => 'level3',
							 -values => [],
							 -multiple => 1,
							 -size => 5,
							 -style => 'width:150px;font-size:90%;',
							 -labels => {},
							 -onChange => "javascript:set_clicked(3);") .
							     "</td>";
      
      $org_select_html .= "<td>" .  $cgi->scrolling_list(-name => 'level4',
							 -id => 'level4',
							 -values => [],
							 -multiple => 1,
							 -size => 5,
							 -style => 'width:150px;font-size:90%;',
							 -labels => {},
							 -onChange => "javascript:set_clicked(4);") .
							     "</td>";
      
      $org_select_html .= "<td>" .  $cgi->scrolling_list(-name => 'level5',
							 -id => 'level5',
							 -values => [],
							 -multiple => 1,
							 -size => 5,
							 -style => 'width:150px;font-size:90%;',
							 -labels => {}).
							     "</td>";

      $org_select_html .= "<td>" .  $cgi->scrolling_list(-name => 'level6',
							 -id => 'level6',
							 -values => [],
							 -multiple => 1,
							 -size => 5,
							 -style => 'width:150px;font-size:90%;',
							 -labels => {}).
							     "</td>";

      
      $org_select_html .= qq~</tr></table></div><br><input type='checkbox' name='display_org' id='display_org' onClick='javascript:display_org_toggle("display_org",~ . scalar @$metagenome_selected . qq~);'>Display Organism Level Column<br><br>~;
      $html .= $org_select_html;
  }
=cut
  $html .= $self->end_form();
  $html .= $table->output();
  $html .= "<p class='subscript'>Data generated in ".(time-$time)." seconds.</p>";
  
  return $html;

}


=item * B<create_color_code> (I<number_of_groups>, I<maximum>)

This method draws a horizontal bar with the color code. I<number_of_groups> is the 
number of colors. The value I<maximum> is used to write a key to the color legend.

=cut

sub create_color_code {
  my ($self, $groups, $max) = @_;

  # set graphic
  my $bar_height = 20;
  my $bar_width  = 50*$groups;
  my $group_width = $bar_width/$groups;

  # create the image
  my $img = WebGD->new($bar_width, $bar_height);
  my $white = $img->colorResolve(255,255,255);  
  my $black = $img->colorResolve(0,0,0);

  # draw the color code
  foreach (my $i=0; $i<$groups; $i++) {
    my $c = WebColors::get_palette('vitamins')->[$i];
    my $upper = ($i+1)*($max/$groups);
    $img->filledRectangle( $i*$group_width, 0,
			   $i*$group_width+$group_width, $bar_height, 
			   $img->colorResolve(@$c) 
			 );
    $img->string(GD::gdSmallFont, $i*$group_width+8, 3, sprintf("%.3f",$upper), $black);
  }

  return '<img src="'.$img->image_src.'">';
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


sub column_metadata{
    my ($self) = @_;
    my $column_metadata = {};
    my $desc = $self->data('dataset_desc');
    my $metagenome = $self->application->cgi->param('metagenome') || '';
    my $next_col;


=head3
    if ( ($desc) && (dataset_is_phylo($desc)) ){
	$column_metadata->{Domain} = {'value'=>'Domain',
				      'header' => { name => 'Domain', filter => 1, operator => 'combobox',
						    visible => 0, show_control => 1 },
				        'order' => 1,
				        'visible' => 1,
				        'group' => 'permanent'
					};
	$column_metadata->{level1} = {'value'=>'Taxa Level 1',
				      'header' => { name => '', filter => 1, operator => 'combobox',
						    sortable => 1, width => 150 },
				        'order' => 2,
				        'visible' => 1,
				        'group' => 'permanent'
					};
	$column_metadata->{level2} = {'value'=>'Taxa Level 2',
				      'header' => { name => '', filter => 1, operator => 'combobox',
						    width => 150 },
				        'order' => 3,
				        'visible' => 1,
				        'group' => 'permanent'
					};
	$column_metadata->{level3} = {'value'=>'Taxa Level 3',
				      'header' => { name => '', filter => 1, operator => 'combobox',
						    width => 150 },
				        'order' => 4,
				        'visible' => 1,
				        'group' => 'permanent'
					};
	$column_metadata->{organism} = {'value'=>'Organism',
					'header' => { name => 'Organism Name', filter => 1 },
					    'order' => 5,
					    'visible' => 1,
					'group' => 'permanent'};
	$next_col = 6;
    }
    elsif ( ($desc) && (dataset_is_metabolic($desc))){
	$column_metadata->{hierarchy1} = {'value'=>'Subsystem Hierarchy 1',
					  'header' => { name => 'Subsystem Hierarchy 1', filter => 1,
							operator => 'combobox', width => 150, sortable => 1 },
					        'order' => 1,
					        'visible' => 1,
					        'group' => 'permanent'
						};
	$column_metadata->{hierarchy2} = {'value'=>'Subsystem Hierarchy 1',
					  'header' => { name => 'Subsystem Hierarchy 2', filter => 1,
							width => 150  },
					        'order' => 2,
					        'visible' => 1,
					        'group' => 'permanent'
						};
	$column_metadata->{hierarchy3} = {'value'=>'Subsystem Hierarchy 1',
					  'header' => { name => 'Subsystem Name', filter => 1,
							sortable => 1,  width => 150  },
					        'order' => 3,
					        'visible' => 1,
					        'group' => 'permanent'
						};
	$next_col = 4;
    }
=cut  
  $next_col = 1;
    # add your metagenome to permanent and add the other possible metagenomes to the select listbox
    # check for available metagenomes
    my $rast = $self->application->data_handle('RAST');  
    my $available = {};
    my $org_seen;
    if (ref($rast)) {
	my $public_metagenomes = &get_public_metagenomes($self->app->dbmaster, $rast);
	foreach my $pmg (@$public_metagenomes) {
	    $column_metadata->{$pmg->[0]} = {'value' => 'Public - ' . $pmg->[1],
					     'header' => { name => $pmg->[0],
							         filter => 1,
							         operators => ['equal', 'unequal', 'less', 'more'],
							         sortable => 1,
							         width => 150,
							         tooltip => $pmg->[1] . '(' . $pmg->[0] . ')'
								 },
								 };
	    if ($pmg->[0] eq $metagenome){
		$column_metadata->{$pmg->[0]}->{order} = $next_col;
		$column_metadata->{$pmg->[0]}->{visible} = 1;
		$column_metadata->{$pmg->[0]}->{group} = 'permanent';
	    }
	    else{
		$column_metadata->{$pmg->[0]}->{visible} = 0;
		$column_metadata->{$pmg->[0]}->{group} = 'metagenomes';
	    }
	    $org_seen->{$pmg->[0]}++;
	}

	if ($self->application->session->user) {
      
	    my $mgs = $rast->Job->get_jobs_for_user($self->application->session->user, 'view', 1);
      
	    # build hash from all accessible metagenomes
	    foreach my $mg_job (@$mgs) {
		next if ($org_seen->{$mg_job->genome_id});
		$column_metadata->{$mg_job->genome_id} = {'value' => 'Private - ' . $mg_job->genome_name,
							  'header' => { name => $mg_job->genome_id,
									filter => 1,
									operators => ['equal', 'unequal', 'less', 'more'],
									sortable => 1,
									width => 150,
									tooltip => $mg_job->genome_name . '(' . $mg_job->genome_id . ')'
									},
									};
		if ( ($mg_job->metagenome) && ($mg_job->genome_id eq $metagenome) ) {
		    $column_metadata->{$mg_job->genome_id}->{order} = $next_col;
		    $column_metadata->{$mg_job->genome_id}->{visible} = 1;
		    $column_metadata->{$mg_job->genome_id}->{group} = 'permanent';
		}
		else{
		    $column_metadata->{$mg_job->genome_id}->{visible} = 0;
		    $column_metadata->{$mg_job->genome_id}->{group} = 'metagenomes';  
		}
	    }
	}
    }
    else {
    # no rast/user, no access to metagenomes
    }
  
    return $column_metadata;
}

sub load_count_cells{
  my ($taxas, $level_counts, $id, $total, $seen_taxa) = @_;

  my @cells;
  foreach my $tax (@$taxas){
    if ($level_counts->{$id}->{$tax}){
      my ($absolute_score,$score);
      if ($seen_taxa->{$id}->{$tax}){
	$absolute_score=-1; $score=-1;
      }
      else{
	$seen_taxa->{$id}->{$tax}++;
	$absolute_score = $level_counts->{$id}->{$tax};
	$score = sprintf("%.4f",$absolute_score/$total);
      }
      push (@cells, ($score, $absolute_score));
    }
    else{
      push (@cells, (0,0));
    }
  }
  return @cells;
}


sub require_javascript {
    return ["$FIG_Config::cgi_url/Html/VennDiagram.js"];
}


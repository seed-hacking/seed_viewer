
package SeedViewer::WebPage::TargetSearch;

# Overview
#
# The basic template of the page is the same as other SeedViewer pages with init and output
# subroutines.
#
# User's parameter selections (aka filters) and logical operators are 
# converted into a prioritized series of search strings to reduce the size of the search
# space as quickly as possible. 
#
# The add_results_table subroutine is called through ajax; within this subroutine the
# management of the columns to be displayed in the results table occurs, the subroutine 
# get_search_results is called and the results evaluated.
# 
# Within get_search_results the parameters are prioritized and sorted, the sub-searches are
# called, and the results table populated.
#
# There are approx 19 different sub-search subroutines. This is where the logical operators 
# are evaluated and pegs are added or filtered out of the results.
#
# The interface is controlled by the following subroutines with javascript: 
# add_search_box_js,add_search_spinner,remove_search_box_js,add_suffix_search_box_js.
#
# Notes: This page requires checkboxes_old.js which is checked into cvs under SeedViewer.
# The menu links to the TargetSearchDirections.pm page.

use URI::Escape;
use base qw( WebPage );
use strict;
use FIG;
use FIG_Config;
use Data::Dumper;
use DBI;
use DBMaster;
use ERDBFinder;
use Tracer;
use SFXlate;
use FigKernelPackages::Observation qw(get_objects);
use constant FOPS => { 1 => 'AND', 2 => 'OR', 3 => 'NOT'};
use constant DESCRIPTORS => {
    "Signal Peptide" =>
        { objects => '',
          filter => 'Feature(signal-peptide) <> ""' },
    "Transmembrane Domains" =>
        { objects => '',
          filter => 'Feature(transmembran-map) <> ""' },
    "Similar to Human Protein" => 
        { objects => '',
         filter => 'Feature(similar-to-human) = 1' },
    "EC Number or Function" =>
        { objects => '',
          filter => 'Feature(assignment) LIKE ?' },
    "Taxon ID" =>
        { objects => '',
          filter => 'Feature(id) LIKE ?' },
    "Subsystem" =>
        { objects => 'HasRoleInSubsystem',
          filter => 'HasRoleInSubsystem(to-link) = ?' },
    "PFAM ID" =>
        { objects => 'HasProperty Property',
          filter => 'Property(property-name) eq ?' },
    "FigID" =>
        { objects => '',
          filter => 'Feature(id) = ?' },
    "ID" =>
        { objects => 'HasAlias',
          filter => 'HasAlias(to-link) = ?' },
    "Lineage" =>
        { objects => 'HasFeature Genome',
          filter => 'Genome(taxonomy) LIKE ?' },
    "Molecular Weight" =>
        { objects => '',
          filter => 'Feature(molecular-weight) >= ? AND Feature(molecular-weight) <= ?' },
    "Isoelectric Point" =>
        { objects => '',
          filter => 'Feature(isoelectric-point) >= ? AND Feature(isoelectric-point) <= ?' },
    "Sequence Length" =>
        { objects => '',
          filter => 'Feature(sequence-length) >= ? AND Feature(sequence-length) <= ?' },
    "Cellular Location" =>
        { objects => 'IsPossiblePlaceFor',
          filter => 'IsPossiblePlaceFor(from-link) = ?' },
    };
my @MIKEPARMS = qw(fig cgi filter search_term lop pegs_to_save concat_or_results peg_param_hits);

sub init {
  my $self = shift;

  # set title
  $self->title('Protein Target Search');

  # register components
  $self->application->register_component('Table', 'ResultTable');
  $self->application->register_component('Info', 'Directions');
  $self->application->register_component('Ajax', 'ajax_part');

}

sub output {
  my ($self) = @_;
  my $cgi = $self->application->cgi;
  my $fig = $self->application->data_handle('FIG');

  my $state;
  my $ref;
  foreach my $key ($cgi->param) {
      $state->{$key} = $cgi->param($key);
  }

  my $content = "";

  $content .= &add_search_box_js();
  $content .= &add_search_spinner_js();
  $content .= &remove_search_box_js();
  $content .= &add_suffix_search_box_js();
  $content .= &add_global_variable_js();
 
  my $application = $self->application;

  my $field_1_values;
  my $field_1_labels;

  $content .= '<h3>Protein Target Search</h3>';
  $content .= "<div id='spinner_here'></div>";
  $content .= "<div id='rows_deleted_count_here'></div>";
  my $id = "first";
  $content .= $self->start_form($id,$state);
  $content .= "<table name='search_table' id='search_table_1'><tr name='row_div' id='row_div_1'><td>";
  $content .= "<SELECT NAME='logic_operator1'><OPTION SELECTED>AND<OPTION>OR<OPTION>NOT</SELECT>";
  $content .= "<SELECT NAME='Filter1' ID='Filter1' onChange='add_suffix_search_box(1);'>";
  $content .= "<OPTION SELECTED value='Select Parameter'>Select Parameter</OPTION>";
  $content .= "<OPTION value='Cellular Location'>Cellular Location</OPTION>";
  #$content .= "<OPTION value='Cellular Location1'>Cellular Location1</OPTION>";
  $content .= "<OPTION value='Conserved Neighborhood'>Conserved Neighborhood</OPTION>";
  $content .= "<OPTION value='EC Number or Function'>EC Number or Function</OPTION>";
  #leaving out for now
  #$content .= "<OPTION value='Disease'>Organism, Disease caused by</OPTION>";
  $content .= "<OPTION value='ID'>ID, any gene/protein identifier</OPTION>";
  $content .= "<OPTION value='ID'>ID, ASAP</OPTION>";
  $content .= "<OPTION value='ID'>ID, JGI</OPTION>";
  $content .= "<OPTION value='ID'>ID, KEGG</OPTION>";
  $content .= "<OPTION value='ID'>ID, NCBI</OPTION>";
  $content .= "<OPTION value='ID'>ID, PIR</OPTION>";
  $content .= "<OPTION value='ID'>ID, RefSeq</OPTION>";
  $content .= "<OPTION value='ID'>ID, SwissProt</OPTION>";
  $content .= "<OPTION value='ID'>ID, TIGR</OPTION>";
  $content .= "<OPTION value='ID'>ID, TrEMBL</OPTION>";
  $content .= "<OPTION value='ID'>ID, UniProt</OPTION>";
  $content .= "<OPTION value='Isoelectric Point'>Isoelectric Point</OPTION>";
  $content .= "<OPTION value= 'Molecular Weight'>Molecular Weight</OPTION>";
  $content .= "<OPTION value='Endospores'>Organism, Endospore Production</OPTION>";
  $content .= "<OPTION value='GC_Content'>Organism, GC Content of</OPTION>";
  $content .= "<OPTION value='Gram_Stain'>Organism, Gram Stain of</OPTION>";
  $content .= "<OPTION value='Habitat'>Organism, Habitat of</OPTION>";
  $content .= "<OPTION value='Lineage'>Organism, Lineage</OPTION>";
  $content .= "<OPTION value='Motility'>Organism, Motility of</OPTION>";
  $content .= "<OPTION value='Organism Name'>Organism, Name</OPTION>";
  $content .= "<OPTION value='Oxygen_Requirement'>Organism, Oxygen Requirement of</OPTION>";
  $content .= "<OPTION value='Optimal_Temperature'>Organism, Optimal Temperature of</OPTION>";
  $content .= "<OPTION value='Pathogenic'>Organism, Pathogenic</OPTION>";
  $content .= "<OPTION value='Pathogenic_In'>Organism, Host of Pathogenic</OPTION>";
  #$content .= "<OPTION value='Shape'>Organism, Shape of</OPTION>";
  $content .= "<OPTION value='Salinity'>Organism, Salinity of</OPTION>";
  $content .= "<OPTION value='Temperature_Range'>Organism, Temperature Range of</OPTION>";
  $content .= "<OPTION value='Taxon ID'>Organism, Taxon ID</OPTION>";
  $content .= "<OPTION value='PatScan Sequence, AA'>PatScan Sequence, AA</OPTION>";
  $content .= "<OPTION value='PatScan Sequence, DNA'>PatScan Sequence, DNA</OPTION>";
  $content .= "<OPTION value='PFAM ID'>PFAM ID</OPTION>";
  $content .= "<OPTION value='PFAM Name'>PFAM Name</OPTION>";
  $content .= "<OPTION value='Selected Amino Acid Content'>Selected Amino Acid Content</OPTION>";
  $content .= "<OPTION value='Sequence Length'>Sequence Length</OPTION>";
  $content .= "<OPTION value='Signal Peptide'>Signal Peptide</OPTION>";
  $content .= "<OPTION value='Similar to Human Protein'>Similar to Human Protein</OPTION>";
  $content .= "<OPTION value='Subsystem'>Subsystem</OPTION>";
  $content .= "<OPTION value='Transmembrane Domains'>Transmembrane Domains</OPTION>";
  
  $content .= "</SELECT>";
  $content .= '</td>';
  $content .= '</tr>';
  $content .= '</table>';
  $content .= "<table style='width: 800px;'><tr><td><input type='button' class='button' value='+' onClick='add_search_box();'></td><td><input class='button' type='button' name='Search' value='Search' onClick='javascript:execute_ajax(\"add_results_table\", \"ajax_target\", \"first\", \"Processing...\", 0);'></td></tr></table>";
  $content .= "<script>function goto_result () { window.top.location = '#result_table'; }</script>";
  $content .= $self->end_form;
  
  $content .= "<br>";
  $content .= "<br>";
  $content .= $self->start_form('reset_form');
  $content .= "<input class='button' type='button' value='reset form' onclick='document.forms.reset_form.submit();'>";
  $content .= $self->end_form();
  $content .= $self->start_form('abort');
  $content .= "<input class='button' type='button' value='kill search' onclick='abort_requests()'>";
  $content .= $self->end_form();
  $content .= "<a name='result_table' /><div id='ajax_target'></div>";
  $content .= $application->component('ajax_part')->output();

  Trace("Ajax finished") if T(3);
  return $content;
}

sub add_results_table {
   
    my ($self) = @_;
    my $application = $self->application();
    my $cgi = $self->application->cgi;
    my $fig = $self->application->data_handle('FIG');
    my $sfx = $fig->sprout;
    my $content;

    my %search_parameter_columns;
    foreach my $key ($cgi->param){
	if($key =~/^Filt.*(\d+)$/){
	    my $i = $1;
	    my $filter_number = "Filter".$i;
	    my $filter = $cgi->param($filter_number);
	    if(!$filter){next;}
            #the search_parameter_columns hash keeps track of selected parameters to
            #automatically add their respective columns to the results table.
	    if($filter eq "Subsystem"){ $search_parameter_columns{'subsystem_22'} = 1;}  
	    elsif($filter eq "Lineage"){ $search_parameter_columns{'taxonomy_24'} = 1;}
	    elsif($filter eq "Conserved Neighborhood"){$search_parameter_columns{'conserved_neighborhood_7'} = 1;} 
	    elsif($filter eq "PFAM ID"){ $search_parameter_columns{'pfam_domains_16'} = 1;}
	    elsif($filter eq "PFAM Name"){$search_parameter_columns{'pfam_domains_16'} = 1;}
	    elsif($filter eq "Molecular Weight"){ $search_parameter_columns{'molecular_weight_12'} = 1;}
	    elsif($filter eq "Isoelectric Point"){ $search_parameter_columns{'isoelectric_weight_9'} = 1;}
	    elsif($filter eq "Sequence Length"){ $search_parameter_columns{'sequence_length_19'} = 1;}
	    elsif($filter eq "Taxon ID"){ $search_parameter_columns{'taxonomy_24'} = 1;}
	    elsif($filter eq "Cellular Location"){$search_parameter_columns{'cellular_location_6'} = 1;}
	    elsif($filter =~/Cellular Location/){$search_parameter_columns{'cellular_location_6'} = 1;}
	    elsif($filter eq "Signal Peptide"){ $search_parameter_columns{'signal_peptide_20'} = 1;}
	    elsif($filter eq "Transmembrane Domains"){$search_parameter_columns{'transmembrane_domains_26'} = 1;}
	    elsif($filter eq "PatScan Sequence, AA"){ $search_parameter_columns{'patscan_hit_aa_14'} = 1;}
	    elsif($filter eq "PatScan Sequence, DNA"){$search_parameter_columns{'patscan_hit_dna_15'} = 1;}
	    #elsif($filter eq "Selected Amino Acid Content"){$search_parameter_columns{} = 1;}
	    elsif($filter eq "GC_Content"){$search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Gram_Stain"){$search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Shape"){$search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Arrangement"){$search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Endospores"){$search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Motility"){$search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Salinity"){$search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Oxygen_Requirement"){ $search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Habitat"){ $search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Temperature_Range"){ $search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Optimal_Temperature"){ $search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Pathogenic"){ $search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Pathogenic_In"){ $search_parameter_columns{'z_phenotypes_29'} = 1;}
	    #elsif($filter eq "Disease"){ $search_parameter_columns{'z_phenotypes_29'} = 1;}
	    elsif($filter eq "Similar to Human Protein"){ $search_parameter_columns{'similar_to_human_21'} = 1;}
	}
    }

        my %scroll_list = ( 'asap_id_5' => 'ASAP id',
			'cellular_location_6' => 'Cellular Location',
			'conserved_neighborhood_7' => 'Conserved Neighborhood',
			'evidence_8' => 'Evidence Code',
			'isoelectric_9' => 'Isoelectric Point',
			'jgi_id_10' => 'JGI id',
			'kegg_id_11' => 'KEGG id',
			'molecular_weight_12' => 'Molecular Weight', 
			'ncbi_id_13'  => 'NCBI id',
			'patscan_hit_aa_14'  => 'PatScan Hit, AA',
			'patscan_hit_dna_15'  => 'PatScan Hit, DNA',
			'pfam_domains_16' => 'PFAM Domains',
			'pir_id_17' => 'PIR id',
			'refseq_id_18' => 'RefSeq id',
			'sequence_length_19' => 'Sequence Length',
			'signal_peptide_20' => 'Signal Peptide',
			'similar_to_human_21' => 'Similar to Human Protein',
			'subsystem_22' => 'Subsystems',
			'swissprot_id_23' => 'SwissProt id',
			'taxonomy_24' => 'Taxonomy Lineage',
			'tigr_id_25' => 'TIGR id',
			'transmembrane_domains_26' => 'Transmembrane Domains',
			'trembl_id_27' => 'TrEMBL id',
			'uniprot_id_28' => 'UniProt id',
			'z_phenotypes_29' => 'Phenotypes',
			);

 
    my @sim_list_values = sort keys %scroll_list;
    my (@good_list) = ();

    #comment line below to stop automatically adding columns for selected parameters to results table
    push(@good_list,keys(%search_parameter_columns));
    
    my ($in_list, $out_list) = &get_incolumns(\@good_list, \%scroll_list);
    
    my $result_table = $self->application->component('ResultTable');
    
    my $result_table_id = $result_table->id();
    
    $content .= qq"<table border=0 align=center cellpadding=10><tr bgcolor=#EAEAEA><td>"; #outside table (gray colored table)
    $content .= qq"<table border=0 align=center cellpadding=0><tr<td>";
    $content .= qq"<table border=0 align=center><caption>Additional columns to be shown:</caption><br><tr><td rowspan=2>Columns not in display:<br>";
    
    $content .= $cgi->scrolling_list(-name=>'sim_display_list_out',
				     -id => 'sim_display_list_out',
				     -values=>$out_list,
				     -size=>5,
				     -multiple=>'true',
				     -class=>'listbox',
				     -labels=>\%scroll_list);
    $content .= qq"</td><td><br><br>";
	    
    $content .= $cgi->submit(-name => 'add_list',
			     -onClick => "moveOptionsRight('sim_display_list_out','sim_display_list_in','$result_table_id')",
			     -value => '==>');
    
    $content .= qq"</td><td rowspan=2>Columns in display:<br>";
    $content .= $cgi->scrolling_list(-name=>'sim_display_list_in',
				     -id => 'sim_display_list_in',
				     -values=>$in_list,
				     -size=>5,
				     -multiple=>'true',
				     -class=>'listbox',
				     -labels=>\%scroll_list);
    
    $content .= qq"</td></tr><tr><td>";
    
    $content .= $cgi->submit(-name => 'remove_list',
			     -onClick => "moveOptionsLeft('sim_display_list_in','sim_display_list_out','$result_table_id')",
			     -value => '<==');
    
    $content .= qq"</td></tr></table>";
    $content .= qq"</td></tr><tr><td align=right>";
    $content .= qq"</td></tr></table></td></tr></table>";
 
    $content .= $cgi->hidden(-name    => 'selected_columns',-id => 'selected_columns');
   
    my @in_columns;
    my $permanent_columns = [{ 'name' => 'Parameters Hit', 'filter' => 1}, { 'name' => 'FIG ID', 'sortable'=> 1,'filter' => 1} , {'name' => 'Organism', 'sortable'=> 1, 'filter' => 1, 'operators' => ['like','unlike']} , { 'name' => 'Aliases', 'sortable'=> 1,'filter' => 1, 'operators' => ['like','unlike']} , {'name' => 'Function', 'sortable'=> 1,'filter' => 1, 'operators' => ['like','unlike']}];

    my @permanent_column_names = ("Parameters Hit","FIG ID","Organism","Aliases","Function");
    
    push(@in_columns, sort keys %scroll_list);
    
    my $columns_to_be_shown = $permanent_columns;
    foreach my $cols (@in_columns){
	if($search_parameter_columns{$cols}){
	    push (@$columns_to_be_shown, {'name' => $scroll_list{$cols}, 'visible' => 1,'sortable'=> 1,'filter' => 1});
	}
	elsif (grep (/$cols/, keys %scroll_list)){
	    push (@$columns_to_be_shown, {'name' => $scroll_list{$cols}, 'visible' => 0,'sortable'=> 1,'filter' => 1});
	}
	else{
	    push (@$columns_to_be_shown, {'name' => $scroll_list{$cols}, 'visible' => 1,'sortable'=> 1,'filter' => 1});
	}
    }
	  
    $result_table->columns ($columns_to_be_shown);
    
    $result_table->show_top_browse(1);
    $result_table->show_bottom_browse(1);
    $result_table->items_per_page(50);
    $result_table->width(950);
    $result_table->show_select_items_per_page(1);
    $result_table->show_export_button({'title' => 'Export Table', 'strip_html' => 1} );

    Trace("Starting target search ...") if T(3);
    my ($data,$search_status) = &get_search_results($fig, $cgi,\%scroll_list);
    Trace("Search results returned ...") if T(3);
    if($search_status =~/MAX_FAILURE:(\d+)/){$content .= "<h3> Over $1 hits found. Please refine search and try again. </h3>";}
    elsif($search_status =~/NOT_FAILED/){$content .= "<h3> This search did not match any proteins. Please try again after modifying/removing search parameter(s) with logical NOT operator(s).</h3>";}
    elsif($search_status =~/FAILED/){$content .= "<h3> This search did not match any proteins. Please try again after modifying/removing search parameter(s) with logical AND operator(s).</h3>";}
    elsif($search_status =~/OR_FAILURE/){$content .= "<h3>This search did not match any proteins. Please try again after modifying/removing search parameter(s) with logical OR operator(s).</h3>";}
    elsif($search_status =~/Search Rejected/){$content .= "<h3>This search is too broad. It is unlikely to return less than 10K hits before timing out. Please refine your search. Follow the link in the menu to the Tips page for help.</h3>";}
    elsif($data){
	my $hit_number = scalar(@$data);
	$content .= "<h4> Hits: $hit_number </h4>";
	$result_table->data($data);
	$content .= $result_table->output();
	Trace("Finished building results table") if T(3);
    }
    else{
	$content .= "<h4> No Hits Found </4>";
    }

    return $content;
}

sub get_incolumns {
    my ($in_cols, $columns) = @_;
    
    my (@out_cols);
    my @all_cols = sort keys %$columns;
    foreach my $col (@all_cols){
	push (@out_cols, $col) if (! grep (/$col/, @$in_cols));
    }
    return ($in_cols, \@out_cols);    
}


sub get_search_results{

    my($fig,$cgi,$scroll_list) = @_;
    my $pegs_to_save;
    my %returned_or_pegs;
    my $data;
    my $search_status;
    my $search_summary;
    my $pegs_returned;
    my $peg_param_hits;
    my $patscan_hits_aa;
    my $patscan_hits_dna;
    my $filter_thru_or_results = 0;
    my $or_success = 1;

    #i is filter counter
    my $i;
    my @search_strings;
    my $search_string;
    #concat_or_results will only be left set to true when all logical operators are ORs
    #when concat_or_results are set to true all hits from each filter's search are saved and no hits are filtered out
    my $concat_or_results = 1;    
  
    foreach my $key ($cgi->param){
	if($key =~/^Filter(\d+)$/){
	    $i = $1;
	    my $filter_number = "Filter".$i;
	    my $filter = $cgi->param($filter_number);
	    if(!$filter){next;}
	    my $lop_number = "logic_operator".$i;
	    my $lop;
	    $lop = $cgi->param($lop_number);
	    my $search_term_number = "search_term".$i;
	    my $search_term = $cgi->param($search_term_number);

	    #to optimize the search filters that will reduce the search space fastest are performed first and assigned a lower numbered prefix 
	    my $filter_prefix;
	    if($lop eq "AND"){
		if($filter eq "ID"){ $filter_prefix = "100_";}
		elsif($filter eq "EC Number or Function"){$filter_prefix = "110_";}
		elsif($filter eq "Taxon ID"){$filter_prefix = "120_";}
		elsif($filter eq "Subsystem"){$filter_prefix = "130_";}
		elsif($filter eq "PFAM ID"){$filter_prefix = "140_";}
		elsif($filter eq "PFAM Name"){$filter_prefix = "150_";}
		elsif($filter eq "Organism Name"){$filter_prefix = "160_";}
		elsif($filter eq "Lineage"){$filter_prefix = "161_";}
		elsif($filter eq "Conserved Neighborhood"){$filter_prefix = "162_";}
		elsif($filter =~/(Salinity|Temperature|GC|Gram_Stain|Habitat|Pathogenic|Shape|Oxygen|Motility)/){$filter_prefix = "170_";}
		elsif($filter =~/(Signal|Transmembrane)/){$filter_prefix = "180_";}
                else{$filter_prefix = "190_";}
		$concat_or_results = 0;
	    }
	    elsif($lop eq "OR"){
		if($filter eq "ID"){ $filter_prefix = "200_";}
		elsif($filter eq "EC Number or Function"){$filter_prefix = "210_";}
		elsif($filter eq "Taxon ID"){$filter_prefix = "220_";}
		elsif($filter eq "Subsystem"){$filter_prefix = "230_";}
		elsif($filter eq "PFAM ID"){$filter_prefix = "240_";}
		elsif($filter eq "PFAM Name"){$filter_prefix = "250_";}
		elsif($filter eq "Organism Name"){$filter_prefix = "260_";}
		elsif($filter eq "Lineage"){$filter_prefix = "261_";}
		elsif($filter eq "Conserved Neighborhood"){$filter_prefix = "262_";}
		elsif($filter =~/(Salinity|Temperature|GC|Gram_Stain|Habitat|Pathogenic|Shape|Oxygen|Motility)/){$filter_prefix = "270_";}
		elsif($filter =~/(Signal|Transmembrane)/){$filter_prefix = "280_";}
		else{$filter_prefix = "290_";}
		$or_success = 0;
		$filter_thru_or_results = 1;
	    }
	    else{
		$filter_prefix = "300_";
	    }

	    $filter = $filter_prefix.$filter;
	    
	    $search_string = $filter."XXX".$search_term;
	    push(@search_strings,$search_string);
	}
    }
     
    my @sorted = sort(@search_strings);
    my $counter = 1;
    my $lop;
    my $filter;

    my $feasible_search = 0;
    my @criteria = ();
    my $chash = DESCRIPTORS;
    my $critCount = 0;
    foreach my $string (@sorted){
	if($string =~/^1\d+_(ID|PFAM ID|PFAM Name|Subsystem|EC Number or Function|Taxon ID|Lineage)/){
	    $feasible_search = 1;
	}
        # Parse this criterion. A lot of fancy dancing is required to get
        # the parameters arranged correctly for ERDBFinder.
        if ($string =~ /^(\d)\d*_(.*?)XXX(.*)/) {
          my $op = FOPS->{$1};
          my $fieldName = $2;
          my $fieldParm = $3;
          if ($fieldName eq 'Taxon ID') {
            $fieldParm = "fig|$fieldParm.%";
          } elsif ($fieldName eq 'PFAM ID') {
            $fieldParm = "PFAM::$fieldParm";
          } elsif ($fieldName eq 'PFAM-Name') {
            my $sqlite_db = "/home/mkubal/Temp/Ontology/ontology.sqlite";
            my $ontology_dbmaster = DBMaster->new(-database => $sqlite_db, -backend => 'SQLite');
            my $dt_objs =  $ontology_dbmaster->pfam->get_objects( { 'term' => $fieldParm } );
            foreach my $dt_obj (@$dt_objs){
              $fieldParm = 'PFAM::' . $dt_obj->id(); 
            }
          } elsif ($fieldName eq 'Lineage') {
            $fieldParm = "%$fieldParm%";
          } elsif ($fieldName eq 'Cellular Location') {
            my $clparam = "FilterCL$critCount";
            Trace("Looking for cellular location in $clparam.") if T(3);
            $fieldParm = $cgi->param($clparam);
          } elsif ($fieldName eq 'EC Number or Function') {
            $fieldParm =~ s/\*/%/g;
          } elsif ($filter eq "Selected Amino Acid Content") {
            $fieldParm = cgi->param('FilterAAC');
          } elsif ($fieldName eq 'ID') {
            if ($fieldParm =~ /^fig/) {
                $fieldName = 'FigID';
            } elsif ($fieldParm =~ /^nmpdr(.+)/) {
                $fieldName = 'FigID';
                $fieldParm = "fig$1";
            }
          }
          push @criteria, [$op, $fieldName, split(/\s*,\s*/, $fieldParm)];
        }
        # Count this string.
        $critCount++;
    }
    Trace("Parsed criteria:\n" . Data::Dumper::Dumper(\@criteria)) if T(4);
    if(! $feasible_search){
	return($data,"Search Rejected");
    }
    my $ff = ERDBFinder->new($fig->sprout, 'Feature', $chash);
    # Find some features.
    my %featureHash = $ff->Find(\@criteria);
    Trace(scalar(keys %featureHash) . " features found by search.") if T(4);
    # We need to know if there are any OR-criteria. If there are, this gets
    # set to 1.
    my $or_found = 0;
    # We cache genomes in here.
    my %genomes;    
    # We now have a complete list of all the features we need. The next step
    # is to apply the remaining criteria to it. These will all be present in
    # the criterion list @criteria. The tricky part here is that some of
    # the criteria will be ORs. We'll mark the pegs found by the OR criteria
    # in the hash below. ANDs that do not survive will be deleted from %featureHash.
    my %orPegs;
    Trace("Features found: " . join(", ", sort keys %featureHash) . ".") if T(4);
    my $cellular_location_count = 0;
    foreach my $criterion (@criteria) {
	$cellular_location_count++;
        my ($operator, $fieldName, @parms) = $criterion;
        # Loop through the features, applying this criterion to each.
        for my $peg (grep { defined $featureHash{$_} } keys %featureHash) {
          # Determine whether or not this peg matches this criterion.
          my $matches = CheckCriterion($fieldName, \@parms, $featureHash{$peg}, \%genomes,
                                       $fig, $cgi);
          # Do we need to delete this PEG? We do if we're an AND and it does not match
          # or a NOT and it does match.
          if ($operator eq 'AND' && ! $matches || $operator eq 'NOT' && $matches) {
              # This is not a real delete, because I'm nervous about deleting while
              # looping, but it will prevent us from looking at this PEG again.
              $featureHash{$peg} = undef;
          } elsif ($operator eq 'OR') {
              # Here we have OR. Remember that fact.
              $or_found = 1;
              # Mark the peg in the or-hash if we matched.
              $orPegs{$peg} = 1 if $matches;
          }
        }
    }
    # Prune useless stuff out of the feature hash. This will be our
    # final list of pegs to keep. While we're at it, we'll also pull
    # in ant remaining genomes we need.
    my %table_pegs;
    for my $peg (keys %featureHash) {
      my $pegData = $featureHash{$peg};
      # $pegData is defined if we've satisfied all the ANDs and NOTs.
      # If there are any ORs, we also require that the peg be in orPegs.
      # So, we keep if (1) pegData is defined and (2a) there are no ORs, or
      # (2b) it's in orPegs.
      if (defined $pegData && (! $or_found || $orPegs{$peg})) {
        # Okay, we want to keep this one.
        $table_pegs{$peg} = $data;
        # We must insure that we have its genome data. Get its genome ID.
        my $genomeID = $fig->genome_of($peg);
        # Does it have embedded genome data?
        if ($data->HasValue('Genome(id)')) {
            # Yes it does. If we have never seen this genome before, we need
            # to save a pointer to it. We get away with this because if
            # an ERDBObject has an entity's ID in it, all the entity's
            # data is dragged in as well.
            if (! exists $genomes{$genomeID}) {
                $genomes{genomeID} = $data;
            }
        } else {
            # Save the genome ID in this feature's data.
            $data->AddValues('Genome(id)' => $genomeID);
            # Do we already have this genome's record in memory?
            if (! exists $genomes{$genomeID}) {
                # No. Read it from the database.
                $genomes{$genomeID} = $fig->sprout->GetEntity(Genome => $genomeID);
            }
        }
      }
    }
    # Release some RAM.
    undef %featureHash;
    # Okay, at this point, @criteria contains all the unprocessed criteria,
    # %table_pegs maps the ID of any probably-qualified peg to a Feature ERDBObject,
    # and %genomes maps the ID of any relevant genome to an ERDBObject containing
    # data for that genome.
    Trace("Finished evaluating filters") if T(3);
    
    if($or_found && ! %orPegs){
	$search_status = "OR_FAILURE";
	return ($data,$search_status);
	
    }
    elsif($search_status eq "FAILED"){
	return ($data,$search_status);
    }
    elsif($search_status eq "NOT_FAILED"){
	return ($data,$search_status);
    }
    elsif(scalar(keys(%table_pegs)) > 10000){
	my $count = scalar(keys(%table_pegs));
	$search_status = "MAX_FAILURE:$count\n";
	return ($data,$search_status);
    }
    elsif(scalar(keys(%table_pegs)) < 1){
	my $search_status = "NONE_FOUND";
	return ($data,$search_status);
    }
    else{
	Trace("SUCCESSFUL QUERY") if T(3);
	my @search_set = keys(%table_pegs);
	my %subsystem_column = &get_subsystems_column($fig, \@search_set);
	my %phenotype_column = &get_phenotype_column($fig, \@search_set);

	Trace("Calling get_peg_attributes_column") if T(3);
	my ($iso_column_ref,$location_column_ref,$mw_column_ref,$pfam_column_ref,$evidence_column_ref,$signal_peptide_ref,$transmembrane_ref,$similar_to_human_ref) = get_peg_attributes_column($fig, \@search_set);
	Trace("get_peg_attributes_column returned") if T(3);
	my $conserved_neighborhood_column_ref = &get_conserved_neighborhood_column($fig, \@search_set);
	my $sequence_length_column_ref = &get_sequence_length_column($fig, \@search_set);
	my %iso_column = %$iso_column_ref;
	my %location_column = %$location_column_ref;

	my %mw_column = %$mw_column_ref;
	my %pfam_column = %$pfam_column_ref;
	my %evidence_column = %$evidence_column_ref;
	my %conserved_neighborhood_column = %$conserved_neighborhood_column_ref;
	my %sequence_length_column = %$sequence_length_column_ref;
	my %signal_peptide_column = %$signal_peptide_ref;
	my %transmembrane_column = %$transmembrane_ref;
	my %similar_to_human_column = %$similar_to_human_ref;
        my @peg_list = keys %table_pegs;
        Trace(scalar(@peg_list) . " pegs found for table loop.") if T(3);
	foreach my $peg (@peg_list)
	{
	    my $function = $fig->function_of($peg);
	    my $genome = $fig->genome_of($peg);
	    my $gs = $fig->genus_species($genome);
	    my @aliases = $fig->feature_aliases($peg);
	    my $alias_string = join("<br>",@aliases);
	    my $gene_name = "none";
	    my $locus = "none";
	    foreach my $alias (@aliases){
		if($alias =~/^[a-z]{3}[A-Z]$/){$gene_name = $alias;}
		elsif($alias =~/^\w{1,3}\d+$/){$locus = $alias;}
	    }
	    
	    my $link = "<a href='http://www.nmpdr.org/FIG/wiki/rest.cgi/NmpdrPlugin/SeedViewer?feature=$peg;page=Annotation'>$peg</a>";
	    my $ref_param_hits = $$peg_param_hits{$peg};
	    my %unique_ph;
	    foreach my $ph (@$ref_param_hits){
		$unique_ph{$ph} = 1;
	    }
	    my $param_hits_string = join("<br>",keys(%unique_ph));
	    my $permanent_data = [$param_hits_string,$link,$gs,$alias_string,$function];
	    	    
	    my $all_aliases = $fig->feature_aliases_bulk([$peg]);

	    foreach my $col (sort keys %$scroll_list){
		if ($col =~ /subsystem/){
		    push(@$permanent_data,$subsystem_column{$peg});
		}
		elsif ($col =~ /conserved_neighborhood/){
		    push(@$permanent_data,$conserved_neighborhood_column{$peg});
		}
		elsif ($col =~ /sequence_length/){
		    push(@$permanent_data,$sequence_length_column{$peg});
		}
		elsif ($col =~ /evidence/){
		    push(@$permanent_data,$evidence_column{$peg});
		}
		elsif ($col =~ /isoelectric/){
		    push(@$permanent_data,$iso_column{$peg});
		}
		elsif ($col =~ /location/){
		    push(@$permanent_data,$location_column{$peg});
		}
		elsif ($col =~ /molecular_weight/){
		    push(@$permanent_data,$mw_column{$peg});
		}
		elsif ($col =~ /pfam_domains/){
		    push(@$permanent_data,$pfam_column{$peg});
		}
		elsif ($col =~ /phenotypes/){
		    push(@$permanent_data,$phenotype_column{$peg});
		}
		elsif ($col =~ /ncbi_id/){
                    if(!&get_prefer($cgi, $peg, 'NCBI', $all_aliases)){push(@$permanent_data,"&nbsp")}
		    else{push(@$permanent_data,&get_prefer($cgi, $peg, 'NCBI', $all_aliases));}
		}
		elsif ($col =~ /refseq_id/){
		    if(!&get_prefer($cgi, $peg, 'RefSeq', $all_aliases)){push(@$permanent_data,"&nbsp")}
		    else{push(@$permanent_data,&get_prefer($cgi, $peg, 'RefSeq', $all_aliases));}
		}
		elsif ($col =~ /swissprot_id/){
		    if(!&get_prefer($cgi, $peg, 'SwissProt', $all_aliases)){push(@$permanent_data,"&nbsp")}
		    else{push(@$permanent_data,&get_prefer($cgi, $peg, 'SwissProt', $all_aliases));}
		}
		elsif ($col =~ /uniprot_id/){
		    if(!&get_prefer($cgi, $peg, 'UniProt', $all_aliases)){push(@$permanent_data,"&nbsp")}
		    else{push(@$permanent_data,&get_prefer($cgi, $peg, 'UniProt', $all_aliases));}
		}
		elsif ($col =~ /tigr_id/){
                    if(!&get_prefer($cgi, $peg, 'TIGR', $all_aliases)){push(@$permanent_data,"&nbsp")}
		    else{push(@$permanent_data,&get_prefer($cgi, $peg, 'TIGR', $all_aliases));}
		}
		elsif ($col =~ /pir_id/){
		    if(!&get_prefer($cgi, $peg, 'PIR', $all_aliases)){push(@$permanent_data,"&nbsp")}
		    else{push(@$permanent_data,&get_prefer($cgi, $peg, 'PIR', $all_aliases));}
		}
		elsif ($col =~ /kegg_id/){
		    if(!&get_prefer($cgi, $peg, 'KEGG', $all_aliases)){push(@$permanent_data,"&nbsp")}
		    else{push(@$permanent_data,&get_prefer($cgi, $peg, 'KEGG', $all_aliases));}
		}
		elsif ($col =~ /trembl_id/){
		    if(!&get_prefer($cgi, $peg, 'TrEMBL', $all_aliases)){push(@$permanent_data,"&nbsp")}
		    else{push(@$permanent_data,&get_prefer($cgi, $peg, 'TrEMBL', $all_aliases));}
		}
		elsif ($col =~ /asap_id/){
                    if(!&get_prefer($cgi, $peg, 'ASAP', $all_aliases)){push(@$permanent_data,"&nbsp")}
		    else{push(@$permanent_data,&get_prefer($cgi, $peg, 'ASAP', $all_aliases));}
	        }
		elsif ($col =~ /jgi_id/){
		    if(!&get_prefer($cgi, $peg, 'JGI', $all_aliases)){push(@$permanent_data,"&nbsp")}
		    else{push(@$permanent_data,&get_prefer($cgi, $peg, 'JGI', $all_aliases));}
		}
		elsif ($col =~ /taxonomy/){
		    push(@$permanent_data,$fig->taxonomy_of($fig->genome_of($peg)));
		}
		elsif ($col =~ /transmembrane/){
		    push(@$permanent_data,$transmembrane_column{$peg});
		}
		elsif ($col =~ /signal_peptide/){
		    push(@$permanent_data,$signal_peptide_column{$peg});
		}
		elsif ($col =~ /similar_to_human/){
		    push(@$permanent_data,$similar_to_human_column{$peg});
		}
		elsif ($col =~ /patscan_hit_aa/){
		    my $ref= $$patscan_hits_aa{$peg};
                    if ($ref) {
                      my $match_string = join("<br>",@$ref);
                      if($match_string !~/at/){$match_string ="&nbsp";}
                      push(@$permanent_data,$match_string);
                    }
		}
		elsif ($col =~ /patscan_hit_dna/){
		    my $ref= $$patscan_hits_dna{$peg};
                    if ($ref) {
                      my $match_string = join("<br>",@$ref);
                      if($match_string !~/at/){$match_string ="&nbsp";}
                      push(@$permanent_data,$match_string);
                    }
		}
	    }
	    push(@$data,$permanent_data);
	}
        Trace("Returning search status $search_status.") if T(3);
        Trace(scalar(@$data) . " data items selected.") if T(3);
	return ($data,$search_status);
    }
}

sub do_index_search{
    my ($mikeThing) = @_;
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,
       $peg_param_hits) = map { $mikeThing->{$_} } @MIKEPARMS;
    
    #Trace("doing index search") if T(3);
    my $pegs_to_return; 
    my $ref;
    my $peg_index_data = [];

    if($search_term =~/fig\|\d+\.\d+\.peg\.\d+/){
	push(@$peg_index_data,$search_term);
    }
    
    my @outer_query = $fig->sprout->GetAll(['IsAliasOf'], "IsAliasOf(from-link) = ?", [$search_term], ['IsAliasOf(to-link)']);
    foreach my $oq (@outer_query){
	my ($to_link) =@$oq;
	push(@$peg_index_data,$to_link);
    }

    #Trace("search_index complete") if T(3);

    my $search_summary;
    if($pegs_to_save){
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    my %pegs_to_filter;
	    foreach my $peg (@$pegs_to_save){$pegs_to_filter{$peg} = 1;}
	    my %pegs_temp;
	    foreach my $peg (@$peg_index_data){
		$pegs_temp{$peg} = 1;
	    }
	    foreach my $peg (keys(%pegs_to_filter)){
		if($pegs_temp{$peg}){
		    push(@$pegs_to_return,$peg); 
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	elsif($lop eq "NOT"){
	    $search_summary = "FAILED";
	    my %pegs_to_filter;
	    foreach my $peg (@$pegs_to_save){$pegs_to_filter{$peg} = 1;}
	    my %pegs_temp;
	    foreach my $peg (@$peg_index_data){
		$pegs_temp{$peg} = 1;
	    }
	    foreach my $peg (keys(%pegs_to_filter)){
		if(! $pegs_temp{$peg}){push(@$pegs_to_return,$peg); $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	elsif($lop eq "OR"){
	    if(! $concat_or_results){
		my %pegs_to_filter;
		foreach my $peg (@$pegs_to_save){$pegs_to_filter{$peg} = 1;}
		my %pegs_temp;
		foreach my $peg (@$peg_index_data){
		    $pegs_temp{$peg} = 1;
		}
		foreach my $peg (keys(%pegs_to_filter)){
		    if($pegs_temp{$peg}){
			push(@$pegs_to_return,$peg); $search_summary = "OR_SUCCESS"; 
			my $param_hit = "$filter:$search_term";
			if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
			else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
	    else{
		push(@$pegs_to_return,@$pegs_to_save);
		foreach my $peg (@$peg_index_data){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "OR_SUCCESS";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
    }
    else{
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    foreach my $peg (@$peg_index_data){
	        push(@$pegs_to_return,$peg);
		$search_summary = "GOOD";
		my $param_hit = "$filter:$search_term";
		if($$peg_param_hits{$peg}){
		    $ref = $$peg_param_hits{$peg};
		    push(@$ref,$param_hit);
		}
		else{
		    $$peg_param_hits{$peg} = [$param_hit];
		}
	    }
	}
	elsif($lop eq "OR"){
	    foreach my $peg (@$peg_index_data){
	        push(@$pegs_to_return,$peg);
		$search_summary = "OR_SUCCESS";
		my $param_hit = "$filter:$search_term";
		if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
	else{
	    $search_summary = "NOT_FAILED";
	}
    }
    
    #Trace("completing index search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_function_search{
    my ($mikeThing) = @_;
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,
       $peg_param_hits) = map { $mikeThing->{$_} } @MIKEPARMS;
    #Trace("function search called") if T(3);
    my $pegs_to_return; 
    my $peg_index_data = [];
    my $ref;
    if($search_term =~/\*/){
        my $like_term = $search_term;
	$like_term =~ s/\*/%/g;
	my @outer_query = $fig->sprout->GetAll(['Feature'], "Feature(assignment) LIKE ?", [$like_term], ['Feature(id)']);
	foreach my $oq (@outer_query){
	    my ($peg) =@$oq;
	    if($peg =~/peg/){
		push(@$peg_index_data,$peg);
	    }
	}
    }
    else{
	my @outer_query = $fig->sprout->GetAll(['Feature'], "Feature(assignment) = ?", [$search_term], ['Feature(id)']);
	foreach my $oq (@outer_query){
	    my ($peg) =@$oq;
	    if($peg =~/peg/){
		push(@$peg_index_data,$peg);
	    }
	}
    }

    my $search_summary;
    if($pegs_to_save){
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    my %pegs_to_filter;
	    foreach my $peg (@$pegs_to_save){$pegs_to_filter{$peg} = 1;}
	    my %pegs_temp;
	    foreach my $peg (@$peg_index_data){
		$pegs_temp{$peg} = 1;
	    }
	    foreach my $peg (keys(%pegs_to_filter)){
		if($pegs_temp{$peg}){
		    push(@$pegs_to_return,$peg); 
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	elsif($lop eq "NOT"){
	    $search_summary = "FAILED";
	    my %pegs_to_filter;
	    foreach my $peg (@$pegs_to_save){$pegs_to_filter{$peg} = 1;}
	    my %pegs_temp;
	    foreach my $peg (@$peg_index_data){
		$pegs_temp{$peg} = 1;
	    }
	    foreach my $peg (keys(%pegs_to_filter)){
		if(! $pegs_temp{$peg}){push(@$pegs_to_return,$peg); $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	elsif($lop eq "OR"){
	    if(! $concat_or_results){
		my %pegs_to_filter;
		foreach my $peg (@$pegs_to_save){$pegs_to_filter{$peg} = 1;}
		my %pegs_temp;
		foreach my $peg (@$peg_index_data){
		    $pegs_temp{$peg} = 1;
		}
		foreach my $peg (keys(%pegs_to_filter)){
		    if($pegs_temp{$peg}){
			push(@$pegs_to_return,$peg); $search_summary = "OR_SUCCESS"; 
			my $param_hit = "$filter:$search_term";
			if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
			else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
	    else{
		push(@$pegs_to_return,@$pegs_to_save);
		foreach my $peg (@$peg_index_data){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "OR_SUCCESS";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
    }
    else{
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    foreach my $peg (@$peg_index_data){
	        push(@$pegs_to_return,$peg);
		$search_summary = "GOOD";
		my $param_hit = "$filter:$search_term";
		if($$peg_param_hits{$peg}){
		    $ref = $$peg_param_hits{$peg};
		    push(@$ref,$param_hit);
		}
		else{
		    $$peg_param_hits{$peg} = [$param_hit];
		}
	    }
	}
	elsif($lop eq "OR"){
	    foreach my $peg (@$peg_index_data){
	        push(@$pegs_to_return,$peg);
		$search_summary = "OR_SUCCESS";
		my $param_hit = "$filter:$search_term";
		if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
	else{
	    $search_summary = "NOT_FAILED";
	}
    }
    
    #Trace("completing function search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_aa_percent_search{
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my ($pegs_to_return, $ref); 
    my $min = 0;
    my $max = 100;

    ##Trace("aa percent search start") if T(3);
    
    my $name_to_letter = {'Alanine' => 'A',  'Arginine' => 'R',  'Asparagine' => 'N',  'Aspartate' => 'D',  'Cysteine' => "C",  "Glutamate" => "E",  "Glutamine" => "Q",  "Histidine" => "H",  "Isoleucine" => "I",  "Leucine" => "L",  "Lysine" => "K",  "Methionine" => "M",  "Proline" => "P",  "Serine" => "S",  "Threonine" => "T",  "Tryptophan" => "W",  "Tyrosine" => "Y",  "Valine" => "V"};

    my $letter = $$name_to_letter{$filter};
    
    if($search_term =~/(\d+)%?,(\d+)%?/){
	$min = $1/100;
	$max = $2/100;
    }
    
    my $search_summary;
    if($pegs_to_save){
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    foreach my $peg (@$pegs_to_save){
		my $letter_count = 0;
		my $seq = $fig->get_translation($peg);
		my $seq_length = length($seq);
		my @letters = split("",$seq);
		foreach my $l (@letters){
		    if($l eq $letter){
			$letter_count++;
		    }
		}
		
		my $percent = $letter_count/$seq_length;
		if($letter_count/$seq_length >= $min && $letter_count/$seq_length <= $max){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
 	elsif($lop eq "NOT"){
	    $search_summary = "FAILED";
	    foreach my $peg (@$pegs_to_save){
		my $letter_count = 0;
		my $seq = $fig->get_translation($peg);
		my $seq_length = length($seq);
		my @letters = split("",$seq);
		foreach my $l (@letters){
		    if($l eq $letter){
			$letter_count++;
		    }
		}
		my $percent = $letter_count/$seq_length;
		if($letter_count/$seq_length < $min && $letter_count/$seq_length > $max){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	elsif($lop eq "OR"){
	    if($concat_or_results){
		push(@$pegs_to_return,@$pegs_to_save);
		my @genomes = $fig->genomes();
		my @all_pegs;
		foreach my $genome (@genomes){
		    if($fig->is_prokaryotic($genome)){
			push(@all_pegs,$fig->pegs_of($genome));
		    }
		}
		foreach my $peg (@all_pegs){
		    my $letter_count = 0;
		    my $seq = $fig->get_translation($peg);
		    my $seq_length = length($seq);
		    my @letters = split("",$seq);
		    foreach my $l (@letters){
			if($l eq $letter){
			    $letter_count++;
			}
		    }
		    my $percent = $letter_count/$seq_length;
		    if($letter_count/$seq_length >= $min && $letter_count/$seq_length <= $max){
			push(@$pegs_to_return,$peg);
			$search_summary = "OR_SUCCESS";
			my $param_hit = "$filter:$search_term";
			if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
			else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
	    else{
		foreach my $peg (@$pegs_to_save){
		    my $letter_count = 0;
		    my $seq = $fig->get_translation($peg);
		    my $seq_length = length($seq);
		    my @letters = split("",$seq);
		    foreach my $l (@letters){
			if($l eq $letter){
			    $letter_count++;
			}
		    }
		    
		    my $percent = $letter_count/$seq_length;
		    if($letter_count/$seq_length >= $min && $letter_count/$seq_length <= $max){
			push(@$pegs_to_return,$peg);
			$search_summary = "OR_SUCCESS";
			my $param_hit = "$filter:$search_term";
			if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
			else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
	}
    }
    
    else{
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    my @genomes = $fig->genomes();
	    my @all_pegs;
	    foreach my $genome (@genomes){
		if($fig->is_prokaryotic($genome)){
		    push(@all_pegs,$fig->pegs_of($genome));
		}
	    }
	    foreach my $peg (@all_pegs){
		my $letter_count = 0;
		my $seq = $fig->get_translation($peg);
		my $seq_length = length($seq);
		my @letters = split("",$seq);
		foreach my $l (@letters){
		    if($l eq $letter){
			$letter_count++;
		    }
		}
                my $percent = $letter_count/$seq_length;
                if($letter_count/$seq_length >= $min && $letter_count/$seq_length <= $max){
                    push(@$pegs_to_return,$peg);
                    $search_summary = "GOOD";
                    my $param_hit = "$filter:$search_term";
                    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
                    else{$$peg_param_hits{$peg} = [$param_hit];}
                }
            }
	}
  	elsif($lop eq "OR"){
	    my @genomes = $fig->genomes();
	    my @all_pegs;
	    foreach my $genome (@genomes){
		if($fig->is_prokaryotic($genome)){
		    push(@all_pegs,$fig->pegs_of($genome));
		}
	    }
	    foreach my $peg (@all_pegs){
		my $letter_count = 0;
		my $seq = $fig->get_translation($peg);
		my $seq_length = length($seq);
		my @letters = split("",$seq);
		foreach my $l (@letters){
		    if($l eq $letter){
			$letter_count++;
		    }
		}
                my $percent = $letter_count/$seq_length;
                if($letter_count/$seq_length >= $min && $letter_count/$seq_length <= $max){
                    push(@$pegs_to_return,$peg);
                    $search_summary = "OR_SUCCESS";
                    my $param_hit = "$filter:$search_term";
                    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
                    else{$$peg_param_hits{$peg} = [$param_hit];}
                }
	    }
	}
	else{
	    $search_summary = "NOT_FAILED";
	    my @genomes = $fig->genomes();
	    my @all_pegs;
	    foreach my $genome (@genomes){
		if($fig->is_prokaryotic($genome)){
		    push(@all_pegs,$fig->pegs_of($genome));
		}
	    }
	    foreach my $peg (@all_pegs){
		my $letter_count = 0;
		my $seq = $fig->get_translation($peg);
		my $seq_length = length($seq);
		my @letters = split("",$seq);
		foreach my $l (@letters){
		    if($l eq $letter){
			$letter_count++;
		    }
		}
                my $percent = $letter_count/$seq_length;
                if($letter_count/$seq_length < $min && $letter_count/$seq_length > $max){
                    push(@$pegs_to_return,$peg);
                    $search_summary = "GOOD";
                    my $param_hit = "$filter:$search_term";
                    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
                    else{$$peg_param_hits{$peg} = [$param_hit];}
                }
	    }
	}
    }
	
    ##print STDERR "completing aa percent search";
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_subsystem_search{
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;

    my ($pegs_to_return, $ref); 

    my @subsystems = $fig->all_subsystems();
    open(OUT,">$FIG_Config::temp/list_of_subsystems.txt");
    foreach my $subsystem (@subsystems){
	print OUT "$subsystem\n";
    }
    close(OUT);

    my %subsystem_filter;
    my $results = `grep $search_term $FIG_Config::temp/list_of_subsystems.txt`;
    my @lines = split("\n",$results);
    foreach my $line (@lines){
	chomp($line);
	$subsystem_filter{$line} =1;
    }

    my $hit_counter = 0;
    my $search_summary;
    if($pegs_to_save){
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    foreach my $peg (@$pegs_to_save){
		my @subs = $fig->peg_to_subsystems($peg);
		foreach my $sub (@subs){
		    if($subsystem_filter{$sub}){
			#Trace("passed:$peg $sub") if T(3);
			push(@$pegs_to_return,$peg);
			$search_summary = "GOOD";
			my $param_hit = "$filter:$search_term";
			if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
			else{$$peg_param_hits{$peg} = [$param_hit];}
			last;
		    }
		}
	    }
	}
	elsif($lop eq "NOT"){
	    $search_summary = "FAILED";
	    foreach my $peg (@$pegs_to_save){
		my @subs = $fig->peg_to_subsystems($peg);
		my $save = 1;
		foreach my $sub (@subs){
		    if($subsystem_filter{$sub}){
			$save = 0; 
			last;
		    }
		}
		if($save){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	else{
	    if($concat_or_results){
		push(@$pegs_to_return,@$pegs_to_save);
		foreach my $subsystem (keys(%subsystem_filter)){
		    ##Trace("SS:$subsystem") if T(3);
		    my $sub = $fig->get_subsystem($subsystem);
		    #my @genomes = $sub->get_genomes();
		    my @roles = $sub->get_roles(); 
		    for my $role (@roles)
		    {
			my @role_pegs = $fig->role_to_pegs($role);
			push(@$pegs_to_return,@role_pegs);
			$search_summary = "OR_SUCCESS";
			my $param_hit = "$filter:$search_term";
			foreach my $peg (@role_pegs){
			    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
			    else{$$peg_param_hits{$peg} = [$param_hit];}
			}
		    }
		}
	    }
	    else{
		foreach my $subsystem (keys(%subsystem_filter)){
		    my $sub = $fig->get_subsystem($subsystem);
		    my @roles = $sub->get_roles(); 
		    for my $role (@roles){
			my @role_pegs = $fig->role_to_pegs($role);
			push(@$pegs_to_return,@role_pegs);
			$search_summary = "OR_SUCCESS";
			my $param_hit = "$filter:$search_term";
			foreach my $peg (@role_pegs){
			    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
			    else{$$peg_param_hits{$peg} = [$param_hit];}
			}
		    }
		}
	    }	
	}	
    }
    else{
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    foreach my $subsystem (keys(%subsystem_filter)){
		if($subsystem =~/Transporters_In_Models/){next;}
		my $sub = $fig->get_subsystem($subsystem);
		my @roles = $sub->get_roles(); 
		for my $role (@roles)
		{
		    ##Trace("role: $role") if T(3);
		    my @role_pegs = $fig->role_to_pegs($role);
		    
		    push(@$pegs_to_return,@role_pegs);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    foreach my $peg (@role_pegs){
			if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
			else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
	}
	elsif($lop eq "NOT"){
	    $search_summary = "NOT_FAILED";
	}
	else{
	    foreach my $subsystem (keys(%subsystem_filter)){
		if($subsystem =~/Transporters_In_Models/){next;}
		my $sub = $fig->get_subsystem($subsystem);
		my @roles = $sub->get_roles(); 
		for my $role (@roles)
		{
		    my @role_pegs = $fig->role_to_pegs($role);
		    push(@$pegs_to_return,@role_pegs);
		    $search_summary = "OR_SUCCESS";
		    my $param_hit = "$filter:$search_term";
		    foreach my $peg (@role_pegs){
			if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
			else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
	}
    }

    ##print STDERR "completing subsystem search, found pegs $found_pegs";
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_lineage_search{

    my $ref;
    Trace("starting lineage search") if T(3);
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my $pegs_to_return;
    $search_term = "'".$search_term."'"; 
    my @genomes = $fig->genomes();
    #Trace("writing genomes to txt files") if T(3);
    open(OUT,">$FIG_Config::temp/genome_lineage.txt");
    foreach my $genome (@genomes){
	my $lineage = $fig->taxonomy_of($genome);
	print OUT "$genome\t$lineage\n";
    }
    close(OUT);
    #Trace("finished writing genomes to txt files") if T(3);

    my %genome_filter;
    my $results = `grep $search_term $FIG_Config::temp/genome_lineage.txt`;
     
    my @lines = split("\n",$results);
    foreach my $line (@lines){
	#Trace("line: $line") if T(3);
	my($genome_id,$lineage) = split("\t",$line);
	if($genome_id =~/(\d+\.\d+)$/){
	    #Trace("search term: $search_term gid: $genome_id") if T(3);
	    $genome_filter{$1} = 1;
	}
    }
    
    my $search_summary;
    
    if($pegs_to_save){
	$search_summary = "FAILED";
	if($lop eq "AND"){
	    foreach my $peg (@$pegs_to_save){
		my $genome = $fig->genome_of($peg);
		if($genome_filter{$genome}){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	elsif($lop eq "NOT"){
	    $search_summary = "NOT_FAILED";
	    foreach my $peg (@$pegs_to_save){
		my $genome = $fig->genome_of($peg);
		if(!$genome_filter{$genome}){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	else{
	    if($concat_or_results){
		push(@$pegs_to_return,@$pegs_to_save);
		foreach my $genome (keys(%genome_filter)){
		    my @pegs_to_add = $fig->pegs_of($genome);
		    push(@$pegs_to_return,@pegs_to_add);
		    $search_summary = "OR_SUCCESS";
		    my $param_hit = "$filter:$search_term";
                    foreach my $peg (@pegs_to_add) {
                      if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
                      else{$$peg_param_hits{$peg} = [$param_hit];}
                    }
		}
	    }
	    else{
		foreach my $peg (@$pegs_to_save){
		    my $genome = $fig->genome_of($peg);
		    if($genome_filter{$genome}){
			push(@$pegs_to_return,$peg);
			$search_summary = "OR_SUCCESS";
			my $param_hit = "$filter:$search_term";
			if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
			else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
	}
    }
    else{
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    foreach my $genome (keys(%genome_filter)){
		my @pegs_to_add = $fig->pegs_of($genome);
		push(@$pegs_to_return,@pegs_to_add);
		$search_summary = "GOOD";
		my $param_hit = "$filter:$search_term";
                foreach my $peg (@pegs_to_add) {
                  if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
                  else{$$peg_param_hits{$peg} = [$param_hit];}
                }
	    }
	}
	elsif($lop eq "NOT"){
	    $search_summary = "NOT_FAILED";
	}
	else{
	    foreach my $genome (keys(%genome_filter)){
		my @pegs_to_add = $fig->pegs_of($genome);
		push(@$pegs_to_return,@pegs_to_add);
		$search_summary = "OR_SUCCESS";
		my $param_hit = "$filter:$search_term";
                foreach my $peg (@pegs_to_add) {
                  if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
                  else{$$peg_param_hits{$peg} = [$param_hit];}
                }
	    }
	}
    }
    print STDERR "completing lineage search";
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_pinned_region_search{

    Trace("do_pinned_region search called") if T(3);
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my $pegs_to_return; 

    my ($search_summary, $ref);
    
    if($pegs_to_save){
	$search_summary = "FAILED";
	if($lop eq "AND"){
	    foreach my $peg (@$pegs_to_save){
		my @results = $fig->coupled_to($peg);
		if($results[0]){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	elsif($lop eq "NOT"){
	    $search_summary = "NOT_FAILED";
	    foreach my $peg (@$pegs_to_save){
		my @results = $fig->coupled_to($peg);
		if(! $results[0]){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	else{
	    if($concat_or_results){
		push(@$pegs_to_return,@$pegs_to_save);
		my @genomes = $fig->genomes();
		my @all_pegs;
		foreach my $genome (@genomes){
		    if($fig->is_prokaryotic($genome)){
			push(@all_pegs,$fig->pegs_of($genome));
		    }
		}
		foreach my $peg (@all_pegs){
		    my @results = $fig->coupled_to($peg);
		    if($results[0]){
			push(@$pegs_to_return,$peg);
			$search_summary = "OR_SUCCESS";
			my $param_hit = "$filter:$search_term";
			if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
			else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
	    else{
		foreach my $peg (@$pegs_to_save){
		    my @results = $fig->coupled_to($peg);
		    if($results[0]){
			push(@$pegs_to_return,$peg);
			$search_summary = "OR_SUCCESS";
			my $param_hit = "$filter:$search_term";
			if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
			else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
	}
    }
    else{
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    my @genomes = $fig->genomes();
	    my @all_pegs;
	    foreach my $genome (@genomes){
		if($fig->is_prokaryotic($genome)){
		    push(@all_pegs,$fig->pegs_of($genome));
		}
	    }
	    foreach my $peg (@all_pegs){
		my @results = $fig->coupled_to($peg);
		if($results[0]){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	elsif($lop eq "NOT"){
	    $search_summary = "NOT_FAILED";
	    my @genomes = $fig->genomes();
	    my @all_pegs;
	    foreach my $genome (@genomes){
		if($fig->is_prokaryotic($genome)){
		    push(@all_pegs,$fig->pegs_of($genome));
		}
	    }
	    foreach my $peg (@all_pegs){
		my @results = $fig->coupled_to($peg);
		if(! $results[0]){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	else{
	    my @genomes = $fig->genomes();
	    my @all_pegs;
	    foreach my $genome (@genomes){
		if($fig->is_prokaryotic($genome)){
		    push(@all_pegs,$fig->pegs_of($genome));
		}
	    }
	    foreach my $peg (@all_pegs){
		my @results = $fig->coupled_to($peg);
		if($results[0]){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "OR_SUCCESS";
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
    }

    print STDERR "completing pinned region search";
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_pfam_id_search{
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my ($pegs_to_return, $ref); 
    $search_term = "PFAM::$search_term";
    
    ##Trace("performing pfam_id_search") if T(3);

    my @attributes;
    my $search_summary;
    if(@$pegs_to_save[0]){
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    foreach my $peg (@$pegs_to_save){
		my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,$search_term], ['Property(property-value)']);
		foreach my $oq (@outer_query){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	elsif($lop eq "NOT"){
	    $search_summary = "NOT_FAILED";
	    foreach my $peg (@$pegs_to_save){
		my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,$search_term], ['Property(property-value)']);
		if(scalar(@outer_query) < 1){push(@$pegs_to_return,$peg);$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}}
	    }
	}
	else{
	    if($concat_or_results){
		push(@$pegs_to_return,@$pegs_to_save);
		my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ?", [$search_term], ['Feature(id)']);
		foreach my $oq (@outer_query){
		    my($peg) = @$oq;
		    push(@$pegs_to_return,$peg);
		    $search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	    else{
		foreach my $peg (@$pegs_to_save){
		    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,$search_term], ['Property(property-value)']);
		    foreach my $oq (@outer_query){
			push(@$pegs_to_return,$peg);
			$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
	}
    }
    else{
	##Trace("pegs NOT passed in") if T(3);
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ?", [$search_term], ['Feature(id)']);
	    foreach my $oq (@outer_query){
		my($peg) = @$oq;
		push(@$pegs_to_return,$peg);
		$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
	elsif($lop eq "NOT"){
	    $search_summary = "NOT_FAILED";
	}
	else{
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ?", [$search_term], ['Feature(id)']);
	    foreach my $oq (@outer_query){
		my($peg) = @$oq;
		push(@$pegs_to_return,$peg);
		$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
    }
    ##Trace("completing PFAM ID search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_similar_to_human_search{
    #Trace("do_similar_to_human_search called") if T(3);
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my ($pegs_to_return, $ref); 
    $search_term = "similar_to_human";
    my $search_summary;
    if(@$pegs_to_save[0]){
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    foreach my $peg (@$pegs_to_save){
		my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ? AND Property(property-value) = ?", [$peg,'similar_to_human','yes'], ['Property(property-value)']);
		foreach my $oq (@outer_query){
		    #Trace("similar_to_human $peg found") if T(3);
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	elsif($lop eq "NOT"){
	    $search_summary = "NOT_FAILED";
	    foreach my $peg (@$pegs_to_save){
		my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ? AND Property(property-value) = ?", [$peg,'similar_to_human','no'], ['Property(property-value)']);
		foreach my $oq (@outer_query){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD";
		    my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	else{
	    if($concat_or_results){
		push(@$pegs_to_return,@$pegs_to_save);
		my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ? AND Property(property-value) = ?", ['similar_to_human','yes'], ['Feature(id)']);
		foreach my $oq (@outer_query){
		    my ($peg) = @$oq;
		    push(@$pegs_to_return,$peg);
		    $search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	    else{
		foreach my $peg (@$pegs_to_save){
		    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ? AND Property(property-value) = ?", [$peg,'similar_to_human','yes'], ['Property(property-value)']);
		    foreach my $oq (@outer_query){
			push(@$pegs_to_return,$peg);
			$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
	}
    }
    else{
	if($lop eq "AND"){
	    $search_summary = "FAILED";
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ? AND Property(property-value) = ?", ['similar_to_human','yes'], ['Feature(id)']);
	    foreach my $oq (@outer_query){
		my ($peg) = @$oq;
		push(@$pegs_to_return,$peg);
		$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
	elsif($lop eq "NOT"){
	    $search_summary = "NOT_FAILED";
	}
	else{
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ? AND Property(property-value) = ?", ['similar_to_human','yes'], ['Feature(id)']);
	    foreach my $oq (@outer_query){
		my ($peg) = @$oq;
		push(@$pegs_to_return,$peg);
		$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
    }
    ##Trace("completing similar to human search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}


sub do_phenotype_search{
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my ($pegs_to_return, $ref);
    my @attributes;
    my %genomes_with_phenotype;
    @attributes = Observation->get_attributes($fig,undef,$filter,$search_term);
    foreach my $attribute (@attributes){
	my $genome = @$attribute[0];
	$genomes_with_phenotype{$genome} = 1;
    }
  
    my $search_summary;
    if($lop eq "AND"){
	$search_summary = "FAILED";
	if($pegs_to_save){
	    foreach my $peg (@$pegs_to_save){
		my $genome = $fig->genome_of($peg); 
		if($genomes_with_phenotype{$genome}){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	else{
	    foreach my $genome (keys(%genomes_with_phenotype)){
		my @pegs_to_add = $fig->pegs_of($genome);
		push(@$pegs_to_return,@pegs_to_add);
                for my $peg (@pegs_to_add) {
                  $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
                }
	    }
	}
    }
    elsif($lop eq "NOT"){
	$search_summary = "NOT_FAILED";
	if($pegs_to_save){
	    foreach my $peg (@$pegs_to_save){
		my $genome = $fig->genome_of($peg); 
		if(! $genomes_with_phenotype{$genome}){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
    }
    else{
	if($concat_or_results){
	    push(@$pegs_to_return,@$pegs_to_save);
	    foreach my $genome (keys(%genomes_with_phenotype)){
		my @pegs_to_add = $fig->pegs_of($genome);
		push(@$pegs_to_return,@pegs_to_add);
                for my $peg (@pegs_to_add) {
                  $search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
                }
	    }
	}
	else{
	    foreach my $peg (@$pegs_to_save){
		my $genome = $fig->genome_of($peg); 
		if($genomes_with_phenotype{$genome}){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
    }

    ##Trace("completing phenotype search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_pfam_name_search{
    my($fig,$cgi,$filter,$pfam_name,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my ($pegs_to_return, $search_summary, $ref);

    my $pfam_id;
    my $sqlite_db = "/home/mkubal/Temp/Ontology/ontology.sqlite";
    my $ontology_dbmaster = DBMaster->new(-database => $sqlite_db, -backend => 'SQLite');
    my $dt_objs =  $ontology_dbmaster->pfam->get_objects( { 'term' => $pfam_name} );
    foreach my $dt_obj (@$dt_objs){
	$pfam_id = $dt_obj->id(); 
	#Trace("pfam name mapped to: $pfam_id") if T(3);
    }
   
    if(!$pfam_id){
	if($lop eq "AND"){$search_summary = "FAILED";}
	elsif($lop eq "NOT"){$search_summary = "NOT_FAILED";}
	else{$search_summary = "KEEP_SEARCHING";}
    }
    
    else{
	my $search_term = "PFAM::$pfam_id";

	if(@$pegs_to_save[0]){
	    if($lop eq "AND"){
		$search_summary = "FAILED";
		foreach my $peg (@$pegs_to_save){
		    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,$search_term], ['Property(property-value)']);
		    foreach my $oq (@outer_query){
			push(@$pegs_to_return,$peg);
			$search_summary = "GOOD";
			my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
	    elsif($lop eq "NOT"){
		$search_summary = "NOT_FAILED";
		foreach my $peg (@$pegs_to_save){
		    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,$search_term], ['Property(property-value)']);
		    if(scalar(@outer_query) < 1){push(@$pegs_to_return,$peg);$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}}
		}
	    }
	    else{
		if($concat_or_results){
		    push(@$pegs_to_return,@$pegs_to_save);
		    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ?", [$search_term], ['Feature(id)']);
		    foreach my $oq (@outer_query){
			my($peg) = @$oq;
			push(@$pegs_to_return,$peg);
			$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
		else{
		    foreach my $peg (@$pegs_to_save){
			my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,$search_term], ['Property(property-value)']);
			foreach my $oq (@outer_query){
			push(@$pegs_to_return,$peg);
			$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		    }
		}
	    }
	}
	else{
	    ##Trace("pegs NOT passed in") if T(3);
	    if($lop eq "AND"){
		$search_summary = "FAILED";
		my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ?", [$search_term], ['Feature(id)']);
		foreach my $oq (@outer_query){
		    my($peg) = @$oq;
		    #Trace("peg found by pfam:$peg") if T(3);
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	    elsif($lop eq "NOT"){
		$search_summary = "NOT_FAILED";
	    }
	    else{
		my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ?", [$search_term], ['Feature(id)']);
		foreach my $oq (@outer_query){
		    my($peg) = @$oq;
		    push(@$pegs_to_return,$peg);
		    $search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
    }
    ##Trace("completing PFAM Name search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}
    

sub do_signal_peptide_search{
    Trace("do_signal_peptide_search called") if T(3);
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my ($pegs_to_return, $ref); 
    $search_term = "Phobius::signal";
    my @attributes;
    my $search_summary;
    
    if($lop eq "AND"){
	$search_summary = "FAILED";
	foreach my $peg (@$pegs_to_save){
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'Phobius::signal'], ['Property(property-value)']);
	    foreach my $oq (@outer_query){
		push(@$pegs_to_return,$peg);
		$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
    }
    elsif($lop eq "NOT"){
	$search_summary = "NOT_FAILED";
	my %peg_filter;
	foreach my $peg (@$pegs_to_save){
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'Phobius::signal'], ['Property(property-value)']);
	    if(scalar(@outer_query) < 1 ){push(@$pegs_to_return,$peg); $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}}
	}
    }
    else{
	if($concat_or_results){
	    push(@$pegs_to_return,@$pegs_to_save);
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ?", ['Phobius::signal'], ['Feature(id)']);
	    foreach my $oq (@outer_query){
		my ($peg) = @$oq;
		push(@$pegs_to_return,$peg);
		$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
	else{
	    if($pegs_to_save){
		foreach my $peg (@$pegs_to_save){
		    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'Phobius::signal'], ['Property(property-value)']);
		    foreach my $oq (@outer_query){
			push(@$pegs_to_return,$peg);
			$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		    }
		}
	    }
    	}	
    }
    
    Trace("completing Signal Peptide search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_aa_pattern_search{
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits,$patscan_hits_aa) = @_;
    my $ref;
    my $pegs_to_return;
    my $search_summary;
    
    #Trace("called sub do_aa_pattern_search") if T(3);
    if($lop eq "AND"){
	$search_summary = "FAILED";
	if($pegs_to_save){
	    my $peg_file =  $FIG_Config::temp."/peg.txt";
	    open(PEG,">$peg_file");
	    foreach my $peg (@$pegs_to_save){
		my $peg_seq = $fig->get_translation($peg);
		print PEG ">$peg\n";
		print PEG "$peg_seq\n";
	    }
	    close(PEG);
	
	    my $pat_file =  $FIG_Config::temp."/pat.txt";
	    open(PAT,">$pat_file");
	    print PAT "$search_term\n";
	    close(PAT);
	    
	    #Trace("calling scan_for_matches") if T(3);
	    my @out = `cat $peg_file | $FIG_Config::ext_bin/scan_for_matches -c -p $pat_file`;
	    #Trace("scan for matches done") if T(3);
	    my %already;
	    my $record_hit = 0;
            my $peg;
            my $location;
	    my $matching_seq;
	    foreach my $o (@out){
		if($record_hit){
		    $record_hit = 0;
		    chomp($o);
		    $matching_seq = $o;
		    if($$patscan_hits_aa{$peg}){
			$ref = $$patscan_hits_aa{$peg};
			push(@$ref,"$matching_seq at $location");
		    }
		    else{
			$$patscan_hits_aa{$peg} = ["$matching_seq at $location"];
		    }
		}

		if($o =~/(fig\|\d+.\d+.peg.\d+).*(\d+,\d+)/){
		    ##Trace("regexp found") if T(3);
		    $peg = $1;
		    $location = $2;
		    $record_hit = 1;
		    if($already{$peg}){next;}
		    else{$already{$peg} =1;}
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	else{
	    my @genomes = $fig->genomes();
	    my @all_pegs;
	    foreach my $genome (@genomes){
		if($fig->is_prokaryotic($genome)){
		    push(@all_pegs,$fig->pegs_of($genome));
		}
	    }

	    my $peg_file =  $FIG_Config::temp."/peg.txt";
	    open(PEG,">$peg_file");
		
	    foreach my $peg (@all_pegs){
		my $peg_seq = $fig->get_translation($peg);
		print PEG ">$peg\n";
		print PEG "$peg_seq\n";
	    }
	    close(PEG);
		
	    my $pat_file =  $FIG_Config::temp."/pat.txt";
	    open(PAT,">$pat_file");
	    print PAT "$search_term\n";
	    close(PAT);
		
	    my @out = `cat $peg_file | $FIG_Config::ext_bin/scan_for_matches -c -p $pat_file`;
	    my %already;

	    my $record_hit = 0;
            my $peg;
            my $location;
	    my $matching_seq;
	    foreach my $o (@out){
		if($record_hit){
		    $record_hit = 0;
		    chomp($o);
		    $matching_seq = $o;
		    if($$patscan_hits_aa{$peg}){
			$ref = $$patscan_hits_aa{$peg};
			push(@$ref,"$matching_seq at $location");
		    }
		    else{
			$$patscan_hits_aa{$peg} = ["$matching_seq at $location"];
		    }
		}
		if($o =~/(fig\|\d+.\d+.peg.\d+):*(\d+,\d+)/){
		    $peg = $1;
		    $location = $2;
		    $record_hit = 1;
		    if($already{$peg}){next;}
		    else{$already{$peg} =1;}
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
    }
    elsif($lop eq "NOT"){
	$search_summary = "NOT_FAILED";
	if($pegs_to_save){
	    foreach my $peg (@$pegs_to_save){
		my $peg_seq = $fig->get_translation($peg);
		my $peg_file =  $FIG_Config::temp."/peg.txt";
		open(PEG,">$peg_file");
		print PEG ">$peg\n";
		print PEG "$peg_seq\n";
		close(PEG);
		
		my $pat_file =  $FIG_Config::temp."/pat.txt";
		open(PAT,">$pat_file");
		print PAT "$search_term\n";
		close(PAT);
		
		my @out = `cat $peg_file | $FIG_Config::ext_bin/scan_for_matches -c -p $pat_file`;
		
		if(scalar(@out) < 1){
		    push(@$pegs_to_return,$peg);
		    $$patscan_hits_aa{$peg} = ["sequence does not contain match"];
		}
	    }
	}
    }
    else{
	my @all_pegs;
	if($concat_or_results){
	    push(@$pegs_to_return,@$pegs_to_save);
	    my @genomes = $fig->genomes();
	    foreach my $genome (@genomes){
		if($fig->is_prokaryotic($genome)){
		    push(@all_pegs,$fig->pegs_of($genome));
		}
	    }
	}
	else{
	    @all_pegs = @$pegs_to_save;
	}
	    
	my $peg_file =  $FIG_Config::temp."/peg.txt";
	open(PEG,">$peg_file");
	foreach my $peg (@all_pegs){
	    my $peg_seq = $fig->get_translation($peg);
	    print PEG ">$peg\n";
	    print PEG "$peg_seq\n";
	}
	close(PEG);
	    
	my $pat_file =  $FIG_Config::temp."/pat.txt";
	open(PAT,">$pat_file");
	print PAT "$search_term\n";
	close(PAT);
	    
	my %already;
	my @out = `cat $peg_file | $FIG_Config::ext_bin/scan_for_matches -c -p $pat_file`;

	my $record_hit = 0;
	my $peg;
	my $location;
	my $matching_seq;
	foreach my $o (@out){
	    if($record_hit){
		$record_hit = 0;
		chomp($o);
		$matching_seq = $o;
		if($$patscan_hits_aa{$peg}){
		    $ref = $$patscan_hits_aa{$peg};
		    push(@$ref,"$matching_seq at $location");
		}
		else{
		    $$patscan_hits_aa{$peg} = ["$matching_seq at $location"];
		}
	    }
	    if($o =~/(fig\|\d+.\d+.peg.\d+):*(\d+,\d+)/){
		$peg = $1;
		$location = $2;
		$record_hit = 1;
		if($already{$peg}){next;}
		else{$already{$peg} =1;}
		push(@$pegs_to_return,$peg);
		$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
    }
    
    ##Trace("completing Amino Acid Pattern search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits,$patscan_hits_aa);
}

sub do_dna_pattern_search{
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits,$patscan_hits_dna) = @_;
    my $pegs_to_return; 
    my $search_summary;
    my $ref;
    
    if($lop eq "AND"){
	$search_summary = "FAILED";
	if($pegs_to_save){
	    my $peg_file =  $FIG_Config::temp."/peg.txt";
	    open(PEG,">$peg_file");
	    foreach my $peg (@$pegs_to_save){
		my @loc = $fig->feature_location($peg);
		my $genome = $fig->genome_of($peg);
		my $peg_seq = $fig->dna_seq($genome,@loc);
		print PEG ">$peg\n";
		print PEG "$peg_seq\n";
	    }
	    close(PEG);
	
	    my $pat_file =  $FIG_Config::temp."/pat.txt";
	    open(PAT,">$pat_file");
	    print PAT "$search_term\n";
	    close(PAT);
	    my %already;
	    my @out = `cat $peg_file | $FIG_Config::ext_bin/scan_for_matches -c $pat_file`;

	    my $record_hit = 0;
            my $peg;
            my $location;
	    my $matching_seq;
	    foreach my $o (@out){
		if($record_hit){
		    $record_hit = 0;
		    chomp($o);
		    $matching_seq = $o;
		    if($$patscan_hits_dna{$peg}){
			$ref = $$patscan_hits_dna{$peg};
			push(@$ref,"$matching_seq at $location");
		    }
		    else{
			$$patscan_hits_dna{$peg} = ["$matching_seq at $location"];
		    }
		}
		if($o =~/(fig\|\d+.\d+.peg.\d+):*(\d+,\d+)/){
		    $peg = $1;
		    $location = $2;
		    $record_hit = 1;
		    if($already{$peg}){next;}
		    else{$already{$peg} =1;}
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	else{
	    my @genomes = $fig->genomes();
	    my @all_pegs;
	    foreach my $genome (@genomes){
		if($fig->is_prokaryotic($genome)){
		    push(@all_pegs,$fig->pegs_of($genome));
		}
	    }

	    my $peg_file =  $FIG_Config::temp."/peg.txt";
	    open(PEG,">$peg_file");
		
	    foreach my $peg (@all_pegs){
		my @loc = $fig->feature_location($peg);
		my $genome = $fig->genome_of($peg);
		my $peg_seq = $fig->dna_seq($genome,@loc);
		print PEG ">$peg\n";
		print PEG "$peg_seq\n";
	    }
	    close(PEG);
		
	    my $pat_file =  $FIG_Config::temp."/pat.txt";
	    open(PAT,">$pat_file");
	    print PAT "$search_term\n";
	    close(PAT);
	    my %already;	
	    my @out = `cat $peg_file | $FIG_Config::ext_bin/scan_for_matches -c $pat_file`;

	    my $record_hit = 0;
            my $peg;
            my $location;
	    my $matching_seq;
	    foreach my $o (@out){
		if($record_hit){
		    $record_hit = 0;
		    chomp($o);
		    $matching_seq = $o;
		    if($$patscan_hits_dna{$peg}){
			$ref = $$patscan_hits_dna{$peg};
			push(@$ref,"$matching_seq at $location");
		    }
		    else{
			$$patscan_hits_dna{$peg} = ["$matching_seq at $location"];
		    }
		}
		if($o =~/(fig\|\d+.\d+.peg.\d+):*(\d+,\d+)/){
		    $peg = $1;
		    $location = $2;
		    $record_hit = 1;
		    if($already{$peg}){next;}
		    else{$already{$peg} =1;}
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
    }
    elsif($lop eq "NOT"){
	$search_summary = "NOT_FAILED";
	if($pegs_to_save){
	    foreach my $peg (@$pegs_to_save){
		my @loc = $fig->feature_location($peg);
		my $genome = $fig->genome_of($peg);
		my $peg_seq = $fig->dna_seq($genome,@loc);
		my $peg_file =  $FIG_Config::temp."/peg.txt";
		open(PEG,">$peg_file");
		print PEG ">$peg\n";
		print PEG "$peg_seq\n";
		close(PEG);
		
		my $pat_file =  $FIG_Config::temp."/pat.txt";
		open(PAT,">$pat_file");
		print PAT "$search_term\n";
		close(PAT);
		
		my @out = `cat $peg_file | $FIG_Config::ext_bin/scan_for_matches -c $pat_file`;
		if(scalar(@out) < 1){
		    push(@$pegs_to_return,$peg);
		    $$patscan_hits_dna{$peg} = ["sequence does not contain match"];
		}
	    }
	}
    }
    else{
	my @all_pegs;
	if($concat_or_results){
	    push(@$pegs_to_return,@$pegs_to_save);
	    my @genomes = $fig->genomes();
	    foreach my $genome (@genomes){
		if($fig->is_prokaryotic($genome)){
		    push(@all_pegs,$fig->pegs_of($genome));
		}
	    }
	}
	else{
	    @all_pegs = @$pegs_to_save;
	}
	    
	my $peg_file =  $FIG_Config::temp."/peg.txt";
	open(PEG,">$peg_file");
	foreach my $peg (@all_pegs){
	    my @loc = $fig->feature_location($peg);
	    my $genome = $fig->genome_of($peg);
	    my $peg_seq = $fig->dna_seq($genome,@loc);
	    print PEG ">$peg\n";
	    print PEG "$peg_seq\n";
	}
	close(PEG);
	    
	my $pat_file =  $FIG_Config::temp."/pat.txt";
	open(PAT,">$pat_file");
	print PAT "$search_term\n";
	close(PAT);
	my %already;    
	my @out = `cat $peg_file | $FIG_Config::ext_bin/scan_for_matches -c $pat_file`;

	my $record_hit = 0;
	my $peg;
	my $location;
	my $matching_seq;
	foreach my $o (@out){
	    if($record_hit){
		$record_hit = 0;
		chomp($o);
		$matching_seq = $o;
		if($$patscan_hits_dna{$peg}){
		    $ref = $$patscan_hits_dna{$peg};
		    push(@$ref,"$matching_seq at $location");
		}
		else{
		    $$patscan_hits_dna{$peg} = ["$matching_seq at $location"];
		}
	    }
	    if($o =~/(fig\|\d+.\d+.peg.\d+):*(\d+,\d+)/){
		$peg = $1;
		$location = $2;
		$record_hit = 1;
		if($already{$peg}){next;}
		else{$already{$peg} =1;}
		push(@$pegs_to_return,$peg);
		$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
    }
    
    ##Trace("completing DNA Pattern search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits,$patscan_hits_dna);
}

sub do_location_search{
    #Trace("do_location_search called") if T(3);
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my $pegs_to_return; 
    my $ref;
    $search_term = "PSORT::$search_term";
    #Trace("search_term:$search_term") if T(3);
    my $search_summary;
    
    if($lop eq "AND"){
	$search_summary = "FAILED";
	foreach my $peg (@$pegs_to_save){
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,$search_term], ['Property(property-value)']);
	    foreach my $oq (@outer_query){
		push(@$pegs_to_return,$peg);
		$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
    }
    elsif($lop eq "NOT"){
	$search_summary = "NOT_FAILED";
	foreach my $peg (@$pegs_to_save){
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,$search_term], ['Property(property-value)']);
	    if(scalar(@outer_query) < 1){push(@$pegs_to_return,$peg);}
	}
    }
    else{
	if($concat_or_results){
	    push(@$pegs_to_return,@$pegs_to_save);
	}

        #my $count = 0;
	foreach my $peg (@$pegs_to_save){
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,$search_term], ['Feature(id)']);
	    foreach my $oq (@outer_query){
		#$count++;
		push(@$pegs_to_return,$peg);
		$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
	#Trace("Location hits for $search_term: $count") if T(3);
    }
    
    #my $count = scalar(@$pegs_to_return);
    #Trace("completing cellular location search, $count found") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_taxon_id_search{
    Trace("do taxon_id search called") if T(3);
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my $pegs_to_return; 
    my $ref;
    #my $taxon_filter = "fig|%".$search_term.".%";
    my $taxon_filter = "%".$search_term."%";
    my $search_summary;
    my @all_pegs;

    if($lop eq "AND"){
	$search_summary = "FAILED";
        if(@$pegs_to_save[0]){
	    foreach my $peg (@$pegs_to_save){
		if($peg =~/fig\|$search_term\./){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD"; 
		    my $param_hit = "$filter:$search_term";
		    if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit); } 
		    else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	else{
	    my @outer_query = $fig->sprout->GetAll(['Feature'], "Feature(id) LIKE ? ", ["$taxon_filter"], ['Feature(id)']);
	    foreach my $oq (@outer_query){
		my ($peg) =@$oq;
		push(@$pegs_to_return,$peg);
		$search_summary = "GOOD"; 
		my $param_hit = "$filter:$search_term";
		if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit); } 
		else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	    #Trace("done with sprout q") if T(3);
	}
    }
    elsif($lop eq "NOT"){
	$search_summary = "NOT_FAILED";
	foreach my $peg (@$pegs_to_save){
	    if($peg !~/fig\|$taxon_filter/){
		push(@$pegs_to_return,$peg);
		$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
    }
    
    else{
	if($concat_or_results){
	    push(@$pegs_to_return,@$pegs_to_save);
	    my @all_genomes = $fig->genomes();
	    foreach my $genome (@all_genomes){
		if($genome =~/^$taxon_filter/){
		    my @pegs = $fig->pegs_of($genome);
		    push(@$pegs_to_return,@pegs);
                    for my $peg (@pegs) {
                      $search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
                    }
		}
	    }
	}
	else{
	    foreach my $peg (@$pegs_to_save){
		if($peg =~/^$taxon_filter/){
                    my $genome = $fig->genome_of($peg);
		    my @pegs = $fig->pegs_of($genome);
		    push(@$pegs_to_return,@pegs);
		    $search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
    }
    Trace("completing taxon id search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_length_search{
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my $pegs_to_return; 
    my $ref;
    my ($min,$max) = split(",",$search_term);
    my $search_summary;
    my @all_pegs;
    if($lop eq "AND"){
	$search_summary = "FAILED";
	if($pegs_to_save){@all_pegs = @$pegs_to_save;}
	else{
	    my @genomes = $fig->genomes();
	    foreach my $genome (@genomes){
		if($fig->is_prokaryotic($genome)){
		    push(@all_pegs,$fig->pegs_of($genome));
		}
	    }
	}
	foreach my $peg (@all_pegs){
	    my $seq = $fig->get_translation($peg);
	    my $len = length($seq);
	    if($len >= $min && $len <= $max ){push(@$pegs_to_return,$peg);$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}}
	}
    }
    elsif($lop eq "NOT"){
	$search_summary = "NOT_FAILED";
	foreach my $peg (@$pegs_to_save){
	    my $seq = $fig->get_translation($peg);
	    my $len = length($seq);
	    if($len < $min && $len > $max ){push(@$pegs_to_return,$peg); $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}}
	}
    }    
    else{
	if($concat_or_results){
	    push(@$pegs_to_return,@$pegs_to_save);
	    my @all_genomes = $fig->genomes();
	    foreach my $genome (@all_genomes){
		my @pegs = $fig->pegs_of($genome);
		push(@all_pegs,@pegs);
	    }
	}
	else{
	    @all_pegs = @$pegs_to_save;
	}
	foreach my $peg (@all_pegs){
	    my $seq = $fig->get_translation($peg);
	    my $len = length($seq);
	    if($len >= $min && $len <= $max ){push(@$pegs_to_return,$peg);$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}}
	}
    }
    ##Trace("completing length search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_phenotype_range_search{
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my $pegs_to_return; 
    my ($min,$max) = split(",",$search_term);
    my $ref;
    
    my $search_summary;
    #filter can be GC_Content or Optimal_Temperature
    my @attributes;
    my %genomes_with_phenotype;
    @attributes = Observation->get_attributes($fig,undef,$filter);
    foreach my $attribute (@attributes){
	my $genome = @$attribute[0];
        my $values = @$attribute[2];
	my $min_att_value;
	my $max_att_value;
        if($values =~/unknown/){next}
	elsif($values =~/(\d+)-(\d+)/){
	    $min_att_value = $1;
	    $max_att_value = $2;
	}
	elsif($values =~/^(\d+)$/){
	    $min_att_value = $1;
	    $max_att_value = $1;
	}
	else{next;}
	
	if($min >=$min_att_value && $min <=$max_att_value){
	    $genomes_with_phenotype{$genome} = 1;
	}
	elsif($max >=$min_att_value && $max <=$max_att_value){
	    $genomes_with_phenotype{$genome} = 1;
	}
    }
    
    if($lop eq "AND"){
	$search_summary = "FAILED";
	if($pegs_to_save){
	    foreach my $peg (@$pegs_to_save){
		my $genome = $fig->genome_of($peg); 
		if($genomes_with_phenotype{$genome}){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
	else{
	    foreach my $genome (keys(%genomes_with_phenotype)){
		my @pegs_to_add = $fig->pegs_of($genome);
		push(@$pegs_to_return,@pegs_to_add);
                for my $peg (@pegs_to_add) {
                  $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
                }
	    }
	}
    }
    elsif($lop eq "NOT"){
	$search_summary = "FAILED";
	foreach my $peg (@$pegs_to_save){
	    my $genome = $fig->genome_of($peg); 
	    if(! $genomes_with_phenotype{$genome}){
		push(@$pegs_to_return,$peg);
		$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
    }
    else{
	if($concat_or_results){
	    push(@$pegs_to_return,@$pegs_to_save);
	    foreach my $genome (keys(%genomes_with_phenotype)){
		my @pegs_to_add = $fig->pegs_of($genome);
		push(@$pegs_to_return,@pegs_to_add);
                for my $peg (@pegs_to_add) {
                  $search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
                }
	    }
	}
	else{
	    foreach my $peg (@$pegs_to_save){
		my $genome = $fig->genome_of($peg); 
		if($genomes_with_phenotype{$genome}){
		    push(@$pegs_to_return,$peg);
		    $search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
    }

    ##Trace("completing phenotype range search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_iso_search{
    Trace("do_iso_search called") if T(3);
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my $pegs_to_return; 
    my $ref;
    my ($min,$max) = split(",",$search_term);
    
    my $search_summary;
    if($lop eq "AND"){
	$search_summary = "FAILED";
	foreach my $peg (@$pegs_to_save){
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'isoelectric_point'], ['Property(property-value)']);
	    foreach my $oq (@outer_query){
		my ($iso) =@$oq;
		if($iso){
		    if($iso >= $min && $iso <= $max ){push(@$pegs_to_return,$peg); $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}}
		}
	    }
	}
    }

    elsif($lop eq "NOT"){
	$search_summary = "NOT_FAILED";
	foreach my $peg (@$pegs_to_save){
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'isoelectric_point'], ['Property(property-value)']);
	    foreach my $oq (@outer_query){
		my ($iso) =@$oq;
		if($iso < $min && $iso > $max ){push(@$pegs_to_return,$peg); $search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}}
	    }
	}
    }
  
    else{
	if($concat_or_results){
	    push(@$pegs_to_return,@$pegs_to_save);
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ?", ['isoelectric_point'], ['Feature(id)','Property(property-value)']);
	    foreach my $oq (@outer_query){
		my ($peg,$iso) =@$oq;
		if($iso >= $min && $iso <= $max ){push(@$pegs_to_return,$peg);}
		$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
	else{
	    foreach my $peg (@$pegs_to_save){
		my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'isoelectric_point'], ['Property(property-value)']);
		foreach my $oq (@outer_query){
		    my ($iso) =@$oq;
		    if($iso >= $min && $iso <= $max ){push(@$pegs_to_return,$peg);$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}}
		}
	    }
	}
    }
    
    Trace("completing iso search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_transmembrane_search{
    Trace("do tm search") if T(3);
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my $pegs_to_return; 
    my $ref;
    my ($min,$max) = split(",",$search_term);

    my $search_summary;
    
    if($lop ne "OR"){
	if($lop eq "AND"){$search_summary = "FAILED";}
	else{$search_summary = "NOT_FAILED";}
	foreach my $peg (@$pegs_to_save){
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'Phobius::transmembrane'], ['Property(property-value)']);
	    if(@outer_query){
		foreach my $oq (@outer_query){
		    my ($value) =@$oq;
                    my @locs = split(",", $value);
		    my $location_count = scalar(@locs);
		    if($location_count){
			if($lop eq "AND"){
			    if($location_count >= $min && $location_count <= $max ){push(@$pegs_to_return,$peg);$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}}
			}
			else{
			    if($location_count < $min || $location_count > $max ){push(@$pegs_to_return,$peg);$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}}
			}
		    }
		}
	    }
	    elsif($min == 0 && $max==0){
		if($lop eq "AND"){
		    push(@$pegs_to_return,$peg);$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
    }
    else{
	if($concat_or_results){
	    push(@$pegs_to_return,@$pegs_to_save);
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ?", ['Phobius::transmembrane'], ['Feature(id)','Property(property-value)']);
	    foreach my $oq (@outer_query){
		my ($peg,$value) =@$oq;
                my @locs = split(",", $value);
		my $location_count = scalar(@locs);
		if($location_count){
		    if($location_count >= $min && $location_count <= $max ){push(@$pegs_to_return,$peg);}
		    $search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
		}
	    }
	}
    
	else{
	    foreach my $peg (@$pegs_to_save){
		my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'Phobius::transmembrane'], ['Property(property-value)']);
		foreach my $oq (@outer_query){
		    my ($value) =@$oq;
                    my @locs = split(",",$value);
		    my $location_count = scalar(@locs);
		    if($location_count){
			if($location_count >= $min && $location_count <= $max ){push(@$pegs_to_return,$peg);$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}}
		    }
		}
	    }
	}
    }
    Trace("completing transmembrane search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

sub do_mw_search{

    Trace("do_mw_search called") if T(3);
    my($fig,$cgi,$filter,$search_term,$lop,$pegs_to_save,$concat_or_results,$peg_param_hits) = @_;
    my $pegs_to_return; 
    my $ref;
    my ($min,$max) = split(",",$search_term);
    
    my $search_summary;
    if($lop eq "AND"){
	$search_summary = "FAILED";
	foreach my $peg (@$pegs_to_save){
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'molecular_weight'], ['Property(property-value)']);
	    foreach my $oq (@outer_query){
		my ($mw) =@$oq;
		if($mw){
		    if($mw >= $min && $mw <= $max ){push(@$pegs_to_return,$peg);$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}}
		}
	    }
	}
    }
    elsif($lop eq "NOT"){
	$search_summary = "NOT_FAILED";
	foreach my $peg (@$pegs_to_save){
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'molecular_weight'], ['Property(property-value)']);
	    foreach my $oq (@outer_query){
		my ($mw) =@$oq;
		if($mw){
		    if($mw < $min && $mw > $max ){push(@$pegs_to_return,$peg);$search_summary = "GOOD"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);} else{$$peg_param_hits{$peg} = [$param_hit];}}
		}
	    }
	}
    }
    else{
	if($concat_or_results){
	    push(@$pegs_to_return,@$pegs_to_save);
	    my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Property(property-name) = ?", ['molecular_weight'], ['Feature(id)','Property(property-value)']);
	    foreach my $oq (@outer_query){
		my ($peg,$mw) =@$oq;
		if($mw >= $min && $mw <= $max ){push(@$pegs_to_return,$peg);}
		$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}
	    }
	}
	else{
	    foreach my $peg (@$pegs_to_save){
		my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'molecular_weight'], ['Property(property-value)']);
		foreach my $oq (@outer_query){
		    my ($mw) =@$oq;
		    if($mw){
			if($mw >= $min && $mw <= $max ){push(@$pegs_to_return,$peg);$search_summary = "OR_SUCCESS"; my $param_hit = "$filter:$search_term";if($$peg_param_hits{$peg}){$ref = $$peg_param_hits{$peg};push(@$ref,$param_hit);}else{$$peg_param_hits{$peg} = [$param_hit];}}
		    }
		}
	    }
	}
    }
    
    Trace("completing mw search") if T(3);
    return ($pegs_to_return,$search_summary,$peg_param_hits);
}

#javascript for adding parameter selection input field for specific parameter selected 
sub add_suffix_search_box_js {
    return qq~
	<script>
	function add_suffix_search_box (box_number) {
	    var suffix_count = document.getElementsByName('new_suffix_td').length + rows_deleted_count;
	    var add_suffix = 1;

	    if(suffix_count + 1 == box_number){
	    	add_suffix = 2;
	    }

	    //handles changing parameter selection 
	    if((suffix_count + 1) >  box_number){
		add_suffix = 2;
		var row_obj_id = 'row_div_' + box_number;
		var row_obj = document.getElementById(row_obj_id);
		var suffix_obj_id = 'new_suffix_td_' + box_number;
		var suffix_obj = document.getElementById(suffix_obj_id);
		row_obj.removeChild(suffix_obj);
	    }
	    
	    if(add_suffix == 2){
		var row_div_id = 'row_div_' + box_number;
		var row_div_obj = document.getElementById(row_div_id);
		var new_suffix_td = document.createElement('TD');
		new_suffix_td.style.padding = '0px';
		
		var new_suffix_td_name = 'new_suffix_td';
		var new_suffix_td_id = 'new_suffix_td_' + box_number;
		new_suffix_td.setAttribute('name', new_suffix_td_name);
		new_suffix_td.setAttribute('id', new_suffix_td_id);
				
		var selected_parameter_id = 'Filter' + box_number;
		//var minus_button = "<input class='button' type='button' value='-' onClick='remove_search_box("+ box_number + ");'>";
		//if(box_number == 1){minus_button = "";}
	
		var selected_parameter = document.getElementById(selected_parameter_id).options[document.getElementById(selected_parameter_id).selectedIndex].value;
		
		if(selected_parameter == 'ID'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  eg. gi number, locus, gene name, NCBI Protein accession version (gi|15674351, SAV1290, ftsZ, NP_268525.1)</i></p>"; 
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'PFAM ID'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  eg. PF00108 </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'PFAM Name'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  eg. Abhydrolase_1</i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
	    
		if(selected_parameter == 'Taxon ID'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  eg. 160490</i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Subsystem'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  NMPDR Subsystem name or partial name (eg. Isoleucine_degradation, or Isoleucine) </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'EC Number or Function'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  eg. *EC 2.3.1.16* or 3-ketoacyl-CoA thiolase</i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Organism Name'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i> eg. Streptococcus pyogenes</i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Lineage'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  eg. Firmicutes </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'PatScan Sequence, AA'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>Enter amino acid pattern - <a href='http://www-unix.mcs.anl.gov/compbio/PatScan/HTML/readme_scan_for_matches.html'>detailed instructions found here</a></i><p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'PatScan Sequence, DNA'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>" + " <input class='button' type='button' value='-' onClick='remove_search_box("+ box_number + ");'<p><i>Enter dna pattern - <a href='http://www-unix.mcs.anl.gov/compbio/PatScan/HTML/readme_scan_for_matches.html'>detailed instructions found here</a></i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Molecular Weight'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  enter kD range eg. 40000,50000</i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}

		if(selected_parameter == 'Isoelectric Point'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  enter pI range eg. 5.0,5.3</i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Transmembrane Domains'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  enter number of TM domains as range eg. 2,4</i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}

		if(selected_parameter == 'Sequence Length'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  enter aa sequence length range  eg. 500,1000</i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		//if(selected_parameter == 'Conserved Neighborhood'){
		//    new_suffix_td.innerHTML = "<p> <input class='button' type='button' value='-' onClick='remove_search_box("+ box_number + ");'><p><i> finds genes with conserved genomic context</i></p>";
		//    row_div_obj.appendChild(new_suffix_td);
		//}

		if(selected_parameter == 'Conserved Neighborhood'){
		    new_suffix_td.innerHTML = "<p><i> finds genes with conserved genomic context</i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}

		if(selected_parameter == 'Similar to Human Protein'){
		    new_suffix_td.innerHTML = "<p><i> use NOT logical operator for non-similar proteins</i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		if(selected_parameter == 'Signal Peptide'){
		    new_suffix_td.innerHTML = "<p><i> use NOT logical operator for proteins without a signal peptide</i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}

		if(selected_parameter == 'Selected Amino Acid Content'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterAAC'><OPTION SELECTED>Alanine<OPTION>Arginine<OPTION>Asparagine<OPTION>Aspartate<OPTION>Cysteine<OPTION>Glutamate<OPTION>Glutamine<OPTION>Histidine<OPTION>Isoleucine<OPTION>Leucine<OPTION>Lysine<OPTION>Methionine<OPTION>Proline<OPTION>Serine<OPTION>Threonine<OPTION>Tryptophan<OPTION>Tyrosine<OPTION>Valine</SELECT><input type='textarea' name='search_term" + box_number + "' value='min%,max%' rows='1' columns='6'>"+ "<p><i>  set min,max percent range for selected amino acid (eg. Cysteine: 1,4)</i></p>";     
		    row_div_obj.appendChild(new_suffix_td);
		}
		
	        if(selected_parameter == 'Cellular Location'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterCL" + box_number + "'><OPTION>Cellwall<OPTION>Cytoplasmic<OPTION>CytoplasmicMembrane<OPTION>Extracellular<OPTION>OuterMembrane<OPTION>Periplasmic<OPTION>unknown</SELECT>"+ "<p><i>  eg. Cellwall</i></p>";     
		    row_div_obj.appendChild(new_suffix_td);
                }
		
	        if(selected_parameter == 'Gram_Stain'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterStain'><OPTION SELECTED>Negative<OPTION>Positive</SELECT>"+ "<p><i>  find genes in organism with selected gram stain </i></p>";     
                row_div_obj.appendChild(new_suffix_td);
                }
		
		if(selected_parameter == 'Shape'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterShape'><OPTION SELECTED>Branched filament<OPTION>Coccobacillus<OPTION>Coccus<OPTION>Curved<OPTION>Cylinder, Irregular rod<OPTION>Irregular<OPTION>Irregular coccus<OPTION>Oval, Rod<OPTION>Pleomorphic<OPTION>Pleomorphic coccus<OPTION>Pleomorphic rod<OPTION>Pleomorphic, Disk<OPTION>Rod<OPTION>Rod, Coccus<OPTION>Rod, Oval<OPTION>Sphere<OPTION>Spiral<OPTION>Square<OPTION>unknown</SELECT>"+ "<p><i>  eg. coccus </i></p>";     
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Arrangement'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterArrangement'><OPTION SELECTED>Aggregates<OPTION>Branched hyphae<OPTION>Clusters<OPTION>Filaments<OPTION>Pairs<OPTION>Pairs, Clusters<OPTION>Pairs, Tetrads, Aggregates<OPTION>Singles<OPTION>Singles, Aggregates<OPTION>Singles, Chains<OPTION>Singles, Clusters<OPTION>Singles, Filaments<OPTION>Singles, Pairs<OPTION>Singles, Pairs, Chains<Singles, V-shaped pairs<OPTION>unknown</SELECT>"+ "<p><i>  eg. Aggregates </i></p>";     
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Endospores'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterEndospores'><OPTION SELECTED>No<OPTION>Yes</SELECT>"+ "<p><i>  find genes in organisms with endopsores </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Motility'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterMotility'><OPTION SELECTED>No<OPTION>Yes</SELECT>"+ "<p><i>  find genes in motile organisms </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Pathogenic'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterPathogenic'><OPTION SELECTED>No<OPTION>Yes</SELECT>"+ "<p><i>  find genes in pathogenic organisms </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Salinity'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterSalinity'><OPTION SELECTED>Extreme halophilic<OPTION>Mesophilic<OPTION>Moderate Halophilic<OPTION>Non-halophilic<OPTION>unkown</SELECT>"+ "<p><i> eg. Mesophilic </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Oxygen_Requirement'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterOxygen_Requirement'><OPTION SELECTED>Aerobic<OPTION>Anaerobic<OPTION>Facultative<OPTION>Microaerophilic<OPTION>unknown</SELECT>"+ "<p><i> eg. Anaerobic </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Habitat'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterHabitat'><OPTION SELECTED>Aquatic<OPTION>Host-associated<OPTION>Multiple<OPTION>Specialized<OPTION>Terrestrial<OPTION>unkown</SELECT>"+ "<p><i>find genes in organisms with selected habitat </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
	    
		if(selected_parameter == 'Salinity'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterSalinity'><OPTION SELECTED>Extreme halophilic<OPTION>Mesophilic<OPTION>Moderate Halophilic<OPTION>Non-halophilic<OPTION>unkown</SELECT>"+ "<p><i> eg. Mesophilic </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Pathogenic_In'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterPathogenic_In'><OPTION SELECTED>Animal<OPTION>Avian<OPTION>Cattle<OPTION>Chicken<OPTION>Cyst-forming nematodes<OPTION>Equine<OPTION>Feline<OPTION>Ferret<OPTION>Fish<OPTION>Fish, Shellfish<OPTION>Gram-negative bacteria<OPTION>Human<OPTION>Human, Animal<OPTION>Human, Animal, Insect<OPTION>Human, Marine animal<OPTION>Human, Primate<OPTION>Human, Rodent<OPTION>Mammal, Insect, Plant<OPTION>Insect<OPTION>Maloid fruit trees<OPTION>No<OPTION>Onion<OPTION>Porcine<OPTION>Plant<OPTION>Ruminant<OPTION>Swine<OPTION>unkown<OPTION>Vertebrate and invertebrate aquatic organisms</SELECT>"+ "<p><i> eg. Ferret </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Disease'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterDisease'><OPTION SELECTED>Acne<OPTION>Acrodermatitis chronica atrophicans<OPTION>Acute inflammatory demyelinating polyneuropathy<OPTION>African heartwater<OPTION>Almond leaf scorch<OPTION>Anthrax<OPTION>Aster yellows witches-broom<OPTION>Atypical pneumonia in older children and young adults<OPTION>Bacillary angiomatosis, Cat scratch fever<OPTION>Bacillary angiomatosis, Trench fever<OPTION>Bacteremia<OPTION>Bacteremia, endocarditis, urinary tract infection<OPTION>Bacteremia, gastroenteritis<OPTION>Bacterial endocarditis<OPTION>Bacterial fruit blotch<OPTION>Bacterial spot<OPTION>Black rot<OPTION>Black rot and citrus canker<OPTION>Botulism<OPTION>Bovine anaplasmosis<OPTION>Bovine tuberculosis<OPTION>Brucellosis<OPTION>Brucellosis, infectious abortions, fever<OPTION>Bubonic plague<OPTION>Caries and periodontal diseases<OPTION>Carrions disease, Oroya fever<OPTION>Cell lysis<OPTION>Cellular destruction<OPTION>Cholera<OPTION>Chronic granulomatous disease<OPTION>Chronic respiratory disease in chicken<OPTION>Chronic respiratory diseases<OPTION>Citrus canker<OPTION>Citrus variegated chlorosis<OPTION>Cold water disease, rainbow trout fry syndrome<OPTION>Colibacillosis<OPTION>Contagious bovine pleuropneumonia (CBPP<OPTION>Corn stunt<OPTION>Dental caries<OPTION>Diarrhea<OPTION>Diarrhea and occasionally septicemia<OPTION>Diarrheal disease<OPTION>Diphtheria<OPTION>Dysentery<OPTION>Ehrlichiosis<OPTION>Encephalitis, urinary tract infections, surgical wound infections, pyelonephritis, pneumonia, septicemia<OPTION>Endemic typhus and murine typhus<OPTION>Endocarditis<OPTION>Enteric septicemia<OPTION>Enzootic pneumonia<OPTION>Fibrinous and necrotizing pleuropneumonia<OPTION>Fire Blight<OPTION>Food poisoning<OPTION>Gas gangrene<OPTION>Gastric inflammation and peptic ulcer disease<OPTION>Gastric lesions<OPTION>Gastric ulcerations<OPTION>Gastroenteritis<OPTION>Gastroenteritis and diarrhea<OPTION>Gastroenteritis and food poisoning<OPTION>Gastroenteritis and septicemia<OPTION>Gastroenteritis, wound infections, primary septicemia<OPTION>Gastrointestinal disease<OPTION>Genital ulcer disease<OPTION>Glanders and pneumonia<OPTION>Gonorrhea<OPTION>Guillain-Barre syndrome<OPTION>Heartwater<OPTION>Hemorrhagic colitis<OPTION>Hepatitis, typhlitis, hepatocellular tumors, and gastric bowel disease<OPTION>Human cystitis<OPTION>Human granulocytic anaplasmosis<OPTION>Infections of the urogenital or respiratory tracts<OPTION>Infertility, infectious abortions, septicemia, meningitis<OPTION>Legionnaires disease<OPTION>Leprosy<OPTION>Leptospirosis<OPTION>Listeriosis<OPTION>Louse-borne typhus, Mediterranean spotted fever, epidemic typhus<OPTION>Lyme disease<OPTION>Mastitis<OPTION>Melioidosis<OPTION>Meningitis<OPTION>Meningitis and septicemia<OPTION>Meningitis, speticemia, otitis media, sinusitis, chronic bronchitis<OPTION>Miller Fisher syndrome<OPTION>Monocytic ehrlichiosis<OPTION>Mushroom workers disease, farmers lung disease<OPTION>Necrotizing pneumonia and chronic infections<OPTION>Necrotizing pneumonia and chroninc infections<OPTION>Necrotizing pneumonia, chronic infections<OPTION>Neonatal GBS meningitis<OPTION>Nocardiosis<OPTION>Nocosomial infections<OPTION>None<OPTION>Nosocomial infections in immunocompromised individuals<OPTION>Nosocomial infections, nosocomial pneumonia<OPTION>Oleander leaf scorch<OPTION>Onions yellow disease<OPTION>Opportunistic infections<OPTION>Opportunistic peritoneal diseases<OPTION>Paratuberculosis<OPTION>Paratyphoid fever<OPTION>Pasteurellosis<OPTION>Periodontal disease<OPTION>Periodontal disease, gum inflamation<OPTION>Periodontal diseases and some inflammations<OPTION>Persistent diarrhea<OPTION>Pharyngitis, bronchitis and pneumonitis<OPTION>Plant rot<OPTION>Pneumonia<OPTION>Pneumonia, Meningitis, Bacteremia, Sinusitis, Otitis media, Conjunctivitis<OPTION>Pneumonia, arthritis, myocarditis, and reproductive problems<OPTION>Probable pneumonia agent<OPTION>Psittacosis<OPTION>Q fever<OPTION>Rare opportunistic pathogen of humans<OPTION>Ratoon stunting disease<OPTION>Respiratory deseases<OPTION>Respiratory diseases<OPTION>Respiratory mycoplasmosis<OPTION>Rice bacterial blight disease<OPTION>Rickettsialpox<OPTION>Rocky Mountain Spotted Fever<OPTION>Salmonellosis and swine paratyphoid<OPTION>Scab disease<OPTION>Sennetsu fever<OPTION>Septicemia, pneumonia<OPTION>Septicemia, pneumonia, and meningitis<OPTION>Severe arthritis and septicemia<OPTION>Severe infection, diarrhea, and abcesses<OPTION>Shell disease<OPTION>Skin infections, pneumonia, endocarditis<OPTION>Soft rot disease of potatoes<OPTION>Soft tissue infections<OPTION>Soft tissue infections, bacteremia<OPTION>Soft tissue lesions<OPTION>Sotto disease<OPTION>Spotted-fever like illness<OPTION>Strangles<OPTION>Swine mycoplasmosis<OPTION>Syphilis<OPTION>Tetanus<OPTION>Toxemia and septicemia<OPTION>Toxic-shock syndrome and staphylococcal scarlet fever<OPTION>Tuberculosis<OPTION>Tuberculosis attenuated<OPTION>Tuberculosis in cattle<OPTION>Tularemia<OPTION>Tumors<OPTION>Typhoid fever<OPTION>Upper respiratory tract infections<OPTION>Urinary tract infections<OPTION>Urogenital or respiratory tract infections<OPTION>Urogenital or respiratory tracts infections<OPTION>Variety of infections<OPTION>Vibriosis<OPTION>Whipples disease<OPTION>Wide range of infections<OPTION>Wide range of opportunistic infections<OPTION>Wilt and Tuber Rot, Ring Rot<OPTION>unknown</SELECT>"+ "<p><i> eg. Typhoid fever </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'Temperature_Range'){
		    new_suffix_td.innerHTML = "<SELECT NAME='FilterTemperature_Range'><OPTION SELECTED>Hyperthermophilic<OPTION>Mesophilic<OPTION>Psychrophilic<OPTION>Thermophilic<OPTION>unkown</SELECT>"+ "<p><i> eg. Thermophilic </i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		
		if(selected_parameter == 'GC_Content'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  enter GC content range  eg. 20,30</i></p>";
		    row_div_obj.appendChild(new_suffix_td);
		}
		if(selected_parameter == 'Optimal_Temperature'){
		    new_suffix_td.innerHTML = "<input type='textarea' name='search_term" + box_number + "' value='' rows='1' columns='120'>"+ "<p><i>  enter optimal temperature range  eg. 35,40</i></p>";
                row_div_obj.appendChild(new_suffix_td);
		}
	    }	
	}
    
    </script>
   ~;
}

#javascript for adding additional search parameter when '+' is pressed
sub add_search_box_js {
    return qq~
	<script>
	function add_search_box () {
	    var box_number = document.getElementsByName('row_div').length + 1 + rows_deleted_count;
	    var suffix_count = document.getElementsByName('new_suffix_td').length + rows_deleted_count;
	    if( suffix_count + 1 == box_number){
	       var row_div_id = 'row_div_' + box_number;
	       var table_obj = document.getElementById('search_table_1').firstChild;
	       var new_row_obj = document.createElement('TR');
	       new_row_obj.style.padding = '0px';
	       new_row_obj.setAttribute('name','row_div');
	       new_row_obj.setAttribute('id', row_div_id);
	       var minus_button = "<input class='button' type='button' value='-' onClick='remove_search_box("+ box_number + ");'>";
	       if(box_number == 1){minus_button = "";}
	
	      // new_row_obj.innerHTML = "<TD><SELECT NAME='logic_operator" + box_number + "'><OPTION SELECTED>AND<OPTION>OR<OPTION>NOT</SELECT>" + "<SELECT NAME='Filter"+ box_number + "' ID='Filter" + box_number + "' onChange='add_suffix_search_box(" + box_number + ");'" + "><OPTION SELECTED>Select Parameter<OPTION>Cellular Location" + box_number + "<OPTION>Conserved Neighborhood<OPTION>EC Number or Function<OPTION value='ID'>ID, any gene/protein identifier</OPTION><OPTION value='ID'>ID, ASAP</OPTION><OPTION value='ID'>ID, JGI</OPTION><OPTION value='ID'>ID, KEGG</OPTION><OPTION value='ID'>ID, NCBI</OPTION><OPTION value='ID'>ID, PIR</OPTION><OPTION value='ID'>ID, RefSeq</OPTION><OPTION value='ID'>ID, SwissProt</OPTION><OPTION value='ID'>ID, TIGR</OPTION><<OPTION value='ID'>ID, TREMBL</OPTION><OPTION value='ID'>ID, UniProt</OPTION><OPTION>Isoelectric Point<OPTION>Molecular Weight<OPTION value='Endospores'>Organism, Endospore Production</OPTION><OPTION value='GC_Content'>Organism, GC Content of</OPTION><OPTION value='Gram_Stain'>Organism, Gram Stain of</OPTION><OPTION value='Habitat'>Organism, Habitat of</OPTION><OPTION value='Lineage'>Organism, Lineage</OPTION><OPTION value='Motility'>Organism, Motility of</OPTION><OPTION value='Organism Name'>Organism, Name</OPTION><OPTION value='Oxygen_Requirement'>Organism, Oxygen Requirement of</OPTION>Organism, Oxygen Requirement of</OPTION><OPTION value='Optimal_Temperature'>Organism, Optimal Temperature of</OPTION><OPTION value='Pathogenic'>Organism, Pathogenic</OPTION><OPTION value='Pathogenic_In'>Organism, Host of Pathogenic</OPTION><OPTION value='Salinity'>Organism, Salinity of</OPTION><OPTION value='Temperature_Range'>Organism, Temperature Range of</OPTION><OPTION value='Taxon ID'>Organism, Taxon ID</OPTION><OPTION>PatScan Sequence, AA<OPTION>PatScan Sequence, DNA<OPTION>PFAM ID<OPTION>PFAM Name<OPTION>Selected Amino Acid Content<OPTION>Sequence Length<OPTION>Signal Peptide<OPTION>Similar to Human Protein<OPTION>Subsystem<OPTION>Transmembrane Domains</SELECT>" + minus_button + "</TD>";
	       new_row_obj.innerHTML = "<TD><SELECT NAME='logic_operator" + box_number + "'><OPTION SELECTED>AND<OPTION>OR<OPTION>NOT</SELECT>" + "<SELECT NAME='Filter"+ box_number + "' ID='Filter" + box_number + "' onChange='add_suffix_search_box(" + box_number + ");'" + "><OPTION SELECTED>Select Parameter<OPTION>Cellular Location<OPTION>Conserved Neighborhood<OPTION>EC Number or Function<OPTION value='ID'>ID, any gene/protein identifier</OPTION><OPTION value='ID'>ID, ASAP</OPTION><OPTION value='ID'>ID, JGI</OPTION><OPTION value='ID'>ID, KEGG</OPTION><OPTION value='ID'>ID, NCBI</OPTION><OPTION value='ID'>ID, PIR</OPTION><OPTION value='ID'>ID, RefSeq</OPTION><OPTION value='ID'>ID, SwissProt</OPTION><OPTION value='ID'>ID, TIGR</OPTION><<OPTION value='ID'>ID, TREMBL</OPTION><OPTION value='ID'>ID, UniProt</OPTION><OPTION>Isoelectric Point<OPTION>Molecular Weight<OPTION value='Endospores'>Organism, Endospore Production</OPTION><OPTION value='GC_Content'>Organism, GC Content of</OPTION><OPTION value='Gram_Stain'>Organism, Gram Stain of</OPTION><OPTION value='Habitat'>Organism, Habitat of</OPTION><OPTION value='Lineage'>Organism, Lineage</OPTION><OPTION value='Motility'>Organism, Motility of</OPTION><OPTION value='Organism Name'>Organism, Name</OPTION><OPTION value='Oxygen_Requirement'>Organism, Oxygen Requirement of</OPTION>Organism, Oxygen Requirement of</OPTION><OPTION value='Optimal_Temperature'>Organism, Optimal Temperature of</OPTION><OPTION value='Pathogenic'>Organism, Pathogenic</OPTION><OPTION value='Pathogenic_In'>Organism, Host of Pathogenic</OPTION><OPTION value='Salinity'>Organism, Salinity of</OPTION><OPTION value='Temperature_Range'>Organism, Temperature Range of</OPTION><OPTION value='Taxon ID'>Organism, Taxon ID</OPTION><OPTION>PatScan Sequence, AA<OPTION>PatScan Sequence, DNA<OPTION>PFAM ID<OPTION>PFAM Name<OPTION>Selected Amino Acid Content<OPTION>Sequence Length<OPTION>Signal Peptide<OPTION>Similar to Human Protein<OPTION>Subsystem<OPTION>Transmembrane Domains</SELECT>" + minus_button + "</TD>";

	       table_obj.appendChild(new_row_obj);
	   }
	}
	 
     </script>~;
}

sub add_global_variable_js {
    return qq~
	<script>
	var rows_deleted_count = 0;  
    </script>~;
}

sub add_search_spinner_js {
    return qq~
	<script>
	function add_search_spinner () {
	    var spinner_here_div_obj = document.getElementById('spinner_here');
	    var spinner_div = document.createElement('DIV');
	    spinner_div.setAttribute('name', 'spinner_div');
	    spinner_div.innerHTML = "<img src=\"$FIG_Config::cgi_url/Html/ajax-loader.gif\"><em>" + "Performing Search ..." + "</em>";
	    spinner_here_div_obj.appendChild(spinner_div);
	}
	 
     </script>~;
}

#javascript for removing search parameter when '-' is pressed
sub remove_search_box_js {
    return qq~
	<script>
	function remove_search_box (row_num) {
	    var row_obj_id = 'row_div_' + row_num;
	    document.getElementById('search_table_1').deleteRow(document.getElementById(row_obj_id).rowIndex);
	    rows_deleted_count = rows_deleted_count + 1;
	}
	 
     </script>~;
}


sub require_javascript{
    return ["$FIG_Config::cgi_url/Html/checkboxes_old.js"];
}

sub get_subsystems_column{
    my ($fig, $ids) = @_;

    my %in_subs  = $fig->subsystems_for_pegs($ids);
    my %column;
    foreach my $id (@$ids){
	my @in_sub = @{$in_subs{$id}} if (defined $in_subs{$id});
	my @subsystems;
	
        if (@in_sub > 0) {
	    my $count = 1;
	    foreach my $array(@in_sub){
		push (@subsystems, $count . ". " . $$array[0]);
		$count++;
	    }
            my $in_sub_line = join ("<br>", @subsystems);
	    $column{$id} = $in_sub_line;
        } else {
            $column{$id} = "&nbsp;";
        }
    }
    return (%column);
}

sub get_prefer {
    my ($cgi, $fid, $db, $all_aliases) = @_;
    foreach my $alias (@{$$all_aliases{$fid}}){
	my $id_db = &Observation::get_database($alias);
	if ($id_db eq $db){
	    my $acc_col .= &HTML::set_prot_links($cgi,$alias);
	    return ($acc_col);
	}
    }
    #return (" ");
}


sub get_peg_attributes_column{
    my ($fig, $ids) = @_;
    my $count = 0;
    my (%iso_col, %mw_col,%loc_col,%pfam_col,%ps_col,%ev_col,%sp_col,%tm_col,%sim2hum_col,%code_attributes);

    my $dbmaster = DBMaster->new(-database=>'Ontology',-host=>'bioseed.mcs.anl.gov',-user=>'rast');	
    #my $dbmaster = DBMaster->new(-database =>'Ontology');

    Trace("new way start") if T(3);
    foreach my $peg (@$ids){
	my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'isoelectric_point'], ['Property(property-name)','Property(property-value)']);
	foreach my $oq (@outer_query){
	    my ($key,$value) = @$oq;
	    my @group = ($peg,$key,$value);
	    push (@{$code_attributes{$peg}}, \@group);
	}
	@outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'molecular_weight'], ['Property(property-name)','Property(property-value)']);
	foreach my $oq (@outer_query){
	    my ($key,$value) = @$oq;
	    my @group = ($peg,$key,$value);
	    ##Trace("$key $value") if T(3);
	    push (@{$code_attributes{$peg}}, \@group);
	}

	@outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) LIKE ?", [$peg,'PFAM%'], ['Property(property-name)','Property(property-value)']);
	foreach my $oq (@outer_query){
	    my ($key,$value) = @$oq;
	    my @group = ($peg,$key,$value);
	    #Trace("$key $value") if T(3);
	    push (@{$code_attributes{$peg}}, \@group);
	}

	@outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'evidence_code'], ['Property(property-name)','Property(property-value)']);
	foreach my $oq (@outer_query){
	    my ($key,$value) = @$oq;
	    my @group = ($peg,$key,$value);
	    ##Trace("$key $value") if T(3);
	    push (@{$code_attributes{$peg}}, \@group);
	}

	@outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) LIKE ?", [$peg,'PSORT%'], ['Property(property-name)','Property(property-value)']);
	foreach my $oq (@outer_query){
	    my ($key,$value) = @$oq;
	    my @group = ($peg,$key,$value);
	    ##Trace("$key $value") if T(3);
	    push (@{$code_attributes{$peg}}, \@group);
	}

=head	
#too slow, add in again once Bruce adds similar_to_human to Feature table
	my @outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) = ?", [$peg,'similar_to_human'], ['Property(property-value)']);
        foreach my $oq (@outer_query){
            my ($value) = @$oq;   
	    my @group = ($peg,"similar_to_human",$value);
	    push (@{$code_attributes{$peg}}, \@group);
	    #Trace("similar_to_human: $value") if T(3);
	}
=cut
	@outer_query = $fig->sprout->GetAll(['Feature','HasProperty','Property'], "Feature(id) = ? AND Property(property-name) LIKE ?", [$peg,'Phobius%'], ['Property(property-name)','Property(property-value)']);
	foreach my $oq (@outer_query){
	    my ($key,$value) = @$oq;
	    my @group = ($peg,$key,$value);
	    ##Trace("$key $value") if T(3);
	    push (@{$code_attributes{$peg}}, \@group);
	}
    }

    
    my %complete_genome_hash;
    my @complete_genomes = $fig->genomes('complete');
    foreach my $cg (@complete_genomes){
	$complete_genome_hash{$cg} = 1;
    }
    
    foreach my $id (@$ids){
	my $genome;
	if($id =~/fig\|(\d+\.\d+).peg/){
	    $genome = $1;
	}
	
	my $ev_codes;
	my $iso_codes;
	my $mw_codes;
	my $pfam_codes;
	my $ps_codes;
	my $loc_codes;
	my $tm_codes;
	my $sp_codes;
	my $sim2hum_codes;
	
	#set defaults for attribute column cells
	#NONE, NO or 0 in cell indicates tool has been run on genome's peg but no result was found
        #blank space in cell indicates tool has not yet been run on genome's peg
 		   
	if($complete_genome_hash{$genome}){
	    $ev_codes=" NONE ";
	    $iso_codes=" &nbsp; ";
	    $mw_codes=" &nbsp; ";
	    $pfam_codes=" NONE ";
	    $loc_codes=" unknown ";
	    $tm_codes=" 0 ";
	    $sp_codes=" NO ";
	    #$sim2hum_codes=" NO ";
	    $sim2hum_codes=" not available ";
	}
	else{
	    $ev_codes=" &nbsp; ";
	    $iso_codes=" &nbsp; ";
	    $mw_codes=" &nbsp; ";
	    $pfam_codes=" &nbsp; ";
	    $loc_codes=" &nbsp; ";
	    $tm_codes=" &nbsp; ";
	    $sp_codes=" &nbsp; ";
	    $sim2hum_codes=" &nbsp; ";
	}
	
	my @ev_codes = "";
	my @iso_codes = "";
	my @mw_codes = "";
	my @pfam_codes = "";
	my @loc_codes = "";
	my @tm_codes = "";
	my @sp_codes = "";
	my @sim2hum_codes = "";

        if ($id =~ /^fig\|\d+\.\d+\.peg\.\d+$/) {
            my @codes;
            @codes = @{$code_attributes{$id}} if (defined @{$code_attributes{$id}});
            @ev_codes = ();
	    @iso_codes = ();
	    @mw_codes = ();
	    @pfam_codes = ();
	    @loc_codes = ();
	    @tm_codes = ();
	    @sp_codes = ();
	    @sim2hum_codes = ();
            foreach my $code (@codes) {
                my $key = $code->[1];
		my $value = $code->[2];
		if($key =~/evidence/){
		    push(@ev_codes, $value);
		}
		elsif($key eq "isoelectric_point"){
		    push(@iso_codes, $value);
		}
		elsif($key eq "molecular_weight"){
		    push(@mw_codes, $value);
		}
		elsif($key eq "similar_to_human"){
		    $value = uc($value); 
		    push(@sim2hum_codes, $value);
		}
		elsif($key =~/PSORT/){
		    if($key !~/score/){
			my @parts = split("::",$key);
			push(@loc_codes, $parts[1]);
		    }
		}
		elsif($key =~/Phobius/){
		    my @parts = split("::",$key);
		    if($parts[1] eq "transmembrane"){
			my @values = split(",",$value);
			foreach my $v (@values){
			    push(@tm_codes, $v);
			}
		    }
		    else{
			push(@sp_codes, "YES");
		    }
		}
		elsif($key =~/PFAM/){
		    if($key !~/download/){
			my @parts = split("::",$key);
			if($value =~/;(.*)/){
			    my $loc =  $1;
			    my $pfam_link = "<a href=http://pfam.sanger.ac.uk/family?acc=" . $parts[1] . ">$parts[1] $loc</a>&nbsp";
			    push(@pfam_codes, $pfam_link);
			}
		    }
		}
	    }
        }

	if (scalar(@ev_codes) > 0) {
            my $ev_code_help=join("<br />", map {&HTML::evidence_codes_explain($_)} @ev_codes);
            $ev_codes = CGI::a({id=>"evidence_codes", onMouseover=>"javascript:if(!this.tooltip) this.tooltip=new Popup_Tooltip(this, 'Evidence Codes', '$ev_code_help', ''); this.tooltip.addHandler(); return false;"}, join("<br />", @ev_codes));
        }
	$ev_col{$id}=$ev_codes;

	if (scalar(@iso_codes) && $iso_codes[0]) {
              $iso_codes = CGI::a({id=>"iso_codes"}, join("<br />", @iso_codes));
        }
	$iso_col{$id}=$iso_codes;

	if (scalar(@mw_codes) && $mw_codes[0]) {
              $mw_codes = CGI::a({id=>"mw_codes"}, join("<br />", @mw_codes));
        }
	$mw_col{$id}=$mw_codes;

	if (scalar(@loc_codes) && $loc_codes[0]) {
              $loc_codes = CGI::a({id=>"loc_codes"}, join("<br />", @loc_codes));
        }
	$loc_col{$id}=$loc_codes;

	if (scalar(@pfam_codes) && $pfam_codes[0]) {
              $pfam_codes = CGI::a({id=>"pfam_codes"}, join("<br />", @pfam_codes));
        }
        $pfam_col{$id}=join("<br><br>", @pfam_codes);

	if (scalar(@sp_codes) && $sp_codes[0]) {
              $sp_codes = CGI::a({id=>"sp_codes"}, join("<br />", @sp_codes));
        }
	$sp_col{$id}=$sp_codes;

	if (scalar(@tm_codes) && $tm_codes[0]) {
              $tm_codes = CGI::a({id=>"tm_codes"}, join("<br />", @tm_codes));
        }
	$tm_col{$id}=$tm_codes;
    
	if (scalar(@sim2hum_codes) && $sim2hum_codes[0]) {
              $sim2hum_codes = CGI::a({id=>"sim2hum_codes"}, join("<br />", @sim2hum_codes));
        }
	$sim2hum_col{$id}=$sim2hum_codes;

    }

    ##Trace("old way finished") if T(3);
    Trace("new way finished") if T(3);
    return (\%iso_col,\%loc_col,\%mw_col,\%pfam_col,\%ev_col,\%sp_col,\%tm_col,\%sim2hum_col);
}

sub get_conserved_neighborhood_column{
    my ($fig, $ids) = @_;
    my %cn_col;

    foreach my $id (@$ids){
        if ($id =~ /^fig\|\d+\.\d+\.peg\.\d+$/) {
	    my @results = $fig->coupled_to($id);
	    if($results[0]){
		$cn_col{$id} = "YES";
	    }
	    else{
		$cn_col{$id} = "NO";
	    }
	}
    }

    return (\%cn_col);
}

sub get_sequence_length_column{
    my ($fig, $ids) = @_;
    my %sl_col;

    foreach my $id (@$ids){
        if ($id =~ /^fig\|\d+\.\d+\.peg\.\d+$/) {
            Trace("Retrieving translation for $id.") if T(4);
	    my $seq = $fig->get_translation($id);
	    my $len = length($seq);
            Trace("Translation length is $len.") if T(4);
	    $sl_col{$id} = $len;
	}
    }

    return (\%sl_col);
}


sub get_phenotype_column{
    my ($fig, $ids) = @_;
    my (%column, %code_attributes);

    my %genomes;
    foreach my $id (@$ids){
	if($id =~/(\d+\.\d+)\.peg/){
	    $genomes{$1} = 1;
	}
    }

    my @genomes_array = keys(%genomes);
  
    my @codes = grep { $_->[1] =~ /(Gram_Stain|GC_Content|Shape|Arrangement|Endospores|Motility|Salinity|Oxygen_Requirement|Habitat|Temperature_Range|Optimal_Temperature|Pathogenic|Pathogenic_In|Disease)/ } Observation->get_attributes($fig,\@genomes_array);
    foreach my $key (@codes){
        push (@{$code_attributes{$$key[0]}}, $key);
    }

    foreach my $id (@$ids){
	# add evidence code with tool tip
        my $ev_codes=" &nbsp; ";
        my @ev_codes = "";
	
        if ($id =~ /^fig\|(\d+\.\d+)\.peg\.\d+$/) {
            my @codes;
	    my $genome =  $1;
            @codes = @{$code_attributes{$genome}} if (defined @{$code_attributes{$genome}});
            @ev_codes = ();
            foreach my $code (@codes) {
		my $key = $code->[1];
                my $value = $code->[2];
		my $pretty_code = "$key:$value";
		push(@ev_codes, $pretty_code);
            }
        }

        if (scalar(@ev_codes) && $ev_codes[0]) {
            $ev_codes = CGI::a({id=>"phenotypes"}, join("<br/>\t", @ev_codes));
        }
	$column{$id}=$ev_codes;
    }
    return (%column);
}

=head3 CheckCriterion

    my $matches = CheckCriterion($filter, \@parms, $featureData, \%genomeHash,
                                 $fig, $cgi);

Determine whether or not the specified feature matches the specified
criterion. The criterion is specified as a field name and zero or more
parameters. The feature is specified using an [[ERDBObjectPm]] which
contains at the very least a full Feature record from the database. In
general, if we need additional data about the feature to evaluate the
criterion, we'll add it to the object. This helps us to speed up the
display process later.

=over 4

=item filter

Name of the relevant field.

=item parms

Parameters specified by the user for the search.

=item featureData

Feature to match against the criterion.

=item genomeHash

A hash that maps genome IDs to [[ERDBObjectPm]] objects with the
corresponding genome data in them.

=item fig

[[SFXlatePm]] object to use to access the database.

=item cgi

CGI query obect containing additional parameters that might be needed.

=item RETURN

Returns TRUE if the feature qualifies under the criterion, else FALSE.

=back

=cut

sub CheckCriterion {
    # Get the parameters.
    my ($filter, $parms, $featureData, $genomeHash, $fig, $cgi) = @_;
    # Declare the return variable. We'll set it to TRUE if we match.
    my $retVal = 0;
    # Get the feature and genome IDs just for fun.
    my $peg = $featureData->PrimaryValue('Feature(id)');
    my $genomeID = $fig->genome_of($peg);
    # Get the parameters.
    my ($parm1, $parm2) = @$parms;
    # This is the big, ugly IF used to evaluate each possible criterion.
    if($filter eq "ID") {
        # Checking via alias.
        CheckAliases($featureData, $fig, $peg);
        $retVal = grep { $_ eq $parm1 } $featureData->Value('Feature(alias-list)');
    } elsif ($filter eq "FigID") {
        # Checking via FIG ID.
        $retVal = ($peg eq $parm1);
    } elsif ($filter eq "Subsystem") {
        # Checking via Subsystem name.
        CheckSubsystems($featureData, $fig, $peg);
        $retVal = grep { $_ eq $parm1 } $featureData->Value('Feature(subsystem-list)');
    } elsif ($filter eq "Lineage") {
        # Checking for a match inside the taxonomy.
        CheckGenome($featureData, $genomeHash, $fig, $genomeID);
        $parm1 =~ s/%//g;
        my $taxonomy = $genomeHash->{$genomeID}->PrimaryValue('Genome(taxonomy)');
        $retVal = ($taxonomy =~ /$parm1/i);
    } elsif ($filter eq "Conserved Neighborhood") {
        # Checking to see if the peg is pinned (has coupled-to features).
        CheckCoupling($featureData, $fig, $peg);
        $retVal = $featureData->Value('Feature(coupled-to)');
    } elsif ($filter eq "Organism Name") {
        # Checking the organism name.
        CheckGenome($featureData, $genomeHash, $fig, $genomeID);
        $retVal = $featureData->PrimaryValue('Genome(name)') eq $parm1;
    } elsif ($filter eq "EC Number or Function") {
        # Check for a substring in the assignment.
        $parm1 =~ s/%//g;
        $retVal = ($featureData->PrimaryValue('Feature(assignment)') =~ /$parm1/i);
    } elsif ($filter eq "PFAM ID") {
        # Check for a matching PFAM ID.
        CheckPFams($featureData, $fig, $peg);
        $retVal = grep { $_ eq $parm1 } $featureData->Value('Feature(pfams)');
    } elsif ($filter eq "PFAM Name") {
        # Check for a matching PFAM name.
        CheckPFams($featureData, $fig, $peg);
        $retVal = grep { $_ eq $parm1 } $featureData->PrimaryValue('Feature(pfam-names)');
    } elsif ($filter eq "Molecular Weight") {
        $retVal = Tracer::In($featureData->PrimaryValue('Feature(molecular-weight)'), $parm1, $parm2);
    } elsif ($filter eq "Isoelectric Point") {
        $retVal = Tracer::In($featureData->PrimaryValue('Feature(isoelectric-point)'), $parm1, $parm2);
    } elsif ($filter eq "Sequence Length") {
        $retVal = Tracer::In($featureData->PrimaryValue('Feature(sequence-length)'), $parm1, $parm2);
    } elsif ($filter eq "Taxon ID") {
        # Check the organism ID.
        $retVal = ($genomeID eq $parm1);
    } elsif ($filter eq "Cellular Location") {
        # Check for a matching cellular location.
        CheckCello($featureData, $fig, $peg);
        $retVal = grep { $_ eq $parm1 } $featureData->Value('Feature(cell-locations)');
    } elsif ($filter eq "Signal Peptide") {
        $retVal = ($featureData->PrimaryValue('Feature(signal-peptide)') ? 1 : 0);
    } elsif ($filter eq "Transmembrane Domains") {
        $retVal = ($featureData->PrimaryValue('Feature(transmembrane-map)') ? 1 : 0);
    } elsif ($filter eq "PatScan Sequence, AA") {
        # This is an amino acid pattern match.
        if ($peg =~ /peg/) {
            my $translation = $featureData->PrimaryValue('Feature(translation)');
            my @matchLocations = DoPatScan($translation, $parm1);
            $retVal = @matchLocations;
            $featureData->AddValues('Feature(protScan)' => @matchLocations);
        }
    } elsif ($filter eq "PatScan Sequence, DNA") {
        # This is a nucleotide pattern match.
        my $locs = $featureData->PrimaryValue('Feature(location-string)');
        my $dna = $fig->dna_seq($genomeID, split(/\s*.\s*/,$locs));
        my @matchLocations = DoPatScan($dna, $parm1);
        $retVal = @matchLocations;
        $featureData->AddValues('Feature(dnaScan)' => @matchLocations);
    } elsif ($filter eq "Selected Amino Acid Content") {
        # Here we're looking for a percentage content of a particular amino acid.
        # First, we need to convert from percents to fractions, and set default
        # values.
        $parm1 = ($parm1 ? $parm1/100 : 0);
        $parm2 = ($parm2 ? $parm2/100 : 1);
        
    } elsif ($filter eq "GC_Content") {
    } elsif ($filter eq "Gram_Stain") {
    } elsif ($filter eq "Shape") {
    } elsif ($filter eq "Arrangement") {
    } elsif ($filter eq "Endospores") {
    } elsif ($filter eq "Motility") {
    } elsif ($filter eq "Salinity") {
    } elsif ($filter eq "Oxygen_Requirement") {
    } elsif ($filter eq "Habitat") {
    } elsif ($filter eq "Temperature_Range") {
    } elsif ($filter eq "Pathogenic") {
    } elsif ($filter eq "Pathogenic_In") {
    } elsif ($filter eq "Disease") {
    } elsif ($filter eq "Similar to Human Protein") {
    }
    # Return the result.
    return $retVal;
}


=pod
    
	    if($filter eq "ID"){ $task = 'do_index_search'; }
	    elsif($filter eq "Subsystem"){ $task = 'do_subsystem_search'; }
	    elsif($filter eq "Lineage"){ $task = 'do_lineage_search'; }
	    elsif($filter eq "Conserved Neighborhood"){ $task = 'pinned_region_search'; }
	    elsif($filter eq "Organism Name"){ $task = 'do_lineage_search'; }
	    elsif($filter eq "EC Number or Function"){ $task = 'do_function_search'; }
	    elsif($filter eq "PFAM ID"){ $task = 'do_pfam_id_search'; }
	    elsif($filter eq "PFAM Name"){ $task = 'do_pfam_name_search'; }
	    elsif($filter eq "Molecular Weight"){ $task = 'mw_search'; }
	    elsif($filter eq "Isoelectric Point"){ $task = 'do_iso_search'; }
	    elsif($filter eq "Sequence Length"){ $task = 'do_length_search'; }
	    elsif($filter eq "Taxon ID"){ $task = 'do_taxon_id_search'; }
	    elsif($filter eq "Cellular Location"){
              my $cl_param = "FilterCL".$cellular_location_count;
	      $search_term = $cgi->param($cl_param);
	      $task = 'do_location_search';
	    }
	    elsif($filter eq "Signal Peptide"){ $task = 'do_signal_peptide_search'; }
	    elsif($filter eq "Transmembrane Domains"){ $task = 'do_transmembrane_search'; }
	    elsif($filter eq "PatScan Sequence, AA"){ $task = 'do_aa_pattern_search'; }
	    elsif($filter eq "PatScan Sequence, DNA"){ $task = 'do_dna_pattern_search'; }
	    elsif($filter eq "Selected Amino Acid Content"){
              $task = 'do_aa_percent_search';
              $filter = $cgi->param('FilterAAC');
            }
	    elsif($filter eq "GC_Content"){ $task = 'do_phenotype_range_search'; }
	    elsif($filter eq "Gram_Stain"){ $task = 'do_phenotype_search'; $search_term = $cgi->param('FilterStain');}
	    elsif($filter eq "Shape"){ $task = 'do_phenotype_search'; $search_term = $cgi->param('FilterShape');}
	    elsif($filter eq "Arrangement"){ $task = 'do_phenotype_search'; $search_term = $cgi->param('FilterArrangement');}
	    elsif($filter eq "Endospores"){ $task = 'do_phenotype_search'; $search_term = $cgi->param('FilterEndospores');}
	    elsif($filter eq "Motility"){ $task = 'do_phenotype_search'; $search_term = $cgi->param('FilterMotility');}
	    elsif($filter eq "Salinity"){ $task = 'do_phenotype_search'; $search_term = $cgi->param('FilterSalinity');}
	    elsif($filter eq "Oxygen_Requirement"){ $task = 'do_phenotype_search'; $search_term = $cgi->param('FilterOxygen_Requirement');}
	    elsif($filter eq "Habitat"){ $task = 'do_phenotype_search'; $search_term = $cgi->param('FilterHabitat');}
	    elsif($filter eq "Temperature_Range"){ $task = 'do_phenotype_search'; $search_term = $cgi->param('FilterTemperature_Range');}
	    elsif($filter eq "Pathogenic"){ $task = 'do_phenotype_search'; $search_term = $cgi->param('FilterPathogenic');}
	    elsif($filter eq "Pathogenic_In"){ $task = 'do_phenotype_search'; $search_term = $cgi->param('FilterPathogenic_In');}
	    elsif($filter eq "Disease"){ $task = 'do_phenotype_search'; $search_term = $cgi->param('FilterDisease');}
	    elsif($filter eq "Similar to Human Protein"){ $task = 'do_similar_to_human_search'; }
	}
    	my $mikeThing = { fig => $fig,
                          cgi => $cgi,
                          filter => $filter,
                          search_term => $search_term,
                          lop => $lop,
                          search_summary => $search_summary,
                          pegs_to_save => $pegs_to_save,
                          concat_or_results => $concat_or_results,
                          peg_param_hits => $peg_param_hits,
                          feature_hash => \%featureHash };
        Trace("Mike thing =\n" . Data::Dumper::Dumper($mikeThing)) if T(3); Confess("##HACK");
          ($pegs_returned,$mikeThing->{search_summary},$mikeThing->{peg_param_hits}) = eval("$task(\$mikeThing)");
          if ($@) {
            Confess("Target Search Error: $@");
          }
          if((! $concat_or_results) && ($lop eq "OR")){foreach my $peg (@$pegs_returned){$returned_or_pegs{$peg} = 1;}}
          else{$mikeThing->{pegs_to_save} = $pegs_returned;
          if($search_summary =~/FAILED/){$search_status = "FAILED"; last;}
          elsif($search_summary =~/NOT_FAILED/){$search_status = "NOT_FAILED"; last;}
	  elsif($search_summary =~/OR_SUCCESS/){$or_success = 1;}
          
        }
    }
    

=cut

1;
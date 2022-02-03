package SeedViewer::WebPage::FigFamViewer;

use strict;
use warnings;

use base qw( WebPage );

use Data::Dumper;
use FIG;
use FF;
use FFs;
use HTML;
use FigKernelPackages::Observation qw(get_objects);
use FIG_Config;
use Tracer;
use FIGRules;

1;

sub output {	
    my ($self) = @_;

    $self->application->no_bot(1);
    my ($content, @ff_list);
    my $application = $self->application();
    my $cgi = $application->cgi;
    my $fig = $self->application->data_handle('FIG');
    my $figfam_data = FIG::get_figfams_data();
    my $html = new HTML;

    my $username;
    if (defined $self->application->session->user()){
	$username = $self->application->session->user->login();
    }

    # create menu
    $self->application->menu->add_category('&raquo;FIGfam');
    $self->application->menu->add_entry('&raquo;FIGfam', 'Home', '?page=FigFamViewer');
    $self->application->menu->add_entry('&raquo;FIGfam', 'Download', 'ftp://ftp.theseed.org/FIGfams');
    $self->application->menu->add_entry('&raquo;FIGfam', 'Debug Version', '?page=FigFamDebug') if ((defined $username) && ($username eq 'arodri'));

    if ($cgi->param('Fasta')){
	&download_all_fasta($self);
    }
    elsif ($cgi->param('Selected Fasta') ){
	&download_fasta($self);
    }

    my ($ff);
    if (defined($cgi->param('figfam')) && ($cgi->param('figfam') =~ /^FIG\d{6,9}$/)){
	$ff = $cgi->param('figfam');
    }

    if ( defined($ff)) {
	$self->title('FIGfam ' .$ff);
	push (@ff_list, $ff);
	my $figfams = new FFs($figfam_data, $fig);

	foreach my $fam (@ff_list)
	{
	    my $figfam_obj = $figfams->figfam($fam);
	    my @ff_ids = $figfam_obj->list_members();
	    my @all_subsystems;
	    my %ff_ss = $fig->subsystems_for_pegs(\@ff_ids);
	    foreach my $ref (values %ff_ss){
		foreach my $array (@$ref){
		    push (@all_subsystems, @$array[0]);
		}
	    }

	    # create a table with the figfam's information
	    my $ff_table = qq(<div style=" width:120px;">);
	    $ff_table = "<table class='info'>";
	    $ff_table .=  $self->start_form('main_form');
	    $ff_table .= "<tr><th class='info'>FIGfam ID</th><td class='info'>$fam</td></tr>";
	    $ff_table .= "<tr><th class='info'>Functional Role</th><td class='info'><b>" . $figfam_obj->family_function . "</b></td></tr>";
	    my %saw;
	    my @unique_all_subsystems = grep(!$saw{$_}++, @all_subsystems);
	    $ff_table .= "<tr><th class='info'>Subsystems</th><td class='info'>";
	    $ff_table .= "<table>";
	    foreach my $ss (@unique_all_subsystems){
		$ff_table .= "<tr><td><a href='?page=Subsystems&subsystem=" . $ss . "' target='_new'>$ss</a></td></tr>";
	    }
	    $ff_table .= "</table>";
	    $ff_table .= "</td></tr>";
	    $ff_table .= "<tr><th class='info'>FIGfam Size</th><td class='info'>" . scalar (@ff_ids) . "</td></tr>";
	    $ff_table .= "<tr><th class='info'>Average Sequence Length</th><td class='info'>" . &avgLength(\@ff_ids,$fig) . "</td></tr>";
	    my $ids = join("_", @ff_ids);
	    $ff_table .= "<tr><th class='info'>Member list";

	    $ff_table .= "<table align='right' valign='bottom'><tr><td>";
	    $ff_table .= $cgi->hidden(-name => 'ids', -id => 'ids', -value => $ids);
	    $ff_table .= "<div id='seq_dwnld'>";

	    $ff_table .= qq(<input type="submit" class="btn" name="Fasta" value="Fasta" onmouseover="hov(this,'btn btnhov')" onmouseout="hov(this,'btn')">);

	    $ff_table .= "</div></td></tr></table>"; # close of the div and the table for download fasta section

	    $ff_table .= "</th><td class='info'>";

#	    for (my $i=0;$i<@ff_ids;$i++){
#		if ($i < 10){
#		    if ($i%5 == 0){
#			$ff_table .= "<br>";
#		    }
#		    $ff_table .= "<a href='?page=Annotation&feature=" . $ff_ids[$i] ."' target='_newfid'>$ff_ids[$i]</a>&nbsp;&nbsp;";
#		}
#		else{
#		    $ff_table .= qq~<input type='button' class='btn' id='button_more' value='View All' onmouseover="hov(this,'btn btnhov')" onmouseout="hov(this,'btn')" onclick='if(document.getElementById(\"more_seqs\").style.display==\"none\") { document.getElementById(\"more_seqs\").style.display=\"inline\"; document.getElementById(\"button_more\").value=\"View Less\";} else { document.getElementById(\"more_seqs\").style.display=\"none\";document.getElementById(\"button_more\").value=\"View All\"; }'>~;
#		    $ff_table .= "<div id='more_seqs'style=' display: none;'>";
#		    for (my $j=$i;$j<@ff_ids;$j++){
#			if ($j%5 == 0) {
#			    $ff_table .= "<br>";
#			}
#			$ff_table .= "<a href='?page=Annotation&feature=" . $ff_ids[$j] ."' target='_newfid'>$ff_ids[$j]</a>&nbsp;&nbsp;";
#		    }
#		    $ff_table .= "</div>";
#		    last;
#		}
#	    }

	    # add the detail table here
	    $self->application->register_component('Table', 'SimTable');
	    my $simtable_component = $self->application->component('SimTable');

	    my $columns_metadata = $self->get_columns_list;
	    $self->application->register_component('DisplayListSelect', 'LB');
	    my $listbox_component = $self->application->component('LB');
	    $listbox_component->metadata($columns_metadata);
	    $listbox_component->linked_component($simtable_component);
	    $listbox_component->primary_ids(\@ff_ids);
	    $listbox_component->ajax_function('addColumn');
	    my $listbox_output .= $listbox_component->output();

	    $simtable_component->columns($listbox_component->initial_columns());  
	    $simtable_component->show_select_items_per_page(1);
	    $simtable_component->show_export_button(1);
	    $simtable_component->show_top_browse(1);
	    $simtable_component->show_bottom_browse(1);
	    $simtable_component->items_per_page(10);
	    $simtable_component->width(500);
	    $simtable_component->enable_upload(1);
	    my $table_data = Observation::Sims->display_figfam_table(\@ff_ids, $listbox_component->initial_columns(), $fig, $application,$cgi);

	    $simtable_component->data($table_data);
	    $ff_table .= $simtable_component->output();

	    $ff_table .= "</td></tr>";
	    $ff_table .= "<tr><th class='info'>Structure</th><td class='info'>";
	    my $pdb_sims = $figfams->PDB_connections($fam);
#	    $ff_table .= join (": <BR>", @$pdb_sims);
#	    print STDERR "PDB stuff: " . Dumper($pdb_sims);
	    my $pdb_links = ['PDB', 'SCOP', 'CATH', 'FSSP', 'MMDB', 'PDBsum'];
	    $ff_table .= "<table>";
	    foreach my $sim (@$pdb_sims){
		$ff_table .= "<tr>";
		$ff_table .= "<td>" . $sim . ":</td>";
		foreach my $link (@$pdb_links){
		    $ff_table .= "<td valign='middle'><a href='" . $html->alias_url($sim,$link) . "' target='new'>$link</a></td>";
		}
		$ff_table .= "<td><a href='http://www.ebi.ac.uk/thornton-srv/databases/pdbsum/" . lc ($sim) . "/traces.jpg' target='new'><img width='20' height='20' src='http://www.ebi.ac.uk/thornton-srv/databases/pdbsum/" . lc ($sim) . "/traces.jpg'></a>";
		$ff_table .= "</tr>";
	    }
	    $ff_table .= "</table>";

	    unless ($application->bot()) {
	      $ff_table .= "<tr><th class='info'>Gene Context &<br> FIGfam Taxonomy Distribution";
	      my $tree_context_help = $self->application->component('tree_context_help');
	      #$tree_context_help->wiki('http://biofiler.mcs.anl.gov/wiki/index.php/');
	      $tree_context_help->hover_width(300);
	      $tree_context_help->page('FIGfam Viewer');
	      $tree_context_help->title('FIGfam Taxonomy Tree');
	      $tree_context_help->text('Click on a checkbox to view the compared regions for the selected taxonomy or download the fasta sequences for the selected taxonomy. The numbers in brackets indicate the quantity of sequences in the taxonomy lineage included in the FIGfam.');
	      $ff_table .=  $tree_context_help->output();
	      $ff_table .= qq(<br>);
	      
	      # for taxonomy summary of the similarities
	      my $families = Observation->get_sims_summary(\@ff_ids,$fig);
	      
	      my $tree_search_help = $self->application->component('tree_search_help');
	      $tree_search_help->hover_width(300);
	      $tree_search_help->page('FIGfam Viewer');
	      $tree_search_help->title('FIGfam Taxonomy Tree Search');
	      $tree_search_help->text('You can search for a specific FIG sequence id in the distribution tree by typing the id and clicking on the "search in tree" button.');

	      $ff_table .= qq~<table><tr><td colspan=2 align='center'><input type='text' name='search_string' id='search_string'><input type='button' class='btn' value='Search in tree' onmouseover="hov(this,'btn btnhov')" onmouseout="hov(this,'btn')" onClick="search_in_tree()">~ . $tree_search_help->output() . qq~</td></tr></table><br><br>~;
	      
	      $ff_table .= qq(<table>);
	      
	      # insert a refresh compare regions button
	      $ff_table .= qq(<tr><td align='center'><input type='hidden' name='selected_taxes' id='selected_taxes' value=''><input type='button' class='btn' value='Refresh Context' onmouseover="hov(this,'btn btnhov')" onmouseout="hov(this,'btn')" onClick='execute_ajax(\"refresh_cr\", \"cr\", \"main_form\");'></td><td align='center'>);

	      $ff_table .= qq(<input type="submit" class='btn' value="Get selected fasta" name="Selected Fasta" onmouseover="hov(this,'btn btnhov')" onmouseout="hov(this,'btn')"></td></tr>);


	      my $level = 0;
	      my $tree = $self->application->component('Taxtree');
	      my $lvl1 = ['Root'];
	      my %node;
	      my $node_id =0;
	      foreach my $l1 (@$lvl1) {
		my $label = qq($l1);
		$node{$level} = $tree->add_node( { 'label' => $label, 'expanded' => 1 } );
		($tree,$node_id) = &print_children($fig, $families, $l1, $tree, \%node, $level+1,undef,$node_id, 0);
	      }
	      $ff_table .= qq(<tr><td colspan=2>) . $tree->output() . qq(</td></tr>);
	      $ff_table .= qq(<tr><td align='center'><input type='hidden' name='selected_taxes' id='selected_taxes' value=''><input type='button' class='btn' value='Refresh Context' onmouseover="hov(this,'btn btnhov')" onmouseout="hov(this,'btn')" onClick='execute_ajax(\"refresh_cr\", \"cr\", \"main_form\");'></td><td align='center'>);
	      $ff_table .= $self->button("Selected Fasta", name => "Selected Fasta",
                                         onmouseover => "hov(this,'btn btnhov')",
                                         onmouseout => "hov(this,'btn')") . "</td></tr></table>";
	      
	      $ff_table .= "</th>";
	      $ff_table .= $self->end_form();
	      $ff_table .= $self->application->component('ComparedRegionsAjax')->output();
	      
	      my ($feature_line,$count);
	      # get the list of fig ids to send to the compare region
	      if (@ff_ids <= 10){
		foreach my $id(@ff_ids){
		  $feature_line .= "feature=".$id."&";
		}
	      }
	      else{
		  # go through the %families var to select the right taxonomy group
		  foreach my $tax ( sort {$families->{level}->{$a} <=> $families->{level}->{$b}} keys %{$families->{level}}){
		      if (($families->{count}->{$tax} <= 10) && ($families->{count}->{$tax} >= 4)){
			  foreach my $id (@{$families->{figs}->{$tax}}){
			      $feature_line .= "feature=".$id."&";
			  }
			  last;
		      }
		  }
	      }
	      
	      $ff_table .= "<td class='info'><div style='width: 800px; text-align: justify;'>The graphic below depicts the <b>chromosomal neighborhood</b> of the selected feature (first line of the graphic) and those of similar features in other genomes (all following lines). Same <b>color</b> indicates a <b>set of similar proteins</b>, the <b>selected feature</b> and the ones similar to it in the other genomes will always appear <b>red</b> and in the middle of the line.</div><div id='cr'><img src=\"$FIG_Config::cgi_url/Html/clear.gif\" onload='execute_ajax(\"compared_region\", \"cr\", \"$feature_line\");'></div></td></tr>";
	    }

	    $ff_table .= "</table>";
	    $ff_table .= "</div>";
	    $content .= $ff_table;
	}
    }
    elsif ((defined($cgi->param('figfam'))) && (length($cgi->param('figfam')) > 0)){
	$self->title('FIGfams Search Results');
	my $query = ($cgi->param('figfam'));
	$content .= "<h2>FIGfam Search Results</h2>";
	$content .= "<table><tr><th class='info'>Query</th><td>$query</td></tr></table><br>";

	my $ffs = new FFs($figfam_data, $fig);
	my @searchResults;
	if ($query =~ /^fig\|\d+\.\d+\.peg\.\d+/){
	    my ($fam) = $ffs->families_containing_peg($query);
	    print STDERR "$query gets $fam\n";
	    if ($fam){
		# get the figfam function
		my $ff_obj = $ffs->figfam($fam);
		my $ff_function = $ff_obj->family_function;
		push (@searchResults, $ff_function . "-" . $fam);
	    }
	}
	else{
	    #
	    # CHECK
	    #
	    #my %ff_funcs = map { $_ =~ /^(\S+)\t(\S.*\S)/; $1 => ($2) . "-$1" } `cat "$figfam_data/family.functions"`;
	    #$query =~ s/([\|\\\.\,\+\*\$\^\(\)\[\]])/\\$1/g;
	    #@searchResults = grep (/$query/ig, values %ff_funcs);
	}

	if (@searchResults > 0){
	    my $table_component = $self->application->component('SearchResult');
	    $table_component->columns ([ { 'name' => 'FIGfam ID', 'filter' => 1 },
					 { 'name' => 'Function', 'filter' => 1},
					 { 'name' => 'Sequence Quantity', 'filter' => 2}
					 ]);

	    $table_component->show_export_button(1);
	    $table_component->show_top_browse(1);
	    $table_component->show_bottom_browse(1);
	    $table_component->items_per_page(20);
	    $table_component->show_select_items_per_page(1);
	    $table_component->width(900);

	    my $data = [];
	    foreach my $result (@searchResults){
		my $row = [];
		my ($func, $ff) = ($result) =~ /(.*)-(FIG.*)/;
		my $figfam_obj = $ffs->figfam($ff);
		next unless ref($figfam_obj);
		my $qty_ref = $figfam_obj->pegs_of();
		my $qty = @$qty_ref;

		push (@$row, "<a href='?page=FigFamViewer&figfam=$ff'>$ff</a>");
		push (@$row, $func);
		push (@$row, $qty);
		#push (@$row, 1);
		push (@$data,$row);
	    }
	    $table_component->data($data);
	    $content .= $table_component->output();
	} else {
	  $content .= "<p>no results found.</p>";
	}
	$content .= "<br><a href='?page=FigFamViewer'>back to search</a>";
    }
    elsif (defined($cgi->param('fasta_seq'))){
	
	my $figfams = new FFs($figfam_data, $fig);
	my $seq .= $cgi->param('fasta_seq');
	# Convert this thing into an orthodox FASTA aa sequence.
	my ($title, $pseq) = FIGRules::ParseFasta($seq);
	# Convert the sequence to all uppercase.
	$pseq = uc $pseq;
	#$pseq ~= s/\r//ig;
	my ($got,undef) = $figfams->place_in_family($pseq);
	#print STDERR "NO ERROR 2";

	my ($fam_id, $fam_func, $peg_func);
	$content .= "<table><tr><th class='info'>Query Sequence</th><td><pre>$seq</pre></td></tr>";

	if ($got){
	    $fam_id = $got->family_id;
	    $content .= "<tr><th class='info'>Hit Family</th><td><a href='?page=FigFamViewer&figfam=$fam_id'>$fam_id</a></td></tr>";
	    $fam_func = $got->family_function;
	    $content .= "<tr><th class='info'>Hit Family Function</th><td>$fam_func</td></tr>";
	}
	else {
	    $content .= "<tr><th>Hit Family</th><td>No hits found for this sequence</td></tr>";
	}

	$content .= "</table><br>";
	$content .= "<br><a href='?page=FigFamViewer'>back to search</a>";
	
    }
    else{
	$self->title('FIGfams Home');
	if ($cgi->param('figfam')){
	    $self->application->add_message('warning', 'Invalid FIGfam id');
	}

	$content .= "<h1>FIGfams</h1>";
	my $figfamText;
	$figfamText .= "<p>FIGfams are sets of protein sequences that are similar along the full length of the proteins. Proteins are thought of as implementing one or more abstract functional roles, and all of the members of a single FIGfam are believed to implement precisely the same set of functional roles. For version <a href='?page=FigFamViewer&figfam=history' >history and statistics</a> click on the link.</p>";
	$figfamText .= "<p>The FIGfams are based on the subsystems view, in which the cell is composed of a set of functional subsystems, and each active variant of a subsystem is thought of as a set of functional roles. Proteins implement one or more functional roles. The shallow hierarchy imposed by subsystems is induced by grouping sets of functional roles.</p>";
	$figfamText .= "<p>The FIGfam effort may be thought of as constructing the infrastructure needed to automatically project the manual annotations maintained within the subsystem collection. The construction of FIGfams is based on forming protein-sets in cases in which it can reliably be asserted that sequences implement identical functions. Currently, there are three cases in which we place different sequences into the same protein-set: families constructed from subsystems, families constructed from closely related genomes, and families constructed by comparison of chromosomal context. The actual FIGfams are constructed by inferring which pairs of genes must be placed in the same FIGfam using a set of rules, then forming the set of FIGfams as the maximum set of protein-sets consistent with the pairwise constraints. A post-processing step checks for the rare case in which a resulting FIGfam contains two protein sequences, each of them contained in subsystems, having differing functions. Such a case is evidence of an error in the curation of the relevant subsystems and is corrected manually.</p>";
	$figfamText .= "<p>The following graphic depicts the gene context of a case in which protein sequences from closely-related <i>Bacillus anthracis</i> genomes belong to the same FIGfams because they share similar gene context and share the same subsystems.</p>";
	$figfamText .= "<img height='400' width='800' src=\"$FIG_Config::cgi_url/Html/FIGfams-closeGenomes.png\" alt='Closely-related genomes' />";
	
	$content .= "<table cellpadding=20><tr><td width=75% align=justify rowspan=2>$figfamText</td><td align=center height=100><img height='95px' src=\"$FIG_Config::cgi_url/Html/FIGfams-logo.png\" alt='FIGfams' /></td></tr><tr><td valign=top>";
	$content .= "<h4>Enter FIGfam, Keyword or a sequence FIG id</h4>";
	$content .= $self->start_form();
	$content .= "<input type='text' name='figfam' id='figfam' onclick='document.getElementById(\"fasta_seq\").value=null;'><br />";
#	$content .= "<input type='text' name='figfam' id='figfam' onclick='clearText(\"fasta_seq\");'><br />";
	$content .= "<h4>Or scan a fasta sequence<br>against the FIGfams</h4>";
	$content .= $cgi->textarea(-name => "fasta_seq", 
				   -id => "fasta_seq", 
				   -value => "Enter sequence in fasta format",
				   -rows => 8, -cols => 30,
				   -onclick => "clearText('fasta_seq');clearText('figfam');");
	$content .= "<br>" . $self->button('Search') . "<br />";
	$content .= $self->end_form;
	$content .= "</td></tr></table>";
    }
    
    $content .= "<br><br><br><br><br><br>";
    return $content;
}

sub init {
    my ($self) = @_;
    $self->application->register_component('Table', 'SearchResult');
    $self->application->register_component('GenomeDrawer', 'DomainDrawer');
    $self->application->register_component('RegionDisplay','ComparedRegions');
    $self->application->register_component('Ajax', 'ComparedRegionsAjax');
    $self->application->register_component('HelpLink', 'tree_context_help');
    $self->application->register_component('HelpLink', 'tree_search_help');
    $self->application->register_component('Tree', 'Taxtree');
}


sub require_javascript{
    return ["$FIG_Config::cgi_url/Html/checkboxes.js"];
}

sub download_all_fasta{
    my ($self) = @_;
    my $content;

    my $application = $self->application;
    my $cgi = $application->cgi;
    Trace("Processing sequence download.") if T(3);
    #return "<pre>".Dumper($cgi)."</pre>";

    my @ids = split(/_/, $cgi->param('ids'));

    # need to create two temp files (1. file to store the fig ids, 2. file to store the fasta sequences output)
    my $temp_file = mktemp("/tmp/idsXXXXX");
    my $temp_file_ids = $temp_file . ".ids";
    my $temp_file_seq = $temp_file . ".faa";
    
    # make the fig id file
    open (FH, ">$temp_file_ids");
    foreach my $id (@ids){
	print FH "$id\n";
    }
    close FH;
    
    system("$FIG_Config::bin/get_translations < $temp_file_ids > $temp_file_seq");
    open (FH, $temp_file_seq);
    my @fasta = <FH>;
    close FH;
    my $fasta_line = join ("",@fasta);

    # download the file
    print "Content-Type:application/x-download\n";
    print "Content-Length: " . length($fasta_line) . "\n";
    print "Content-Disposition:attachment;filename=fasta_download.faa\n\n";
    print $fasta_line;

    die 'cgi_exit';
}

sub download_fasta{
    my ($self) = @_;
    my $content;

    use File::Temp qw/ :mktemp /;

    my $application = $self->application;
    my $cgi = $application->cgi;
    Trace("Processing sequence download.") if T(3);
    #return "<pre>".Dumper($cgi)."</pre>";

    my @chunks = split(/_feature=/, $cgi->param('selected_taxes'));
    my (@ids);
    foreach my $chunk (@chunks){
	my ($id) = ($chunk) =~ /(fig.*)/;
	push (@ids, $id) if ($id =~ /^fig/);
    }

    # need to create two temp files (1. file to store the fig ids, 2. file to store the fasta sequences output)
    my $temp_file = mktemp("/tmp/idsXXXXX");
    my $temp_file_ids = $temp_file . ".ids";
    my $temp_file_seq = $temp_file . ".faa";
    
    # make the fig id file
    open (FH, ">$temp_file_ids");
    foreach my $id (@ids){
	print FH "$id\n";
    }
    close FH;
    
    system("$FIG_Config::bin/get_translations < $temp_file_ids > $temp_file_seq");
    open (FH, $temp_file_seq);
    my @fasta = <FH>;
    close FH;
    my $fasta_line = join ("",@fasta);

    # download the file
    print "Content-Type:application/x-download\n";
    print "Content-Length: " . length($fasta_line) . "\n";
    print "Content-Disposition:attachment;filename=fasta_download.faa\n\n";
    print $fasta_line;

    die 'cgi_exit';
}


sub commify {
    local($_) = shift;
    1 while s/^(-?\d+)(\d{3})/$1,$2/;
    return $_;
}

sub refresh_cr{
    my ($self) = @_;
    
    my $application = $self->application;
    my $cgi = $application->cgi;
    Trace("Processing refresh compared region.") if T(3);
    #return "<pre>".Dumper($cgi)."</pre>";

    my $feature_line = $cgi->param('selected_taxes');
    $feature_line =~ s/_/\&/ig;

    my $content = "<img src=\"$FIG_Config::cgi_url/Html/clear.gif\" onload='execute_ajax(\"compared_region\", \"cr\", \"$feature_line\");'>";
    return $content;
}

sub compared_region {
    my ($self) = @_;
    
    my $application = $self->application;
    my $cgi = $application->cgi;
    Trace("Processing compared region.") if T(3);
    #use Data::Dumper;
    #return "<pre>".Dumper($cgi)."</pre>";
    
    unless (defined($cgi->param('feature'))) {
	$application->add_message('warning', 'Feature page called without an identifier');
	return "";
    }
    my $fig = $application->data_handle('FIG');
    
    # check if we have a valid fig
    unless ($fig) {
	$application->add_message('warning', 'Invalid organism id');
	return "";
    }
    
    my $cr = $self->application->component('ComparedRegions');
    $cr->fig($fig);
    
    return $cr->output();
}


=head3
sub domain_display{
    my ($fids,$fig) = @_;

#    my $domain_gd = $self->application->component('DomainDrawer');
#    $domain_gd->width(800);
#    $domain_gd->legend_width(100);
#    my $window_size = 12000;
#    $domain_gd->window_size($window_size);
    my @attributes = $fig->get_attributes($fids);

    my (%code_attributes, %attribute_locations, %attribute_score);
    my $dbmaster = DBMaster->new(-database =>'Ontology');

    my @codes = grep { $_->[1] =~ /^IPR/i } @attributes;
    foreach my $key (@codes){
	my $name = $key->[1];
	if ($name =~ /_/){
	    ($name) = ($key->[1]) =~ /(.*?)_/;
	}
	push (@{$code_attributes{$key->[0]}}, $name);
	push (@{$attribute_location{$key->[0]}{$name}}, $key->[2]);
	push (@{$attribute_score{$key->[0]}{$name}}, $key->[1]);
    }
    
    my %column;
    foreach my $peg (@$fids){
	my @ncodes = @{$code_attributes{$peg}} if (defined @{$code_attributes{$peg}});
	@ipr_codes = ();
	# get only unique values
	my %saw;
	foreach my $key (@ncodes) {$saw{$key}=1;}
	@ncodes = keys %saw;

	foreach my $code (@ncodes) {
	    my @parts = split("::",$code);
	    my $ipr_link = "<a href=http://www.sanger.ac.uk//cgi-bin/Pfam/getacc?" . $parts[1] . ">$parts[1]</a>";

##	    # get the data for the domain with top score
#	    foreach my $key (sort {$attribute_score{$peg}{$b}<=>$attribute_score{$peg}{$a}} keys %{$attribute_score{$peg}{$code}}){
#		print STDERR "$peg: $key";
#		last;
#	    }
	    # get the locations for the domain
	    my @locs;
	    foreach my $part (@{$attribute_location{$peg}{$code}}){
		my ($loc) = ($part) =~ /\;(.*)/;
		push (@locs,$loc);
	    }
	    my %locsaw;
	    foreach my $key (@locs) {$locsaw{$key}=1;}
	    @locs = keys %locsaw;

	    my $locations = join (", ", @locs);
	    
#	    if (defined ($description_codes{$parts[1]})){
		push(@ipr_codes, "$parts[1] ($locations)");
#	    }
#	    else {
#		my $description = $dbmaster->pfam->get_objects( { 'id' => $parts[1] } );
#		$description_codes{$parts[1]} = ${$$description[0]}{term};
#	    push(@ipr_codes, "$ipr_link ($locations)");
#	}
	}
	$column{$peg}=join("<br><br>", @ipr_codes);
    }
    return (%column);
}
=cut

sub avgLength {
    my ($fids, $fig) = @_;
    my $sum=0;
    my $max=0;
    my $min=1e100000;
    my ($min_id,$max_id);
    my $count=0;
    my @lengths;
    
    foreach my $fid (@$fids){
	my $length = $fig->translation_length($fid);
        if (defined $length) { # Will be undefined if FID is not a protein.
            push (@lengths,$length);
            $sum+= $length;
            if ($length < $min){
                $min_id=$fid;
                $min=$length;
            }
            if ($length>$max){
                $max_id=$fid;
                $max=$length;
            }
            $count++;
        }
    }
    my $avg = 0;
    my $std_dev = 0;
    if ($count != 0)
    {
	$avg = int($sum/$count);
	$std_dev = int(&std_dev($avg,\@lengths));
    }
    return ("$avg aa\t[Maximum length: $max_id ($max aa), Minimum length: $min_id ($min aa), Standard Deviation: $std_dev aa]");
}

sub std_dev {
    my ($mean, $lengths)=@_;
    my @elem_squared;
    foreach my $len(@$lengths) {
	next if (!$len);
	push (@elem_squared, ($len **2));
    }
    return sqrt( &mean(@elem_squared) - ($mean ** 2));
}

sub mean {
    my $result;
    foreach (@_) { $result += $_ }
    return $result / @_;
}

sub  print_children {
    my ($fig, $families, $tax, $tree, $node_ref, $level, $genome, $node_id) = @_;
    my %node = %$node_ref;
    if ($tax eq "Root"){
	$families->{"lineage"}->{"Root"} = "Root";
	$families->{color}->{"Root"} = "black";
    }

    my $taxtag = $tax;
#    if ($level > 3){
#	$taxtag = $fig->abbrev($tax);
#    }

    my $expanded = 0;
    $expanded = 1 if ($level <= 2);
    if (@{$$families{children}{$tax}}){
	my $lineage = $families->{"lineage"}->{$tax};
	my $features = "feature=" . join ("&feature=", @{$families->{figs}->{$tax}});
	my $hidden_field_value = $node_id;
	my $label = qq~<input type='hidden' name='tree_node_~ . $lineage . qq~' id='tree_node_~ . $lineage . qq~' value=$hidden_field_value><input type='checkbox' name='lineageBoxes' id='$lineage' value='$lineage' onClick="ClickLineageBoxes('$tax','$lineage');"><font color=$$families{color}{$tax}>$taxtag</font> [$$families{count}{$tax}]~;

	$node{$level} = $node{$level-1}->add_child( {'label' => $label, 'expanded' => $expanded } ) if ($tax !~ /Root/);
	$level = 0 if ($tax =~ /Root/);
	foreach my $child (@{$$families{children}{$tax}}){
	  $node_id++;
	    ($tree, $node_id) = &print_children($fig, $families, $child, $tree, \%node, $level+1,undef,$node_id);
	}
    }
    else{
	my $lineage = $families->{"lineage"}->{$tax};
	
	my $features = "feature=";
	my $id;
	if (ref($families->{figs}->{$tax}))
	{
	    $features .= join ("&feature=", @{$families->{figs}->{$tax}});
	    #my $id = $families->{figs}->{$tax}->[0];
	    $id = join ("_feature=", @{$families->{figs}->{$tax}});
	}
	my $hidden_field_value = $node_id;
	my $label = qq~<input type='hidden' name='tree_node_~ . $lineage . qq~' id='tree_node_~ . $lineage . qq~' value=$hidden_field_value><input type='checkbox' name='lineageBoxes' id='$lineage' value='$id' onClick="ClickLineageBoxes('$tax','$lineage');"><font color=$$families{color}{$tax}>$taxtag</font>~;

	$node{$level-1}->add_child( {'label' => $label } );
    }
    return ($tree,$node_id);
}

sub get_columns_list{
    my ($self) = @_;
    my $columns_metadata={};

#    my $help_objects = &get_help_objects($self);

#    $columns_metadata->{box}->{value} = 'Select';
#    $columns_metadata->{box}->{header} = 'Select' . $help_objects->{organism_color_help_component}->output() . qq(<br><input type='button' class='btn' value='All' onmouseover="hov(this,'btn btnhov')" onmouseout="hov(this,'btn')" onclick="checkUncheckAll('sims_form','click_check')" id='click_check'><br><input type='button' class='btn' value='check to last checked' onmouseover="hov(this,'btn btnhov')" onmouseout="hov(this,'btn')" onclick="check_up_to_last_checked('sims_form')" id='last_checked' name='last_checked'>);
#    $columns_metadata->{box}->{order} = 1;
#    $columns_metadata->{box}->{visible} = 1;
#    $columns_metadata->{box}->{group} = "permanent";

    $columns_metadata->{fig_sequence}->{value} = 'PEG ID';
    $columns_metadata->{fig_sequence}->{header} = {'name' => 'PEG ID', sortable => 1, 'filter' => 1};
#    $columns_metadata->{fig_sequence}->{header} = 'PEG ID';
    $columns_metadata->{fig_sequence}->{order} = 1;
    $columns_metadata->{fig_sequence}->{visible} = 1;
    $columns_metadata->{fig_sequence}->{group} = "permanent";

    $columns_metadata->{length}->{value} = 'Length';
    $columns_metadata->{length}->{header} = {'name' => 'Length', sortable => 1, 'filter' => 1};
#    $columns_metadata->{length}->{header} = 'Length';
    $columns_metadata->{length}->{order} = 2;
    $columns_metadata->{length}->{visible} = 1;
    $columns_metadata->{length}->{group} = "permanent";

    $columns_metadata->{organism}->{value} = 'Organism';
    $columns_metadata->{organism}->{header} = {name => 'Organism', sortable => 1, 'filter' => 1};
#    $columns_metadata->{organism}->{header} = 'Organism';
    $columns_metadata->{organism}->{order} = 3;
    $columns_metadata->{organism}->{visible} = 1;
    $columns_metadata->{organism}->{group} = "permanent";

    $columns_metadata->{subsystem}->{value} = 'Associated Subsystem';
    $columns_metadata->{subsystem}->{header} = {'name' => 'Associated Subsystem', sortable => 1, 'filter' => 1};
    $columns_metadata->{subsystem}->{order} = 4;
    $columns_metadata->{subsystem}->{visible} = 1;
    $columns_metadata->{subsystem}->{group} = "permanent";

    $columns_metadata->{function}->{value} = 'Function';
    $columns_metadata->{function}->{header} = {'name' => 'Function', sortable => 1, 'filter' => 1};
    $columns_metadata->{function}->{order} = 5;
    $columns_metadata->{function}->{visible} = 1;
    $columns_metadata->{function}->{group} = "permanent";
    
    return $columns_metadata;
}

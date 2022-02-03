package SeedViewer::WebPage::ModelView;

use base qw( WebPage );

1;

use strict;
use warnings;
use Tracer;
use URI::Escape;

use FIG_Config;

use WebConfig;
use WebComponent::WebGD;
use WebColors;
use WebLayout;
use Data::Dumper;
=pod

=head1 NAME

Kegg - an instance of WebPage which maps organism data onto a KEGG map

=head1 DESCRIPTION

Map organism data onto a KEGG map

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
    my ($self) = @_;

    $self->title('Model SEED');
	$self->application->register_component('RollerBlind', 'biomassBlind');
	$self->application->register_component('RollerBlind', 'tutorialBlind');
	$self->application->register_component('RollerBlind', 'fbablind');
	
    $self->application->register_component('Ajax', 'headerajax');

    $self->application->register_component('TabView', 'overview');
    $self->application->register_component('TabView', 'optionsbox');
    $self->application->register_component('TabView', 'model_select_and_mfba_controller');
    $self->application->register_component('TabView', 'contentbox');
    $self->application->register_component('TabView', 'tabletabs');

    $self->application->register_component('FilterSelect', 'compareselect' );

    $self->application->register_component('ReactionTable', 'rxnTbl');
    $self->application->register_component('GeneTable', 'geneTbl');
    $self->application->register_component('CompoundTable', 'cpdTbl');
    
    $self->application->register_component('ObjectTable','user_model_table');
    $self->application->register_component('ObjectTable','model_stats_table');
    $self->application->register_component('ObjectTable','biomass_table');
    $self->application->register_component('ObjectTable','selected_biomass');
    $self->application->register_component('ObjectTable','MediaTable');
   
    $self->application->register_component('MapBundle', 'testbundle' );
    $self->application->register_component('FilterSelect', 'modelfilterselect' );
    $self->application->register_component('FilterSelect', 'mgmodelfilterselect' );
    $self->application->register_component('FilterSelect', 'GenomeSelect');

    $self->application->register_component('MFBAController', 'mfba_controller'); 
    $self->application->component('rxnTbl')->base_table()->preferences_key("ModelView_rxnTbl");
    $self->application->component('cpdTbl')->base_table()->preferences_key("ModelView_cpdTbl");

    $self->application->register_component('CustomAlert', 'addAlert');
    $self->application->register_component('CustomAlert', 'removeAlert');
	
	$self->{_metagenome_page} = 0;
    return 1;
}

=item * B<output> ()

=cut

sub output {
    my ($self) = @_;
    my $cgi = $self->application()->cgi();
    my $figmodel = $self->application()->data_handle('FIGMODEL');
    # check if adding or removing reaction
    check_model_change($self);
	# Process parameters
    my $model_ids = $self->get_model_ids($figmodel->user());
    # Add an Ajax header
    my $ajax = $self->application()->component('headerajax');
	my $html .= $ajax->output();
	#Only setting the layout for Model SEED if not in metagenome mode
	if (!defined($self->{_metagenome_page}) || $self->{_metagenome_page} == 0) {
		my $layout = WebLayout->new(TMPL_PATH . '/ModelSEED.tmpl');
		$layout->add_css("$FIG_Config::cgi_url/Html/seedviewer.css");
		$layout->add_css("$FIG_Config::cgi_url/Html/commonviewer.css");
		$layout->add_css("$FIG_Config::cgi_url/Html/web_app_default.css");
		$self->application()->{layout}= $layout;
		my $menu = WebMenu->new();
		$menu->add_category('&raquo;SEED Resources', '?page=ModelView');
		$menu->add_entry('&raquo;SEED Resources', 'What is the SEED', 'http://www.theseed.org/wiki/index.php/Home_of_the_SEED');
		$menu->add_entry('&raquo;SEED Resources', 'Model SEED Home', '?page=ModelView');
		$menu->add_entry('&raquo;SEED Resources', 'SeedViewer Home', '?page=Home');
		$menu->add_entry('&raquo;SEED Resources', 'RAST Home', 'http://rast.nmpdr.org/rast.cgi');
		$menu->add_category('&raquo;Account management', 'http://www.theseed.org', 'Account management', undef, 98);
		$menu->add_entry('&raquo;Account management', 'Create new account', '?page=Register');
		$menu->add_entry('&raquo;Account management', 'I forgot my Password', '?page=RequestNewPassword');
		$self->application()->{menu}= $menu;
	}
	# Use a hidden form to pass parameters, add/remove models, etc.
    $html .= "<form method='get' id='select_models' action='seedviewer.cgi' enctype='multipart/form-data'>\n";
    if (defined($model_ids)) {
    	$html .= "  <input type='hidden' id='model' name='model' value='" . join(",",@{$model_ids}) . "'>\n";
    } else {
    	$html .= "  <input type='hidden' id='model' name='model' value=''>\n";
    }
    $html .= "  <input type='hidden' id='page' name='page' value='ModelView'>\n";
    $html .= "</form>\n";
	#Adding news header
	my $messages = $figmodel->database()->load_single_column_file($figmodel->config("server message file")->[0],"");
	if (defined($messages)) {
		$html .= "<table><tr><th style=\"color:red;\">Important Server Messages:</th></tr>";
		for (my $i=0; $i < @{$messages}; $i++) {
			$html .= "<tr><td style=\"color:red;\">".($i+1).".) ".$messages->[$i]."</td></tr>";
		}
		$html .= "</table><br>";
	}	
	
	my $tutorialArray = $figmodel->database()->load_single_column_file($figmodel->config("Tutorial HTML file")->[0],"");
	my $blind = $self->application()->component('tutorialBlind');
    $blind->add_blind({ 'title' => "<strong>Model SEED Tutorials (Click here to view)</strong>",
                        'content' => "<div style='padding:5px; padding-left:45px;'>".join("",@{$tutorialArray})."</div>",
                        'info' => ""
                      });
    $blind->width(1280);
    $html .= $blind->output()."<br>";
	
    # Build data tabs for the tables section   
    my $tabletabs = $self->application()->component('overview');
    my $modelCgi = '';
    if(defined($model_ids) && @$model_ids > 0){
       $modelCgi .= 'model=' . join(',', @$model_ids);
    }
    $tabletabs->add_tab( 'Selected models and run FBA', '', ['model_select',$modelCgi]);
    $tabletabs->add_tab( 'Model construction', '', ['reconstruction_page',""]);
    $tabletabs->add_tab( 'User models', '', ['user_models',""]);
    $tabletabs->add_tab( 'Model statistics/Select', '', ['model_stats',""]);
    $tabletabs->add_tab( 'Flux Balance Results', '', ['outputResultsTable', "", "MFBAController|mfba_controller"]);
    $tabletabs->add_tab( 'About Model SEED', '', ['aboutmodelseed', ""]);
    $tabletabs->width('100%');
    if( defined( $cgi->param('maintab') ) ){
        $tabletabs->default( $cgi->param('maintab') )
    }
	$html .= $tabletabs->output();

	#Placing KEGG map in vertical space
    #my $onload = "onload=\"javascript:execute_ajax(\'output\',\'MapDiv\',\'model=".$cgi->param('model')."&pathway=".$pnum."\',\'Loading...\',0,\'post_hook\',\'MapBundle|testbundle\');\"";
    #$html .= "<h3>Maps</h3><br>";
    #$html .= '<div style="height:1000;width40px;padding:10px;" id="MapDiv">'.'<img src="'.$FIG_Config::cgi_url.'/Html/clear.gif" '.$onload.'>test</div><br>';
    # Build data tabs for the tables section
    my $mapCGI = '';
    my $biomassCGI = '';
    if (defined($cgi->param('model'))) {
    	$biomassCGI .= "model=".$cgi->param('model');
    	$mapCGI = "model=".$cgi->param('model')."&pathway=00020";
    }
    if (defined($cgi->param('biomass'))) {
    	if (length($biomassCGI) > 0) {
    		$biomassCGI .= "&";
    	}
    	$biomassCGI .= "biomass=".$cgi->param('biomass');
    }
    $modelCgi = '';
    if(defined($model_ids) && @$model_ids > 0){
       $modelCgi .= 'model=' . join(',', @$model_ids);
    }
    if(defined($cgi->param('fluxIds'))) {
        $modelCgi .= "&fluxIds=".$cgi->param('fluxIds');
    }
    my $subtabs = $self->application()->component( 'tabletabs' );
    $subtabs->add_tab( 'Map</h3>', '', ['output', $mapCGI, 'MapBundle|testbundle']);
    $subtabs->add_tab( 'Reactions</h3>', '', ['output', $modelCgi, 'ReactionTable|rxnTbl']);
    $subtabs->add_tab( 'Compounds</h3>', '', ['output', $modelCgi, 'CompoundTable|cpdTbl']);
    $subtabs->add_tab( 'Biomass Components</h3>', '', ['biomass_table',$biomassCGI]);
    if(defined($model_ids) && @{$model_ids} > 0){
        $subtabs->add_tab( 'Genes', '', ['output', $modelCgi, 'GeneTable|geneTbl']);
    }
    $subtabs->add_tab( 'Media formulations</h3>', '', ['media_table',$modelCgi]);
    $subtabs->width('100%');
    if( defined( $cgi->param('tab') ) ){
        $subtabs->default( $cgi->param('tab') )
    }
    $html .= $subtabs->output();
	$html .= "<img src='http://bioseed.mcs.anl.gov/~chenry/FIG/CGI/Html/clear.gif'  onload='initializePage();'>";
    # get custom alerts for adding/removing reactions for models
    #$html .= add_alerts($self);

    return $html;
}

sub get_model_ids {
	my ($self) = @_;
	my $figmodel = $self->application()->data_handle('FIGMODEL');
    my $cgi = $self->application()->cgi();
    my $model_ids;
    if(defined($cgi->param('model'))) {
        my $NoAccessModels;
        my @models = split( /,/, $cgi->param('model') );
        foreach my $Model (@models) {
            my $model = $figmodel->get_model($Model);
            if (defined($model)) {
            	push(@{$model_ids},$Model);
            }
        }
    }
    return $model_ids;
}

sub get_biomass_ids {
	my ($self) = @_;
    my $cgi = $self->application()->cgi();
    my $figmodel = $self->application()->data_handle('FIGMODEL');
    my $biomass_ids;
    my $biomass_hash;
    my $model_ids = $self->get_model_ids();
    if (defined($model_ids)) {
    	 foreach my $Model (@$model_ids) {
    	 	my $model = $figmodel->get_model($Model);
    	 	my $temp = $model->biomassReaction();
    	 	if (defined($temp) && $temp =~ m/bio\d\d\d\d\d/) {
    	 		$biomass_hash->{$temp} = 1;
    	 		push(@{$biomass_ids},$Model."_".$temp);
    	 	}
    	 }
    }
    if(defined($cgi->param('biomass'))) {
        my @rxns = split(/,/,$cgi->param('biomass'));
        foreach my $id (@rxns) {
            if (!defined($biomass_hash->{$id})) {
            	$biomass_hash->{$id} = 1;
            	push(@{$biomass_ids},$id);
            }
        }
    }
    return $biomass_ids;
}

sub model_select {
	my ($self) = @_;
    my $cgi = $self->application()->cgi();
    my $figmodel = $self->application()->data_handle('FIGMODEL');
	# Process parameters
    my $html;
    my $model_ids = $self->get_model_ids();
    my $pnum = "00020";
    if( defined( $cgi->param('pathway') ) ){
        $pnum = $cgi->param('pathway');
    }
    my $modelCgi = '';
    if(defined($model_ids) and @$model_ids > 0) {
        $modelCgi .= 'model=' . join(',', @$model_ids);;
    }
    # Print the top of the ModelView page
    $html .= "<div style=\"padding:10px;\">";
	my $select_filter = model_select_box($self);
    if(defined($model_ids)) {
    	my ($title_string, $overview ) = $self->generate_model_overview($model_ids);
	    my $blind = $self->application()->component('fbablind');
	    my $fbacontrols = $self->application()->component('mfba_controller');
	    $blind->add_blind({ 'title' => "<strong>Click here to run FBA on selected models</strong>",
	                        'content' => "<div style='padding:5px;'>".$fbacontrols->outputFluxControls()."</div>",
	                        'info' => ""
	                      });
	    $blind->width(1280);
	    $html .= $select_filter.$overview.$blind->output()."<br>";
    } else {
    	my ($title_string, $overview) = $self->generate_db_overview();
	    $html .= "<div style=\"width:40%;\">You have arrived at the Biochemistry and Model database".
            " of the SEED framework for genome annotation. You can select a specific model for viewing".
            " using the model select box (below), or you can browse all the database compounds and reactions".
            " in the tables below, or download an Excel spreadsheet of the <a href='ModelSEEDdownload.cgi?biochemistry=1'>reactions</a> or <a href='ModelSEEDdownload.cgi?biochemCompounds=1'>compounds</a> in the database.</div><br/>";
		$html .= $select_filter;
    }
	$html .= "<div style=\"width:50px; float:left;\"></div>";
	
	$html .= "</div><div style=\"clear: both;\"></div>";
    return $html;
}

sub aboutmodelseed {
	my ($self) = @_;
    my $figmodel = $self->application()->data_handle('FIGMODEL');
    return $figmodel->web()->load_html_from_file("/vol/model-dev/MODEL_DEV_DB/ReactionDB/webconfig/AboutModelSEEDText.txt","This content is unavailable at the moment. Email the project developer for assistance: chenry\@mcs.anl.gov.");
}

sub model_stats {
	my ($self) = @_;
    my $cgi = $self->application()->cgi();
    my $figmodel = $self->application()->data_handle('FIGMODEL');
    #Getting table object
    my $table = $self->application()->component('model_stats_table');
    $table->set_type("model");
    my $objects = $table->get_objects();
    #my $objects = $table->get_objects({users => ["%|".$UserID."|%","like"]});
    #$objects = $table->get_objects({users => "all"});
    if (!defined($objects) || @{$objects} == 0) {
    	return "<p>No models in table</p>";
    }
    #Setting table columns
    my $columns = [
    	{ function => 'FIGMODELweb:create_model_id_link', call => 'FUNCTION:id', name => 'Name', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterName' ) || "" },
        { call => 'FUNCTION:name', name => 'Organism', filter => 1, sortable => 1, width => '200', operand => $cgi->param( 'filterOrganism' ) || "" },
        #{ function => 'FIGMODELweb:create_genome_link', call => 'FUNCTION:genome', name => 'Genome ID', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterGenomeID' ) || "" },
        { call => 'FUNCTION:cellwalltype', name => 'Class', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterClass' ) || "" },
		{ call => 'FUNCTION:associatedGenes', name => 'Genes', sortable => 1, width => '100', operand => $cgi->param( 'filterGenes' ) || "" },
        { call => 'FUNCTION:reactions', name => 'Reactions', sortable => 1, width => '100', operand => $cgi->param( 'filterReactions' ) || "" },
        #{ function => 'FIGMODELweb:call_model_function(gapfilling_reactions)', call => 'FUNCTION:id', name => 'Gapfilling Reactions', sortable => 1, width => '100', operand => $cgi->param( 'filterGapfilling' ) || "" },
        { call => 'FUNCTION:compounds', name => 'Compounds', sortable => 1, width => '100', operand => $cgi->param( 'filterCompounds' ) || "" },
        { function => 'FIGMODELweb:model_source', call => 'FUNCTION:source', name => 'Source', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterSource' ) || "" },
		{ function => 'FIGMODELweb:create_model_download_link', call => 'FUNCTION:id', name => 'Download links', sortable => 1, width => '100', operand => $cgi->param( 'filterSBML' ) || "" },
        { call => 'FUNCTION:version', name => 'Version', sortable => 1, width => '100', operand => $cgi->param( 'filterVersion' ) || "" },
        { function => 'FIGMODELweb:model_modification_time', call => 'FUNCTION:modificationDate', name => 'Last update', sortable => 1, width => '100', operand => $cgi->param( 'filterUpdate' ) || "" }		
	];
    $table->add_columns($columns);
    $table->set_table_parameters({
    	show_export_button => "1",
    	sort_column => "Name",
    	width => "100%",
    	show_bottom_browse => "1",
    	show_top_browse => "1",
    	items_per_page => "20",
    });
	return $table->output();
}

sub user_models {
    my ($self) = @_;	
    my $cgi = $self->application()->cgi();
    my $figmodel = $self->application()->data_handle('FIGMODEL');
    if (!defined($figmodel->userObj()) || $figmodel->userObj()->login() eq "public") {
    	return "<h2>User is not logged in</h2>";
    }
    my $html = "";
    if ($figmodel->user() ne "PUBLIC" && defined($cgi->param('recongenome'))) {
        #Getting genome ID submitted for reconstruction if a job has been submitted
        $html = "<h2>".$cgi->param('recongenome')." genome submitted for model construction.</h2>";
        my $oldout;
        open($oldout, ">&STDOUT");
	    my ($fh, $filename) = File::Temp::tempfile("XXXXXXX");
		close($fh);;
		open(STDOUT, '>', $filename);
		select STDOUT; $| = 1;
        my $mdl = $figmodel->get_model("Seed".$cgi->param('recongenome').".".$figmodel->userObj()->_id());
        if (!defined($mdl)) {
        	$mdl = $figmodel->create_model({
				genome => $cgi->param('recongenome'),
				owner => $figmodel->user(),
				reconstruction => 0,
				gapfilling => 0
			});
        }
		if (defined($mdl)) {
			$figmodel->database()->create_object("job",{
				USER => $figmodel->user(),
				QUEUETIME => ModelSEED::utilities::TIMESTAMP(),
				EXCLUSIVEKEY => "Reconstruction_".$figmodel->user()."_".$cgi->param('recongenome'),
				COMMAND => "mdlreconstruction?".$mdl->id()."?1",
				QUEUE => "6"
			});
		}
		open(STDOUT, ">&", $oldout);
		unlink($filename);
    }
    #Getting table object
    my $table = $self->application()->component('user_model_table');
    $table->set_type("model");
    my $objects = $table->get_objects({owner => $figmodel->user()});
    if (!defined($objects) || @{$objects} == 0) {
    	return "<h2>User owns no models at this time</h2>";
    }
	#Setting table columns
	my $columns = [
		{ function => 'FIGMODELweb:create_model_id_link', call => 'FUNCTION:id', name => 'Name', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterName' ) || "" },
		{ call => 'FUNCTION:name', name => 'Organism', filter => 1, sortable => 1, width => '200', operand => $cgi->param( 'filterOrganism' ) || "" },
		{ call => 'FUNCTION:associatedGenes', name => 'Genes', sortable => 1, width => '100', operand => $cgi->param( 'filterGenes' ) || "" },
        { call => 'FUNCTION:reactions', name => 'Reactions', sortable => 1, width => '100', operand => $cgi->param( 'filterReactions' ) || "" },
        { function => 'FIGMODELweb:model_source', call => 'FUNCTION:source', name => 'Source', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterSource' ) || "" },
		#{ function => 'FIGMODELweb:create_genome_link', call => 'FUNCTION:genome', name => 'Genome ID', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterGenomeID' ) || "" },
		{ call => 'FUNCTION:version', name => 'Version', sortable => 1, width => '100', operand => $cgi->param( 'filterVersion' ) || "" },
		{ call => 'FUNCTION:message', name => 'Status', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterClass' ) || "" },
		{ function => 'FIGMODELweb:model_modification_time', call => 'FUNCTION:modificationDate', name => 'Last update', sortable => 1, width => '100', operand => $cgi->param( 'filterUpdate' ) || "" },
		{ function => 'FIGMODELweb:create_model_download_link', call => 'FUNCTION:id', name => 'Download links', sortable => 1, width => '100', operand => $cgi->param( 'filterSBML' ) || "" }
	];
    $table->add_columns($columns);
    $table->set_table_parameters({
    	show_export_button => "1",
    	sort_column => "Last update",
    	sort_descending => "1",
    	width => "100%",
    	show_bottom_browse => "1",
    	show_top_browse => "1",
    	items_per_page => "20",
    });
	return $html."<h2>Complete and incomplete models currently owned by user:</h2><br>".$table->output();
}

sub reconstruction_page {
    my ($self) = @_;
    my $figmodel = $self->application()->data_handle('FIGMODEL');
    my $html = "<h2>Select genome for model construction</h2>
    	<div style='text-align: justify; width: 800px;'>The Model Seed will automatically reconstruct a preliminary genome-scale metabolic model for the selected organism. These models include the following components:
    	<ul style='list-style-type: disc;'>
    	<li>A draft of the stoichiometric network for the metabolic pathways of the organism including intraceullar enzymatic and spontaneous reactions and transmembrane transport reactions.</li>
    	<li>A preliminary biomass reaction containing amino acids, nucleotides, deoxynucleotides, lipids, cell wall components, and many cofactors</li>
    	<li>A set of predicted gene-protein-reaction relationships generated based on SEED/RAST genome annotations.</li>
    	<li>A list of intracellular and transport reactions that must be added to the draft network to enable the model to produce all biomass building blocks during growth in rich media.</li>
    	<li>Predictions of the behavior of reactions during 10% optimal growth on rich media by the preliminary model (essentiality, activity, and directionality).</li>
    	<li>Predictions of essential genes in the preliminary model during growh on rich media.</li>
    	<li>Predictions of essential nutrients and byproducts predicted for growth in the preliminary model.</li>
    	</ul>Select from the list below to build a new model. <a href=\"http://rast.nmpdr.org/\">If the required genome is not present, first submit the genome to RAST.</a> When the RAST annotation is complete, return to this menu.</div>
    ";
    if (!defined($figmodel->userObj()) || $figmodel->userObj()->login() eq "public") {
    	$html .= '<p style="color:red;">User must be logged in to build models</p><br>';
    	return $html;
    }
    my $mdls = $figmodel->database()->sudo_get_objects("model",{owner => $figmodel->user()});
	my $userModelHash;
	for (my $i=0; $i < @{$mdls}; $i++) {
		if ($mdls->[$i]->id() =~ m/^Seed/) {
			$userModelHash->{$mdls->[$i]->genome()} = 1;
		}
	}
    my $genomes = $figmodel->sapSvr()->all_genomes({
		-complete => 1,
		-prokaryotic => 1
	});
   	my $genomeData = $figmodel->sapSvr()->genome_data({
		-ids => [keys(%{$genomes})],
		-data => ["domain"]
	});
	my $handle = $figmodel->database()->get_object_manager("rastjob");
	my @jobs;
	if (defined($handle)) {
		push(@jobs,$handle->get_jobs_for_user_fast($figmodel->userObj(), 'view', 1));	
	}
	$handle = $figmodel->database()->get_object_manager("rasttestjob");
	if (defined($handle)) {
		push(@jobs,$handle->get_jobs_for_user_fast($figmodel->userObj(), 'view', 1));	
	}
	foreach my $j (@jobs) {
		if (!defined($genomes->{$j->{genome_id}})) {
			$genomes->{$j->{genome_id}} = "Private: ".$j->{genome_name};
			$genomeData->{$j->{genome_id}}->[0] = 'Unknown';
		}
	}
	#Loading data items for select box
	my $labels = [];
	my @genomeList = sort { ($genomes->{$b} =~ /^Private\: /) cmp ($genomes->{$a} =~ /^Private\: /) || lc($genomes->{$a}) cmp lc($genomes->{$b}) } keys(%{$genomes});
	my $values = [@genomeList];
	my $d2l = {Unknown => 'U',Archaea => 'A',Bacteria => 'B','Environmental Sample' => 'S',Eukaryota => 'E',Plasmid => 'P',Virus => 'V'};
	for (my $i=0; $i < @{$values}; $i++) {
		push(@{$labels},$genomes->{$values->[$i]}." [".$d2l->{$genomeData->{$values->[$i]}->[0]}."] (".$values->[$i].")");
	}
	#Creating select box
    my $select_box = $self->application()->component('GenomeSelect');
    $select_box->initial_text("type here for available genomes");
    $select_box->name('select_genome_for_reconstruction');
    $select_box->width(500);
    $select_box->multiple(0);
    $select_box->values($values);
    $select_box->labels($labels);
    $select_box->dropdown(1);
    $select_box->size(14);
    $html .= '<table><tr><td>'.$select_box->output().'</td><td><input type="button" value="Build preliminary model" onClick="submit_reconstruction();"></td></tr></table>';
    $html .= "<i>(Example search: 'bacillus', 'coli', 'Seed85962.1')</i>";
    return $html;
}

sub biomass_table {
    my ($self) = @_;
	#Getting web application objects
    my $html = "<table>";
    my $application = $self->application();
    my $cgi = $application->cgi();
    my $figmodel = $application->data_handle('FIGMODEL');
    my $objs = $figmodel->database()->get_objects("model");
    my $bofModelHash;
    for (my $i=0; $i < @{$objs};$i++) {
    	push(@{$bofModelHash->{$objs->[$i]->biomassReaction()}},$objs->[$i]->id());
    }
    my $UserID = "none";
    if (defined($self->application->session->user)) {
        $UserID = $self->application->session->user->login;
    }
    #Getting table object
    my $table = $application->component('biomass_table');
    $table->set_type("bof");
    my $objects = $table->get_objects();
    my $items = "50";
    my $biomass_rxn = $self->get_biomass_ids();
    my $bioids;
    if (defined($biomass_rxn)) {
    	for (my $i=0; $i < @{$biomass_rxn}; $i++) {
    		if ($biomass_rxn->[$i] =~ m/(.+)_((bio|rxn)\d\d\d\d\d)/) {
				push(@{$bioids},$2);
			} else {
				push(@{$bioids},$biomass_rxn->[$i]);
			}
    	}
    	$items = "10";
    }
    #Setting table columns
    my $columns = [
    	{ function => 'FIGMODELweb:create_reaction_link', call => 'FUNCTION:id', name => 'Biomass ID', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterBOFID' ) || "" },
	    { input => {cpdHash => $self->cpdHash()}, function => 'FIGMODELweb:display_reaction_equation', call => 'THIS', name => 'Equation', filter => 1, sortable => 1, width => '500', operand => $cgi->param( 'filterBOFEquation' ) || "" },
	    { input => {bofModelHash=>$bofModelHash}, function => 'FIGMODELweb:print_biomass_models', call => 'FUNCTION:id', name => 'Models', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterBOFModels' ) || "" },
	    { function => 'FIGMODELweb:print_compound_group(CofactorPackage)', call => 'FUNCTION:cofactorPackage', name => 'Cofactor set', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterBOFcof' ) || "" },
	    { function => 'FIGMODELweb:print_compound_group(LipidPackage)', call => 'FUNCTION:lipidPackage', name => 'Lipid set', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterBOFlip' ) || "" },
	    { function => 'FIGMODELweb:print_compound_group(CellWallPackage)', call => 'FUNCTION:cellWallPackage', name => 'Cell wall set', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterBOFwall' ) || "" }
	];
    $table->add_columns($columns);
    $table->set_table_parameters({
    	show_export_button => "1",
    	sort_column => "BOF",
    	width => "100%",
    	show_bottom_browse => "1",
    	show_top_browse => "1",
    	items_per_page => $items
    });
    my $blind = $application->component('biomassBlind');
    $blind->add_blind({ 'title' => "Biomass Select (Click this title bar to select biomass reactions for comparison)",
                        'content' => "<div style='padding:5px; padding-left:45px;'>".$table->output()."</div>",
                        'info' => ""
                      });
    $blind->width(1280);
    $html .= "<tr><td>".$blind->output()."</td></tr>";
    
    #Printing the selected biomass table
    if (defined($biomass_rxn)) {
    	#Getting table object
	    my $selectedbiomass = $application->component('selected_biomass');
	    $selectedbiomass->set_type("compound");
	    my $bioobjects;
	 	my $cpdHash;
	    for (my $i=0; $i < @{$biomass_rxn}; $i++) {
			my $rxnid = $biomass_rxn->[$i];
			if ($biomass_rxn->[$i] =~ m/(.+)_((bio|rxn)\d\d\d\d\d)/) {
				$rxnid = $2;
			}
			my $objs = $figmodel->database()->get_objects("cpdbof",{BIOMASS=>$rxnid});
			for (my $i=0; $i < @{$objs}; $i++) {
				if (!defined($cpdHash->{$objs->[$i]->COMPOUND()})) {
					$cpdHash->{$objs->[$i]->COMPOUND()} = 1;
					push(@{$bioobjects},$figmodel->database()->get_object("compound",{id=>$objs->[$i]->COMPOUND()}));
				}
			}
		}
	    $selectedbiomass->set_objects($bioobjects);
	    
	    #Setting table columns
	    my $modelargs = "(NONE)";
	    my $model_ids = $self->get_model_ids();
	    if (@{$model_ids} > 0) {
	    	$modelargs = "(".join(",",@{$model_ids}).")";
	    }
	    my $biocolumns = [
		    { call => 'FUNCTION:id', name => 'Compound', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterBOFcpdID' ) || "" },
		    { input => {-delimiter => ",<br>", object => "cpdals", function => "COMPOUND", type => "name"}, function => 'FIGMODELweb:display_alias', call => 'FUNCTION:id', name => 'Name', filter => 1, sortable => 1, width => '200', operand => $cgi->param( 'filterBOFcpdName' ) || "" },
		    { call => 'FUNCTION:formula', name => 'Formula', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterBOFcpdFormula' ) || "" },
		    { call => 'FUNCTION:mass', name => 'Mass', sortable => 1, width => '100'},
		    { input => {type => "compound"}, function => 'FIGMODELweb:display_keggmaps', call => 'FUNCTION:id', name => 'KEGG maps', filter => 1, sortable => 1, width => '200', operand => $cgi->param( 'filterBOFcpdKEGGMap' ) || "" },
			{ input => {-delimiter => ",", object => "cpdals", function => "COMPOUND", type => "KEGG"}, function => 'FIGMODELweb:display_alias', call => 'FUNCTION:id', name => 'KEGG CID', filter => 1, sortable => 1, width => '50', operand => $cgi->param( 'filterBOFcpdKEGGID' ) || "" }		    
		];
		for (my $i=0; $i < @{$biomass_rxn}; $i++) {
			if ($biomass_rxn->[$i] =~ m/(.+)_((bio|rxn)\d\d\d\d\d)/) {
				my $model = $1;
				my $rxnid = $2;
				push(@{$biocolumns},{ function => 'FIGMODELweb:print_compound_biomass_coef('.$rxnid.')', call => 'FUNCTION:id', name => $model.":<br>(".$rxnid.")", filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterBOFcpd'.$biomass_rxn->[$i] ) || "" });		
			} else {
				push(@{$biocolumns},{ function => 'FIGMODELweb:print_compound_biomass_coef('.$biomass_rxn->[$i].')', call => 'FUNCTION:id', name => $biomass_rxn->[$i], filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterBOFcpd'.$biomass_rxn->[$i] ) || "" });
			}
		}
		my $items = @{$bioobjects};
	    $selectedbiomass->add_columns($biocolumns);
	    $selectedbiomass->set_table_parameters({
	    	show_export_button => "0",
	    	sort_column => "Name",
	    	width => "100%",
	    	show_bottom_browse => "1",
	    	show_top_browse => "1",
	    	items_per_page => $items,
	    });
    	$html .= "<tr><td>".$selectedbiomass->output()."</td></tr>";
    }
    $html .= "</table>";

	return $html;
}

sub media_table {
	my ($self,$type) = @_;
	my $figmodel = $self->application()->data_handle('FIGMODEL');
	my $cgi = $self->application()->cgi();
	#Getting data
	my $cpdHash = $figmodel->database()->get_object_hash({type=>"compound",attribute=>"id"});
	my $mediaHash = $figmodel->database()->get_object_hash({type=>"mediacpd",attribute=>"MEDIA"});	
    #Getting table object
    my $table = $self->application()->component('MediaTable');
    $table->set_type("media");
    my $objects = $table->get_objects();
    #Setting table columns
    my $columns = [
    	{ call => 'FUNCTION:id', name => 'Media name', filter => 1, sortable => 1, width => '100', operand => $cgi->param( 'filterMediaName' ) || "" },
	    { input => {type => "name",mediaCpdHash => $mediaHash,compoundHash => $cpdHash}, function => 'FIGMODELweb:printMediaCompounds', call => 'FUNCTION:id', name => 'Media compound names', filter => 1, sortable => 1, width => '500', operand => $cgi->param( 'filterMediaCompoundNames' ) || "" },
	    { input => {type => "id",mediaCpdHash => $mediaHash,compoundHash => $cpdHash}, function => 'FIGMODELweb:printMediaCompounds', call => 'FUNCTION:id', name => 'Media compound IDs', filter => 1, sortable => 1, width => '500', operand => $cgi->param( 'filterMediaCompoundIDs' ) || "" }
	];
    $table->add_columns($columns);
    $table->set_table_parameters({
    	show_export_button => "1",
    	sort_column => "Media name",
    	width => "1200",
    	show_bottom_browse => "1",
    	show_top_browse => "1",
    	items_per_page => "50"
    });
	#Creating a div to hold the table
	my $html = "<div><table>\n
		<tr><th align='center'><b>Media Formulations Currently Available in the Database</b></th></tr>\n
		<tr><td>".$table->output()."</td></tr>\n
	</table></div>\n";
	return $html;
}

sub generate_model_overview {
    my ($self, $model_ids) = @_;
    my $figmodel = $self->application()->data_handle('FIGMODEL');
    my $model_overview = $figmodel->web()->get_model_overview_tbl($model_ids,$self->{_metagenome_page});
	#Setting the title string
	my $title_string;
    if( @$model_ids == 1 ) {
        $title_string =  "<b>Model Overview Page</b>";
    } else {
        $title_string = "<b>Model Comparison Page</b>";
    }
    return ($title_string, $model_overview);
}

sub generate_db_overview {
    my ($self) = @_;
    my $figmodel = $self->application()->data_handle('FIGMODEL');	
	my $modelObjs = $figmodel->database()->get_objects("model",undef,1);
	my $rxnObjs = $figmodel->database()->get_objects("reaction",undef,1);
	my $cpdObjs = $figmodel->database()->get_objects("compound",undef,1);
    my $db_overview = "
    	<div><table><tr>
    		<th style='width: 100px;' >Database </th>
    		<td> SEED </td>
    	</tr><tr>
    		<th style='width: 100px;'>Total Models</th>
    		<td>" . @{$modelObjs} . "</td>
    	</tr><tr>
    		<th style='width: 100px;'>Total Reactions</th>\
    		<td>" . @{$rxnObjs} . "</td>
    	</tr><tr>
    		<th style='width: 100px;' >Total Compounds</th>
    		<td>" . @{$cpdObjs} . "</td>
    	</tr></table></div>
    ";
    return ("<h3>Database Overview</h3>",$db_overview);
}

sub model_select_box {
    my ($self, $string) = @_;
    my $figmodel = $self->application()->data_handle('FIGMODEL');
    my $filter = $self->application()->component('modelfilterselect');
    $filter->width(500);
    $filter->size(14);
    $filter->dropdown(1);
    $filter->initial_text("type here to see available models");
    $filter->name("select_single_genome_model");
    # Getting the list of single genome models in the database
    my $labels = [];
    my $values = [];
    my $mdlObjs = $figmodel->database()->get_objects("model");
    @{$mdlObjs} = sort {    ( $a->name() || '' ) . $a->id() cmp
                            ( $b->name() || '' ) . $b->id()
                       } @{$mdlObjs};
    for (my $i=0; $i < @{$mdlObjs}; $i++) {
    	push(@{$labels}, ($mdlObjs->[$i]->name() || '') ." ( ".$mdlObjs->[$i]->id()." )");
    	push(@{$values},$mdlObjs->[$i]->id());
    }
    $filter->labels($labels);
    $filter->values($values);
    return "<table><tr><td>".$filter->output()."</td>".
        "<td><input type='button' value='Select Model' ".
        "onClick='select_model(\"select_single_genome_model\");'></td>".
        "</tr></table><i>(Example search: 'bacillus', 'coli', 'Seed85962.1')</i>";
}

sub check_model_change {
    my ($self) = @_;

    my $application = $self->application();
    my $cgi = $application->cgi();
    my $figmodel = $application->data_handle('FIGMODEL');

    if (defined($cgi->param('add_rxn_model')) && ($cgi->param('add_rxn_model') ne "") && defined($cgi->param('add_rxn_reaction')) && ($cgi->param('add_rxn_reaction') ne "")) {
		my $model_id = $cgi->param('add_rxn_model');
		my $rxn_id = $cgi->param('add_rxn_reaction');
		my $notes = $cgi->param('add_rxn_notes');
	
		my $model = $figmodel->get_model($model_id);
	
		# Locking the model so no one else can modify it
		$model->aquireModelLock();
		
		# First we get a copy of the unmodified original table for safe keeping
		my $originaltbl = $model->reaction_table();
	
		# This reloads the reaction table into a new object that you can modify
		# without modifying the original
		my $newtbl = $model->reaction_table(1);
	
		# Gather directionality
		my $reaction_table = $figmodel->database()->GetDBTable("REACTIONS");
		my $rxn_row = $reaction_table->get_row_by_key($rxn_id, 'DATABASE');
	
		my $dir = $rxn_row->{'REVERSIBILITY'}->[0];
	
		# Build row object
		my $new_row = {'LOAD' => [$rxn_id], 'DIRECTIONALITY' => [$dir], 'COMPARTMENT' => ['c'], 'ASSOCIATED PEG' => ['MANUAL'], 'SUBSYSTEM' => ['NONE'], 'CONFIDENCE' => ['NONE'], 'REFERENCE' => ['NONE'], 'NOTES' => [$notes]};
	
		# Add reaction
		$newtbl->add_row($new_row);
	
		# Calculating the changes and saving the changes in the model history table
		my @version = split(/\./, $model->version());
		$version[1]++;
		my $new_version = join(".", @version);
		$model->calculate_model_changes($originaltbl,"Added reaction $rxn_id: ".$notes,$newtbl,$new_version);
	
		# Saving the modified table
		$newtbl->save();
	
		# Releasing the lock on the model
		$model->releaseModelLock();
	
		$application->add_message('info', "Added reaction '$rxn_id' to model '$model_id': model updated to version '$new_version'");
    } elsif (defined($cgi->param('remove_rxn_model')) && ($cgi->param('remove_rxn_model') ne "") && defined($cgi->param('remove_rxn_reaction')) && ($cgi->param('remove_rxn_reaction') ne "")) {
		my $model_id = $cgi->param('remove_rxn_model');
		my $rxn_id = $cgi->param('remove_rxn_reaction');
		my $notes = $cgi->param('remove_rxn_notes');
	
		my $model = $figmodel->get_model($model_id);
	
		# Locking the model so no one else can modify it
		$model->aquireModelLock();
		
		# First we get a copy of the unmodified original table for safe keeping
		my $originaltbl = $model->reaction_table();
	
		# This reloads the reaction table into a new object that you can modify
		# without modifying the original
		my $newtbl = $model->reaction_table(1);
	
		# Remove reaction
		if ($newtbl->delete_row_by_key($rxn_id, 'LOAD') == 0) {
		    $application->add_message('warning', "Reaction '$rxn_id' not found in model '$model_id'");
		    return;
		}
	
		# Calculating the changes and saving the changes in the model history table
		my @version = split(/\./, $model->version());
		$version[1]++;
		my $new_version = join(".", @version);
		$model->calculate_model_changes($originaltbl,"Removed reaction $rxn_id: ".$notes,$newtbl,$new_version);
	
		# Saving the modified table
		$newtbl->save();
	
		# Releasing the lock on the model
		$model->releaseModelLock();
	
		$application->add_message('info', "Removed reaction '$rxn_id' from model '$model_id': model updated to version '$new_version'");
    }
}

sub add_alerts {
    my ($self) = @_;

    my $application = $self->application();
    my $cgi = $application->cgi();

    my $add_alert = $application->component('addAlert');
    my $remove_alert = $application->component('removeAlert');

    $add_alert->name('add_alert');
    $add_alert->type('confirm');
    $add_alert->form('addReactionForm');
    $add_alert->title('Add Reaction');
    $add_alert->width(400);
    $remove_alert->name('remove_alert');
    $remove_alert->type('confirm');
    $remove_alert->form('removeReactionForm');
    $remove_alert->title('Remove Reaction');
    $remove_alert->width(400);
    
    my $bold_style = "style='font-weight:bold;'";

    my $add_html = "<form name='addReactionForm' method='post'>";
    $add_html .= "<p>Are you sure you want to add reaction <span id='add_rxn_span' $bold_style></span> to model <span id='add_model_span' $bold_style></span>?</p>";
    $add_html .= "Reason for addition:<br /><textarea rows='2' cols='30' name='add_rxn_notes'>Manual addition.</textarea>";
    $add_html .= "<input type='hidden' name='add_rxn_reaction' id='add_rxn_reaction' value='' />";
    $add_html .= "<input type='hidden' name='add_rxn_model' id='add_rxn_model' value='' />";
    $add_html .= "<input type='hidden' id='page' name='page' value='ModelView' />";
    $add_html .= "<input type='hidden' id='model' name='model' value='".$cgi->param('model')."' />";
    $add_html .= "</form>";

    my $remove_html = "<form name='removeReactionForm' method='post'>";
    $remove_html .= "<p>Are you sure you want to remove reaction <span id='remove_rxn_span' $bold_style></span> from model <span id='remove_model_span' $bold_style></span>?</p>";
    $remove_html .= "Reason for removal:<br /><textarea rows='2' cols='30' name='remove_rxn_notes'>Manual removal.</textarea>";
    $remove_html .= "<input type='hidden' name='remove_rxn_reaction' id='remove_rxn_reaction' value='' />";
    $remove_html .= "<input type='hidden' name='remove_rxn_model' id='remove_rxn_model' value='' />";
    $remove_html .= "<input type='hidden' id='page' name='page' value='ModelView' />";
    $remove_html .= "<input type='hidden' id='model' name='model' value='".$cgi->param('model')."' />";
    $remove_html .= "</form>";

    $add_alert->content($add_html);
    $remove_alert->content($remove_html);

    return $add_alert->output() . $remove_alert->output();
}

sub require_javascript {
    return ["$FIG_Config::cgi_url/Html/ModelView.js","$FIG_Config::cgi_url/Html/EventManager.js"];
}

sub rxnHash {
    my ($self) = @_;
    if (!defined($self->{_rxnHash})) {
    	my $rxns = $self->figmodel()->database()->get_objects("reaction");
    	for (my $i=0; $i < @{$rxns}; $i++) {
    		$self->{_rxnHash}->{$rxns->[$i]->id()} = $rxns->[$i];
    	}
    }
    return $self->{_rxnHash};
}

sub cpdHash {
    my ($self) = @_;
    if (!defined($self->{_cpdHash})) {
    	my $cpds = $self->figmodel()->database()->get_objects("compound");
    	for (my $i=0; $i < @{$cpds}; $i++) {
    		$self->{_cpdHash}->{$cpds->[$i]->id()} = $cpds->[$i];
    	}
    }
    return $self->{_cpdHash};
}

sub cpdNAMEHash {
    my ($self) = @_;
    if (!defined($self->{_cpdNAMEHash})) {
    	my $objs = $self->figmodel()->database()->get_objects("cpdals",{ 'type' => 'name' });
    	for (my $i=0; $i < @{$objs}; $i++) {
    		push(@{$self->{_cpdNAMEHash}->{$objs->[$i]->COMPOUND()}},$objs->[$i]->alias());
    		push(@{$self->{_cpdNAMEHash}->{$objs->[$i]->alias()}},$objs->[$i]->COMPOUND());
    	}
    }
    return $self->{_cpdNAMEHash};
}

sub cpdKEGGHash {
    my ($self) = @_;
    if (!defined($self->{_cpdKEGGHash})) {
    	my $objs = $self->figmodel()->database()->get_objects("cpdals",{ 'type' => 'KEGG' });
    	for (my $i=0; $i < @{$objs}; $i++) {
    		push(@{$self->{_cpdKEGGHash}->{$objs->[$i]->COMPOUND()}},$objs->[$i]->alias());
    		push(@{$self->{_cpdKEGGHash}->{$objs->[$i]->alias()}},$objs->[$i]->COMPOUND());
    	}
    }
    return $self->{_cpdKEGGHash};
}

sub rxnNAMEHash {
    my ($self) = @_;
    if (!defined($self->{_rxnNAMEHash})) {
    	my $objs = $self->figmodel()->database()->get_objects("rxnals",{ 'type' => 'name' });
    	for (my $i=0; $i < @{$objs}; $i++) {
    		push(@{$self->{_rxnNAMEHash}->{$objs->[$i]->REACTION()}},$objs->[$i]->alias());
    		push(@{$self->{_rxnNAMEHash}->{$objs->[$i]->alias()}},$objs->[$i]->REACTION());
    	}
    }
    return $self->{_rxnNAMEHash};
}

sub rxnKEGGHash {
    my ($self) = @_;
    if (!defined($self->{_rxnKEGGHash})) {
    	my $objs = $self->figmodel()->database()->get_objects("rxnals",{ 'type' => 'KEGG' });
    	for (my $i=0; $i < @{$objs}; $i++) {
    		push(@{$self->{_rxnKEGGHash}->{$objs->[$i]->REACTION()}},$objs->[$i]->alias());
    		push(@{$self->{_rxnKEGGHash}->{$objs->[$i]->alias()}},$objs->[$i]->REACTION());
    	}
    }
    return $self->{_rxnKEGGHash};
}

sub figmodel {
    my ($self) = @_;
    if (!defined($self->{_figmodel})) {
    	$self->{_figmodel} = $self->application()->data_handle('FIGMODEL');
    }
    return $self->{_figmodel};
}

sub modeldata {
    my ($self,$id) = @_;
    if (!defined($self->{_modeldata}->{$id})) {
    	$self->{_modeldata}->{$id}->{model} = $self->figmodel()->get_model($id);
    	if (!defined($self->{_modeldata}->{$id}->{model})) {
    		$self->{_modeldata}->{$id} = {error => "Model ".$id." not found!"};
    	} else {
	    	$self->{_modeldata}->{$id}->{cpdtbl} = $self->{_modeldata}->{$id}->{model}->compound_table();
	    	$self->{_modeldata}->{$id}->{rxnmdl} = $self->{_modeldata}->{$id}->{model}->rxnmdlHash();
	    	$self->{_modeldata}->{$id}->{genome} = $self->{_modeldata}->{$id}->{model}->genome();
	    	$self->{_modeldata}->{$id}->{rxnclass} =  $self->{_modeldata}->{$id}->{model}->reaction_class_table();
	    	$self->{_modeldata}->{$id}->{cpdclass} =  $self->{_modeldata}->{$id}->{model}->compound_class_table();
    	}
    }
    return $self->{_modeldata}->{$id};
}

sub modelHash {
    my ($self) = @_;
	if (!defined($self->{_modelHash})) {  
   		if (defined($self->application()->cgi()->param('model'))) {
			my $modelList = [split(/,/,$self->application()->cgi()->param('model'))];
			for (my $i=0; $i < @{$modelList}; $i++) {
				my $data = $self->modeldata($modelList->[$i]);
				if (!defined($data->{error})) {
					$self->{_modelHash}->{$modelList->[$i]} = $data;
					push(@{$self->{_modelHash}->{array}},$modelList->[$i]);
				}
			}
		}
	}
	return $self->{_modelHash};
}

sub reaction {
	my ($self) = @_;
    if (!defined($self->{_reaction})) {
		$self->{_reaction} = $self->figmodel()->get_reaction();
    }
    return $self->{_reaction};
}

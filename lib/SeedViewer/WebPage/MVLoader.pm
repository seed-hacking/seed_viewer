package SeedViewer::WebPage::MVLoader;

use base qw( WebPage );

1;

use strict;
use warnings;
use Data::Dumper;
use FIG_Config;
use WebColors;
use JSON;
use FIGMODELweb;

sub init {
    my ($self) = @_;
    $self->title('Model View Loader');
    $self->application->register_component('Ajax', 'ajax');
    $self->application->register_component('AjaxQueue', 'ajaxQueue');
    $self->application->register_component('JSCaller', 'jscaller');
    $self->application->register_component('Console', 'console');
    $self->application->register_component('TabView', 'tabViewOverview');
    $self->application->register_component('TabView', 'tabViewModelInfo');
    $self->application->register_component('TabView', 'tabViewKeggMaps');
    $self->application->register_component('FilterSelect', 'modelfilterselect');
    $self->application->register_component('FilterSelect', 'mgmodelfilterselect');
    $self->application->register_component('CustomAlert', 'modelExceededAlert');
    $self->application->register_component('KEGGMap', 'keggmap');
    $self->application->register_component('MFBAController', 'mfba_controller');
    $self->application->register_component('RollerBlind', 'mfbaBlind');
    $self->application->register_component('EventManager', 'event_manager');
    $self->application->register_component('Table', 'mapTable');
    $self->application->register_component('Table', 'rxnTable');
    $self->application->register_component('Table', 'cpdTable');
    $self->application->register_component('Table', 'mdlTable');
    $self->application->register_component('Table', 'usrmdlTable');
    $self->application->register_component('RollerBlind', 'keggMapBlind');
    $self->application->register_component('Hover', 'keggMapHover');
    $self->application->register_component('FilterSelect', 'GenomeSelect');
    return 1;
}

sub output {
    my ($self) = @_;
    my $application = $self->application();
	$application->{layout}->add_css("$FIG_Config::cgi_url/Html/MVLoader.css");
    # First register all the tables here and pass to MVTable_create to allow additional table functions
    my $map_table = $self->get_map_table();
    my $rxn_table = $self->get_rxn_table();
    my $cpd_table = $self->get_cpd_table();
    my $mdl_table = $self->get_mdl_table();
    my $usrmdl_table = $self->get_usrmdl_table();
    $self->MVTable_create($map_table, "get_map_table", "mapTableDiv");
    $self->MVTable_create($cpd_table, "get_cpd_table", "cpdTableDiv");
    $self->MVTable_create($rxn_table, "get_rxn_table", "rxnTableDiv");
    $self->MVTable_create($mdl_table, "get_mdl_table", "mdlTableDiv");
    $self->MVTable_create($usrmdl_table, "get_usrmdl_table", "usrmdlTableDiv");
    # Next set up ajax calls
    my $ajax = $application->component('ajax');
    $ajax->create_request({'name' => 'getKeggMaps', 'type' => 'static',
        'url' =>'./Html/keggmap.tbl', 'onfinish' => 'processKeggMaps'});
	$ajax->create_request({'name' => 'getCompounds', 'type' => 'static',
        'url' => './Html/compounds.tbl', 'onfinish' => 'processCompounds'});
    $ajax->create_request({'name' => 'getReactions', 'type' => 'static',
        'url' => './Html/reactions.tbl', 'onfinish' => 'processReactions'});
    $ajax->create_request({'name' => 'loadModelSEED', 'type' => 'static',
        'url' => './Html/AboutModelSEED.txt', 'onfinish' => 'load_html_from_cache'}); 
	$ajax->create_request({'name' => 'getModels', 'type' => 'server',
        'sub' => 'load_models'});
    $ajax->create_request({'name' => 'getReactionLinkInfo', 'type' => 'server',
        'sub' => 'load_additional_rxn_info', 'onfinish' => 'addReactionLinkColumns'});
    $ajax->create_request({'name' => 'loadModelReconstructionMenu', 'type' => 'server',
        'sub' => 'reconstruction_page'});
	$ajax->create_request({'name' => 'loadFluxBalanceAnalysisResults', 'type' => 'server',
        'sub' => 'FBA_results_page'});
        
    #$ajax->create_request({'name' => 'getBiomass', 'type' => 'server',
    #    'sub' => 'load_biomass', 'onfinish' => 'processBiomass'});
    #$ajax->create_request({'name' => 'getMedia', 'type' => 'server',
    #    'sub' => 'load_media', 'onfinish' => 'processMedia'});
    # Now set up the AjaxQueue
    my $ajax_queue = $application->component('ajaxQueue');
    $ajax_queue->add_ajax("getKeggMaps", 0);
    $ajax_queue->add_ajax("getCompounds", 0);
    $ajax_queue->add_ajax("getReactions", 0);
    $ajax_queue->add_ajax("getModels", 0);
    $ajax_queue->add_ajax("getReactionLinkInfo", 0);
    $ajax_queue->add_ajax("loadModelReconstructionMenu", 0);
    $ajax_queue->add_ajax("loadFluxBalanceAnalysisResults", 0);
    #$ajax_queue->add_ajax("getBiomass", 0);
    #$ajax_queue->add_ajax("getMedia", 0);
    $ajax_queue->add_ajax("loadModelSEED", 0);
    # now start the queue once the page loads
    my $jscaller = $application->component('jscaller');
    $jscaller->call_function('AjaxQueue.start');
    my $html = $ajax->output();
    my $event_manager = $application->component('event_manager');
    #$html .= "This page attempts to load the ModelView information into javascript objects.<br />";
    $html .= model_exceeded_alert($self);
    #$html .= "<button onclick='Console.show();'>Show Console</button><br>";

    my $overview_tab_view = $application->component('tabViewOverview');
    $overview_tab_view->add_tab('Select Model', $self->model_select());
    $overview_tab_view->add_tab('Model construction',"<div id='reconstructionMenu'></div>");
    $overview_tab_view->add_tab('User models',"<div id='usrmdlTableDiv'>" . $usrmdl_table->output() . "</div>");
    $overview_tab_view->add_tab( 'Model statistics/Select',"<div id='mdlTableDiv'>" . $mdl_table->output() . "</div>");
    $overview_tab_view->add_tab('Flux Balance Results',"<div id='FBAResults'></div>");
    $overview_tab_view->add_tab( 'About Model SEED', $self->about_model_seed());
    $html .= $overview_tab_view->output();

    my $model_tab_view = $application->component('tabViewModelInfo');
    $model_tab_view->add_tab('Maps',$self->get_map_tab($map_table));
    $model_tab_view->add_tab('Reactions',"<div id='rxnTableDiv'>" . $rxn_table->output() . "</div>");
    $model_tab_view->add_tab('Compounds',"<div id='cpdTableDiv'>" . $cpd_table->output() . "</div>");
    #$model_tab_view->add_tab('Biomass Reactions', $bio_tab);
    $html .= $model_tab_view->output();
    
    $jscaller->call_function('initializeEvents');
    return $html . $event_manager->output();
}

sub about_model_seed {
	#return "<img src='http://bioseed.mcs.anl.gov/~chenry/FIG/CGI/Html/clear.gif'  onload='load_html_from_cache(\"AboutSeedPage.txt\");'>";
	return '<div id="AboutModelSEED"></div>';
}

sub model_select {
    my ($self) = @_;

    my $application = $self->application();
    my $figmodel = $application->data_handle('FIGMODEL');

    #Getting username
    my $UserID = "NONE";
    if (defined($self->application->session->user)) {
	$UserID = $self->application->session->user->login;
    }

    # Creating the filterselect object
    my $filter = $application->component('modelfilterselect');
    $filter->width(500);
    $filter->size(14);
    $filter->dropdown(1);
    $filter->initial_text("type here to see available models");

    # Getting the list of single genome models in the database
    my $modelList = $figmodel->get_models({users => "all"});
    if ($UserID ne "NONE") {
	my $temp = $figmodel->get_models({users => ["%|".$UserID."|%","like"]}); 
	if (defined($temp)) {
	    push(@{$modelList},@{$temp});
	}
    }
    my $labels = [];
    my $values = [];
    #my $attributes = [  { name => 'Type', possible_values => [ 'Metagenome models' , 'Single genome models' ], values => [] } ];
    @{$modelList} = sort {$a->name().$a->id() cmp $b->name().$b->id()} @{$modelList};
    for (my $i=0; $i < @{$modelList}; $i++) {
	push(@{$labels},$modelList->[$i]->name()." ( ".$modelList->[$i]->id()." )");
    	push(@{$values},$modelList->[$i]->id());
    	#push(@{$attributes->[0]->{values}},'Single genome models');
    }
    $filter->name("select_single_genome_model");
    $filter->labels($labels);
    $filter->values($values);
    my $html = "<table><tr>";
    my $buttonText = "Select Model";
    if (defined($self->{_metagenome_page}) && $self->{_metagenome_page} == 1) {
    	# Getting the list of metagenome models in the database
	my $mgfilter = $application->component('mgmodelfilterselect');
	$mgfilter->name("select_metagenome_model");
	$mgfilter->width(500);
	$mgfilter->size(14);
	$mgfilter->dropdown(1);
	$mgfilter->initial_text("type here to see available metagenome models");
    	$labels = [];
	$values = [];
    	my $mgmodelList = $figmodel->get_models(undef,1);
    	@{$mgmodelList} = sort {$a->name().$a->id() cmp $b->name().$b->id()} @{$mgmodelList};
    	for (my $i=0; $i < @{$mgmodelList}; $i++) {
	    push(@{$labels},$mgmodelList->[$i]->name()." ( ".$mgmodelList->[$i]->id()." )");
	    push(@{$values},$mgmodelList->[$i]->id());
	    #push(@{$attributes->[0]->{values}},'Metagenome models');
	}
	$mgfilter->labels($labels);
	$mgfilter->values($values);
	$html .= "<td>".$mgfilter->output().'</td><td><input type="button" value="Select Metagenome Model" onClick="selectModel(\'select_metagenome_model\');"></td>';
	$buttonText = "Select single genome model";
	$filter->initial_text("type here to see available single genome models");
    	#$filter->attributes($attributes);
	#$filter->auto_place_attribute_boxes(0);
    }
    $html .= "<td>".$filter->output().'</td><td><input type="button" value="'.$buttonText.'" onClick="selectModel(\'select_single_genome_model\');"></td>';
    #Creating the model select form
    #my $html = '<form action="" onsubmit="addModelParam( this.filter_select_'.$filter->{id}.'.value ); return false;" >';
    $html .= '</tr></table>';
    $html .= "<i>(Example search: 'bacillus', 'coli', 'Seed85962.1')</i>";
    #$html .= "</form>";

    $html .= "<br /><br />";

    my $header = "<tr><td></td><th style='width: 100px;'>Model ID</th>";
    $header .= "<th style='width: 150px;'>Organism</th>";
    $header .= "<th style='width: 80px;' >Version</th><th style='width: 80px;' >Source</th>";
    $header .= "<th style='width: 80px;' >Genome size</th><th style='width: 80px;' >Model genes</th><th style='width: 80px;' >Reactions with genes</th><th style='width: 80px;' >Gapfilling Reactions</th>".
	"<th style='width: 80px;' >Gapfilling Media</th><th style='width: 80px;' >Compounds</th><td></td></tr>";
		
    # make the selected models table
    $html .= "<table id='selected_model_table' style='display:none'>$header</table>";
    my $mfbaControl = $application->component('mfba_controller');
    my $mfbaBlind = $application->component('mfbaBlind');
    $mfbaBlind->add_blind( { 'title' => "<strong>Run FBA on selected models</strong>",
                             'content' => "<div id='mfbaControls' style='padding:5px;'>".
                                $mfbaControl->outputFluxControls()."</div>",
                             'info' => "" });
    $html .= $mfbaBlind->output();

    return $html;

}

sub get_map_table {
    my ($self) = @_;

    my $application = $self->application();

    my $map_table = $application->component('mapTable');
    $map_table->columns( [  { 'name' => 'Name', 'filter' => 1 },
                        { 'name' => 'Reactions', 'sortable' => 1 },
                        { 'name' => 'Compounds', 'sortable' => 1 },
                        { 'name' => 'EC Numbers', 'sortable' => 1 }
                     ] );

    $map_table->items_per_page(6);
    $map_table->show_bottom_browse(1);
    $map_table->width(900);
    $map_table->dynamic_data(1);

    return $map_table;
}

sub get_map_tab {
    my ($self, $map_table) = @_;

    my $application = $self->application();

    my $blind = $application->component('keggMapBlind');
    $blind->add_blind({ 'title' => "Map Select",
			'content' => "<div id='mapTableDiv' style='padding:5px;'>".$map_table->output()."</div>",
			'info' => 'click to show/hide',
			'active' => 1 });
    $blind->width(1000);
    
    my $mapTabs = $application->component('tabViewKeggMaps');
    $mapTabs->dynamic(1);

    # set up hover and use hidden input to store hover id
    my $hover = $application->component('keggMapHover');
    my $hover_input = "<input type='hidden' id='keggMapHover' value='" . $hover->id() . "' />";

    my $html = $hover->output();
    $html .= $hover_input;
    $html .= $blind->output();
    $html .= "<span id='tooltip_" . $hover->id() . "_current' value='' style='display: none;'></span>";
    $html .= "<div id='keggmap_popup' value='' style='display: none;'></div>";
    $html .= "<div id='modelKey' style='padding:10px;'></div>";
    $html .= $mapTabs->output();

    return $html;
}

# load reaction roles and subsystems, which is subject to change
# more often than static reaction info such as name, equation, etc...
sub load_additional_rxn_info {
    my ($self) = @_;
	
    my $application = $self->application();
    my $cgi = $application->cgi();
    my $figmodel = $application->data_handle('FIGMODEL');
    my $jscaller = $application->component('jscaller');
    $application->component('console')->println("Loading reaction links...");

    my $rxn_table = $figmodel->database()->GetDBTable("REACTIONS");
    my $role_mapping_table = $figmodel->database()->GetDBTable("ROLE MAPPING TABLE");
    my $subsystem_table = $figmodel->database()->GetLinkTable("REACTION","SUBSYSTEM");
    my $rxn_info = [];
    for (my $i=0; $i<$rxn_table->size(); $i++) {
	my (@roles, @model_role_out, @subsystems);

	my $rxn_row = $rxn_table->get_row($i);
	my $rxn_id = $rxn_row->{"DATABASE"}->[0];
	my $roles = $figmodel->roles_of_reaction($rxn_id);
	if (defined($roles)) {
	    @roles = @$roles;
	}
	my %role_hash;
	map {$role_hash{lc($_)} = 1} @$roles;

	my @model_roles = $role_mapping_table->get_rows_by_key($rxn_id,"REACTION");
	foreach my $model_role (@model_roles) {
	    my $role = $model_role->{"ROLE"}->[0];
	    if (defined($role) && !defined($role_hash{lc($role)})) {
		$role_hash{lc($role)} = 1;
		push(@model_role_out, $role . "\$" . join("~", @{$model_role->{"SOURCE"}}));
	    }
	}

	my $rxn_subsys_row = $subsystem_table->get_row_by_key($rxn_id,"REACTION");
	my $subsystems = $rxn_subsys_row->{"SUBSYSTEM"};
	if (defined($subsystems)) {
	    @subsystems = @$subsystems;
	}

	unless (scalar(@roles) == 0 && scalar(@model_role_out) == 0 && scalar(@subsystems) == 0) {
	    my $output = $rxn_id . ";";
	    $output .= join("|", @roles) . ";";
	    $output .= join("|", @model_role_out) . ";";
	    $output .= join("|", @subsystems);
	    push (@$rxn_info, $output);
	}
    }

    $jscaller->call_function_data("processReactionLinkInfo", $rxn_info);

    return;
}

# load reaction roles and subsystems, which is subject to change
# more often than static reaction info such as name, equation, etc...
sub load_models {
    my ($self) = @_;
    
    my $application = $self->application();
    my $cgi = $application->cgi();
    my $figmodel = $application->data_handle('FIGMODEL');
	my $modelObjs = $figmodel->database()->get_objects("model",{users=>"all"});
    my $UserID = "NONE";
    if (defined($self->application->session->user)) {
        $UserID = $self->application->session->user->login;
        push(@{$modelObjs},@{$figmodel->database()->get_objects("model",{users => ["%|".$UserID."|%","like"]})});
    }
	my $model_info;
	for (my $i=0; $i < @{$modelObjs}; $i++) {
		my $obj = $modelObjs->[$i];
		if (defined($obj->owner())) {
			my $owner = $obj->owner();
			if ($UserID eq $obj->owner()) {
				$owner = "SELF";
			}
			my $genomeName = $figmodel->get_genome_stats($obj->genome())->{NAME}->[0];
			my $geneCount = $figmodel->get_genome_stats($obj->genome())->{"TOTAL GENES"}->[0];
			my $geneSize = $figmodel->get_genome_stats($obj->genome())->{"SIZE"}->[0];
			my $gapfilledrxn = $obj->spontaneousReactions()+$obj->autoCompleteReactions()+$obj->biologReactions()+$obj->gapFillReactions();
			my $modelString = $obj->id().";".$owner.";".$obj->users().";".$genomeName.";".$geneSize.";".$obj->genome().";".
							$obj->source().";".$obj->modificationDate().";".$obj->builtDate().";".$obj->autocompleteDate().";".$obj->status().";".
							$obj->version().".".$obj->autocompleteVersion().";".$obj->message().";".$obj->cellwalltype().";".$obj->associatedGenes().";".
							$geneCount.";".$obj->reactions().";".$obj->compounds().";".$gapfilledrxn.";".$obj->autoCompleteTime().";".
							$obj->autoCompleteMedia().";".$obj->biomassReaction().";".$obj->growth().";".$obj->noGrowthCompounds();
			push(@{$model_info},$modelString);
		}
	}
	my $jscaller = $application->component('jscaller');
	$jscaller->call_function_data("processModels",$model_info);
    return;
}

#sub load_biomass {
#    my ($self) = @_;
#    my $application = $self->application();
#    my $cgi = $application->cgi();
#    my $figmodel = $application->data_handle('FIGMODEL');
#	my $biomassObjs = $figmodel->database()->get_objects("model",{users=>"all"});
#	push(@{$biomassObjs},$figmodel->database()->get_objects("model",{users => ["%|".$UserID."|%","like"]}));
#	my $biomass_info;
#	for (my $i=0; $i < @{$biomassObjs}; $i++) {
#		my $obj = $biomassObjs->[$i];
#		my $biomassString = $obj->id().";".$obj->owner().";".$obj->users().";".$genomeName.";".$genomeSize.";".
#						$obj->genome().";".$obj->source().";".$obj->modificationDate().";".$obj->builtDate().";".
#						$obj->autocompleteDate().";".$obj->status().";".$obj->version().".".$obj->autocompleteVersion().";".
#						$obj->message().";".$obj->cellwalltype().";".$obj->associatedGenes().";".$geneCount.";".$obj->reactions().";".
#						$obj->compounds().";".$obj->spontaneousReactions()+$obj->autoCompleteReactions()+$obj->biologReactions()+$obj->gapFillReactions().";".
#						$obj->autoCompleteTime().";".$obj->autoCompleteMedia().";".$obj->biomassReaction().";".$obj->growth().";".$obj->noGrowthCompounds();
#		push(@{$model_info},$biomassString);
#	}
#	my $jscaller = $application->component('jscaller');
#	$jscaller->call_function_data("processBiomass", $biomass_info);
#    return;
#}

#sub load_media {
#    my ($self) = @_;
#    my $application = $self->application();
#    my $cgi = $application->cgi();
#    my $figmodel = $application->data_handle('FIGMODEL');
#	my $mediaObjs = $figmodel->database()->get_objects("media",{users=>"all"});
#	push(@{$mediaObjs},$figmodel->database()->get_objects("media",{users => ["%|".$UserID."|%","like"]}));
#	my $media_info;
#	for (my $i=0; $i < @{$mediaObjs}; $i++) {
#		my $obj = $mediaObjs->[$i];
#		my $mediaString = $obj->id().";".$obj->owner().";".$obj->users().";".$genomeName.";".
#						$obj->genome().";".$obj->source().";".$obj->modificationDate().";".$obj->builtDate().";".
#						$obj->autocompleteDate().";".$obj->status().";".$obj->version().".".$obj->autocompleteVersion().";".
#						$obj->message().";".$obj->cellwalltype().";".$obj->associatedGenes().";".$geneCount.";".$obj->reactions().";".
#						$obj->compounds().";".$obj->spontaneousReactions()+$obj->autoCompleteReactions()+$obj->biologReactions()+$obj->gapFillReactions().";".
#						$obj->autoCompleteTime().";".$obj->autoCompleteMedia().";".$obj->biomassReaction().";".$obj->growth().";".$obj->noGrowthCompounds();
#		push(@{$media_info},$mediaString);
#	}
#	my $jscaller = $application->component('jscaller');
#	$jscaller->call_function_data("processMedia", $media_info);
#    return;
#}

sub get_model_info {
    my ($self) = @_;
    my $application = $self->application();
    my $cgi = $application->cgi();
    my $figmodel = $application->data_handle('FIGMODEL');
    my $jscaller = $application->component('jscaller');
    my $model_id = $cgi->param('model');
    my $model = $figmodel->get_model($model_id);
    if ($model) {
		my (@reactions, @compounds);
		my $rxn_table = $model->reaction_table();
		my $cpd_table = $model->compound_table();
		# get reactions
		for (my $i=0; $i<$rxn_table->size(); $i++) {
		    my $reaction = $rxn_table->get_row($i);
		    my $rxn_id = $reaction->{'LOAD'}->[0];
		    # Get reaction class
		    my $class = $model->get_reaction_class($rxn_id, 1);
		    # Get genes
		    my $peg_string = join("|",@{$reaction->{"ASSOCIATED PEG"}});
		    $peg_string =~ s/\+/|/g;
		    $peg_string =~ s/,/|/g;
		    my %peg_hash;
		    map{$peg_hash{$_} = 1} split(/\|/, $peg_string);
		    my $genes = join("|", keys(%peg_hash));
		    # Get notes
		    my $notes = $reaction->{"NOTES"}->[0];
		    push(@reactions, "$rxn_id;$class;$genes;$notes");
		}
		# get compounds
		for (my $i=0; $i<$cpd_table->size(); $i++) {
		    my $compound = $cpd_table->get_row($i);
		    my $cpd_id = $compound->{"DATABASE"}->[0];
	
		    my $biomass = '';
		    if (defined( $compound->{"BIOMASS"} )) {
			$biomass = join("|", @{$compound->{"BIOMASS"}});
		    }
	
		    my $transports = '';
		    if (defined( $compound->{"TRANSPORTERS"} )) {
			$transports = join("|", @{$compound->{"TRANSPORTERS"}});
		    }
	
		    push(@compounds, "$cpd_id;$biomass;$transports");
		}
		#Adding data column to the overview table
		my $model_info = {id=>$model->id(),reactions => \@reactions,compounds => \@compounds};
		$jscaller->call_function_data("selectModelResponse", $model_info);
		return;
    } else {
		# Error: no such model
		return;
    }
}

sub FBA_results_page {
    my ($self) = @_;
    my $application = $self->application();
    my $cgi = $application->cgi();
    my $figmodel = $application->data_handle('FIGMODEL');
    my $html = $application->component('mfba_controller')->outputResultsTable();    
    my $data = {div=>"FBAResults",content=>$html};
    my $jscaller = $application->component('jscaller');
    $jscaller->call_function_data("fillDiv",$data);
}

sub reconstruction_page {
    my ($self) = @_;
    my $application = $self->application();
    my $cgi = $application->cgi();
    my $figmodel = $application->data_handle('FIGMODEL');
    my $fig = $figmodel->fig();
    #Getting user information
    my $user = $application->session->user;
    my $UserID = "NONE";
    my $usermodels;
    my $userModelHash;
    if (defined($user)) {
	$UserID = $user->login;
	$usermodels = $figmodel->get_models({owner => $UserID});
        if (defined($usermodels)) {
            for (my $i=0; $i < @{$usermodels}; $i++) {
		if ($usermodels->[$i]->id() =~ m/^Seed/) {
		    $userModelHash->{$usermodels->[$i]->genome()} = 1;
		}
            }
        }
    }
    #Introductory text
    my $html = "<h2>Select genome for model construction</h2>";
    $html .= "<div style='text-align: justify; width: 800px;'>The Model Seed will automatically reconstruct a preliminary genome-scale metabolic model for the selected organism. These models include the following components:";
    $html .= '<ul style="list-style-type: disc;">';
    $html .= "<li>A draft of the stoichiometric network for the metabolic pathways of the organism including intraceullar enzymatic and spontaneous reactions and transmembrane transport reactions.</li>";
    $html .= "<li>A preliminary biomass reaction containing amino acids, nucleotides, deoxynucleotides, lipids, cell wall components, and many cofactors</li>";
    $html .= "<li>A set of predicted gene-protein-reaction relationships generated based on SEED/RAST genome annotations.</li>";
    $html .= "<li>A list of intracellular and transport reactions that must be added to the draft network to enable the model to produce all biomass building blocks during growth in rich media.</li>";
    $html .= "<li>Predictions of the behavior of reactions during 10% optimal growth on rich media by the preliminary model (essentiality, activity, and directionality).</li>";
    $html .= "<li>Predictions of essential genes in the preliminary model during growh on rich media.</li>";
    $html .= "<li>Predictions of essential nutrients and byproducts predicted for growth in the preliminary model.</li>";
    $html .= "</ul>Select from the list below to build a new model. <a href=\"http://rast.nmpdr.org/\">If the required genome is not present, first submit the genome to RAST.</a> When the RAST annotation is complete, return to this menu.</div>";
    #Getting genome information
    my $genome_info = $fig->genome_info();
    my $genomes  = [];
    my $handled = {};
    foreach my $genome (@$genome_info) {
        $handled->{$genome->[0]} = 1;
        if (!defined($userModelHash) || !defined($userModelHash->{$genome->[0]})) {
            push(@$genomes,{id => $genome->[0],name => $genome->[1],maindomain => $genome->[3]});
        }
    }
    #Checking that the user is logged in before enabling the submit button
    if ($UserID eq "NONE") {
        $html .= '<p style="color:red;">User must be logged in to build models</p><br>';
    } elsif ($user) {
	my $handle = $figmodel->database()->get_object_manager("rastjob");
	my @jobs;
	if (defined($handle)) {
	    push(@jobs,$handle->get_jobs_for_user_fast($user, 'view', 1));	
	}
	$handle = $figmodel->database()->get_object_manager("rasttestjob");
	if (defined($handle)) {
	    push(@jobs,$handle->get_jobs_for_user_fast($user, 'view', 1));	
	}
	foreach my $j (@jobs) {
	    next if $handled->{$j->{genome_id}};
	    if (!defined($userModelHash) || !defined($userModelHash->{$j->{genome_id}})) {
		push(@$genomes,{id => $j->{genome_id},name => "Private: ".$j->{genome_name},maindomain => 'Bacteria'});
	    }
	}
    }
    #Sorting genomes alphabetically
    @$genomes = sort { ($b->{name} =~ /^Private\: /) cmp ($a->{name} =~ /^Private\: /) || lc($a->{name}) cmp lc($b->{name}) } @$genomes;
    #Populating select box with genomes
    my $values = [];
    my $labels = [];
    my $select_box = $application->component('GenomeSelect');
    my $d2l = {Archaea => 'A',Bacteria => 'B','Environmental Sample' => 'S',Eukaryota => 'E',Plasmid => 'P',Virus => 'V' };
    foreach my $genome (@$genomes) {
	push(@$values, $genome->{id});
	push(@$labels, $genome->{name} . " [" . $d2l->{$genome->{maindomain}} . "] (" . $genome->{id} . ")");
    }
    $select_box->initial_text("type here for available genomes");
    $select_box->name('select_genome_for_reconstruction');
    $select_box->width(500);
    $select_box->multiple(0);
    $select_box->values($values);
    $select_box->labels($labels);
    $select_box->dropdown(1);
    $select_box->size(14);
    #Disabling select button if no user is logged in
    my $disabled = "";
    if ($UserID eq "NONE") {
        $disabled = 'disabled="true" title="User must be logged in to build new models"';
    }
    #Printing select box and submit button
    $html .= '<table><tr><td>'.$select_box->output().'</td><td><input type="button" value="Build preliminary model" onClick="submit_reconstruction();" '.$disabled.'></td></tr></table>';
    $html .= "<i>(Example search: 'bacillus', 'coli', 'Seed85962.1')</i>";
    my $data = {div=>"reconstructionMenu",content=>$html};
    my $jscaller = $application->component('jscaller');
    $jscaller->call_function_data("fillDiv",$data);
}

sub get_rxn_table {
    my ($self) = @_;

    my $application = $self->application();
    my $cgi = $application->cgi();

    my $rxn_table = $application->component('rxnTable');
    my $column_names = ["Reaction","Name","Equation","KEGG MAP","Enzyme","KEGG RID"];
    my $column_widths = [100,200,400,100,100,100];

    my $columns;
    for (my $i=0; $i<@$column_names; $i++) {
	$columns->[$i] = { name => $column_names->[$i], filter => 1, sortable => 1, width => $column_widths->[$i] };
    }

    $rxn_table->columns($columns);
    $rxn_table->items_per_page(50);
    $rxn_table->show_select_items_per_page(1);
    $rxn_table->show_top_browse(1);
    $rxn_table->show_bottom_browse(1);
    $rxn_table->show_column_select(1);
    $rxn_table->dynamic_data(1);

    return $rxn_table;
}

sub get_cpd_table {
    my ($self) = @_;

    my $application = $self->application();
    my $cgi = $application->cgi();

    my $cpd_table = $application->component('cpdTable');
    my $column_names = ["Compound","Name","Formula","Mass","KEGG MAP","KEGG CID","Model ID"];
    my $column_widths = [100,200,100,50,100,50,50];

    my $columns;
    for (my $i=0; $i<@$column_names; $i++) {
	$columns->[$i] = { name => $column_names->[$i], filter => 1, sortable => 1, width => $column_widths->[$i] };
    }

    $cpd_table->columns($columns);
    $cpd_table->show_export_button(1);
    $cpd_table->items_per_page(50);
    $cpd_table->show_select_items_per_page(1);
    $cpd_table->show_top_browse(1);
    $cpd_table->show_bottom_browse(1);
    $cpd_table->dynamic_data(1);

    return $cpd_table;
}

sub get_mdl_table {
    my ($self) = @_;
    my $application = $self->application();
    my $cgi = $application->cgi();
    my $mdl_table = $application->component('mdlTable');
    my $column_names = ["Name","Organism","Genome ID","Class","Genes","Reactions","Gapfilled Reactions","Compounds","Source","Download","Version","Last update"];
    my $column_widths = [100,200,100,100,100,100,100,100,100,100,100,100];
    my $columns;
    for (my $i=0; $i<@$column_names; $i++) {
		$columns->[$i] = { name => $column_names->[$i], filter => 1, sortable => 1, width => $column_widths->[$i] };
    }
    $mdl_table->columns($columns);
    $mdl_table->show_export_button(1);
    $mdl_table->items_per_page(50);
    $mdl_table->show_select_items_per_page(1);
    $mdl_table->show_top_browse(1);
    $mdl_table->show_bottom_browse(1);
    $mdl_table->dynamic_data(1);
    return $mdl_table;
}

sub get_usrmdl_table {
    my ($self) = @_;
    my $application = $self->application();
    my $cgi = $application->cgi();
    my $usrmdl_table = $application->component('usrmdlTable');
    my $column_names = ["Name","Organism","Genome ID","Status","Download","Version","Last update"];
    my $column_widths = [100,200,100,100,100,100,100];
    my $columns;
    for (my $i=0; $i<@$column_names; $i++) {
		$columns->[$i] = { name => $column_names->[$i], filter => 1, sortable => 1, width => $column_widths->[$i] };
    }
    $usrmdl_table->columns($columns);
    $usrmdl_table->show_export_button(1);
    $usrmdl_table->items_per_page(50);
    $usrmdl_table->show_select_items_per_page(1);
    $usrmdl_table->show_top_browse(1);
    $usrmdl_table->show_bottom_browse(1);
    $usrmdl_table->dynamic_data(1);
    return $usrmdl_table;
}

sub model_exceeded_alert {
    my ($self) = @_;

    my $alert = $self->application->component('modelExceededAlert');
    $alert->name("models_exceeded");
    $alert->title("Too Many Models");
    $alert->content("Sorry but you have exceeded the number of models that can be selected at one time. Please remove a model and try again."); 

    return $alert->output();
}

sub get_kegg_map {
    my ($self) = @_;

    my $application = $self->application();
    my $cgi = $application->cgi();

    my $keggmap = $application->component('keggmap');
    my $pathway = $cgi->param('pathway');
    my $num_models = $cgi->param('num_models');
    my $rxn_color = $cgi->param('reactions');
    my $cpd_color = $cgi->param('compounds');

    # get the coloring information
    my $rxn_colors = WebColors::get_palette('varied');
    $rxn_colors->[$num_models] = [128, 0, 128];
    my $cpd_colors = [[0, 255, 0], [255, 0, 0], [0, 0, 255]];

    my @highlights;
    if ($rxn_color) {
	my @reactions = split(/\|/, $rxn_color);
	foreach (@reactions) {
	    my @color_codes = split(",");
	    my $kegg_rxn = shift(@color_codes);
	    my @colors;
	    map {push(@colors, $rxn_colors->[$_])} @color_codes;

	    my $param_hash = { 'id' => $kegg_rxn, 'color' => \@colors };
	    push(@highlights, $param_hash);
	}
    }

    if ($cpd_color) {
	my @compounds = split(/\|/, $cpd_color);
	foreach (@compounds) {
	    my @color_codes = split(",");
	    my $kegg_cpd = shift(@color_codes);
	    my @colors;
	    map {push(@colors, $cpd_colors->[$_])} @color_codes;

	    my $param_hash = { 'id' => $kegg_cpd, 'color' => \@colors };
	    push(@highlights, $param_hash);
	}
    }

    $keggmap->map_id($pathway);
    $keggmap->highlights( \@highlights );
    $keggmap->area(0);
    my $map_coords = $keggmap->map_coordinates();
    my $ec_coords = $keggmap->ec_coordinates();
    my $rxn_coords = $keggmap->reaction_coordinates();
    my $cpd_coords = $keggmap->compound_coordinates();

    my $map_hash = {'id' => $pathway, 'name' => $keggmap->map_name(), 'mapCoords' => $map_coords, 
                    'ecCoords' => $ec_coords, 'rxnCoords' => $rxn_coords, 'cpdCoords' => $cpd_coords};
    my $html = "<div id='keggmap_$pathway'>";
    $html .= $keggmap->output();
    $html .= "</div>";
    $html .= "<input type='hidden' id='mapInfo_$pathway' value='" . encode_json($map_hash) . "' />";

    return $html;
}

#  makes a Table component dynamic via MVTable interface here and in MVLoader.js
sub MVTable_create {
    my ($self, $table, $subroutine, $div) = @_;
    # create copy of columns so they aren't transformed when table->output is called
    my $columns;
    my $originalColumns = $table->columns();
    for (my $i=0; $i < @{$originalColumns}; $i++) {
    	push(@{$columns},{name=>$originalColumns->[$i]->{name},
                          filter=>$originalColumns->[$i]->{filter},
                          sortable=>$originalColumns->[$i]->{sortable},
                          width=>$originalColumns->[$i]->{width},
                          operand=>$originalColumns->[$i]->{operand}
                         });
    }
    my $mvtable = {name => $table->{_id}, columns => $columns, subroutine => $subroutine, div => $div};

    my $jscaller = $self->application->component('jscaller');
    $jscaller->call_function_data("createMVTable", $mvtable);
}

sub MVTable_reload {
    my ($self) = @_;

    my $cgi = $self->application->cgi();
    my $mvtable_json = $cgi->param('mvtable');

    my $mvtable = decode_json($mvtable_json);

    my $subroutine = $mvtable->{subroutine};
    my $table;
    eval {$table = $self->$subroutine(); };

    $table->columns($mvtable->{columns});

    return $table->output();
}

sub require_javascript {
    return ["$FIG_Config::cgi_url/Html/MVLoader.js","$FIG_Config::cgi_url/Html/PopUp.js"];
}

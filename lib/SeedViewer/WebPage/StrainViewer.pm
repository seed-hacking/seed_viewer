package SeedViewer::WebPage::StrainViewer;

use base qw( WebPage );

1;

use strict;
use warnings;
use FIGMODEL; # Fig subset of FigModel
use UnvSubsys;

=pod

=head1 NAME

StrainViewer

=head1 DESCRIPTION

View or create strains for an organism.

=head1 METHODS

=over 4

=item * B<init> ()

Initialise the page

=cut

sub init {
  	my $self = shift;
	$self->title('Strain Viewer');
	$self->application->register_component('StrainHeader', 'strain_header');
	# New interval components
	$self->application->register_component('Table', 'interval_select_table');
	$self->application->register_component('GrowthData', 'interval_select_growth');
	# Strain Select components
	$self->application->register_component('StrainTable', 'strain_table');
	# general components
	$self->application->register_component('StrainTree', 'strain_tree');
	$self->application->register_component('TabView', 'strain_tv');
    $self->application->register_component('Ajax', 'page_ajax');
	# Strain View components
	$self->application->register_component('GrowthData', 'growth_display');
	$self->application->register_component('TabView', 'prediction_tv');
	$self->application->register_component('GeneTable', 'gene_table');
	$self->application->register_component('IntervalTable', 'interval_table');
	$self->application->register_component('CompoundTable', 'cpd_table');
	$self->application->register_component('ReactionTable', 'rxn_table');
	$self->application->register_component('ReactionTable', 'ko_rxn_table');
	#$self->application->register_component('Comments', 'strain_discussion');
}

=item * B<output> ()

Returns the html output of the Reaction Viewer page.

=cut
sub output {
	my ($self) = @_;
	my $html = '';
	my $application = $self->application();
	my $model = $application->data_handle('FIGMODEL');
	my $cgi = $application->cgi();
	my $Username = $application->session->user;

	my $interval_select_table   = $application->component('interval_select_table');
	my $strain_tree 			= $application->component('strain_tree');
	my $strain_table			= $application->component('strain_table');
	my $strain_header			= $application->component('strain_header');
	my $strain_tv				= $application->component('strain_tv');
    my $ajax = $application->component('page_ajax');
    $html .= $ajax->output();
	$strain_tv->width(1200);

	# CGI parameters:
	# act = (NEW or SUBMIT or DISPLAY)
	# id  = (selected strain or new strain ID or old-strain)
	my $Strain = $cgi->param( 'id' );
	my $Action = $cgi->param( 'act' ) || 'DISPLAY';

	if($Action eq 'SUBMIT') {
		my $organism; 	# CGI == 'organism' the organism on which the strain is based
		my $oldID;		# CGI == 'old' the strain on which this one is built.
		my $ID;			# CGI == 'id'  the id of the new strain
		my $growth;		# CGI == 'growth' the growth data of the new strain
		my $ownership;	# CGI == 'owner' who owns the strain (and which table it will reside in)
		my $intervals;	# CGI == 'intervals' a | deliminated set of intervalIDs

		my $fail = 0;
		# Raise warnings and do not add if we didn't get all neccesary data.
		unless(defined($oldID = $cgi->param( 'old' ))) {
			$application->add_message('warning', "Invalid parent strain selected.");
			$fail = 1;
		}
		unless(defined($ID = $cgi->param( 'id' )) && length($ID) > 0) {
			$application->add_message('warning', "Invalid strain ID.");
			$fail = 1;
		}
		#unless(defined($ownership = $cgi->param( 'ownership' )) && length($ownership) > 0) {
		#	$application->add_message('warning', "No strain owner selected.");
		#	$fail = 1;
		#}
		unless(defined($intervals = $cgi->param( 'intervals' )) && length($intervals) > 0) {
			$application->add_message('warning', "No additional intervals added; remember to
				select some intervals.");
			$fail = 1;
		}
		#unless(defined($organism = $cgi->param( 'organism' ))) {
		#	$application->add_message('warning', "Invalid base organism selected.");
		#	$fail = 1;
		#}
		my @IntervalArray = split(/\|/, $intervals);

		my $MediaArray = $self->GetArrayOfMedia();
		for(my $i = 0; $i < @{$MediaArray}; $i++) {
			my $MediaName = $MediaArray->[$i];
			my $param;
			if(defined($param = $cgi->param( $MediaName ))) {
				unless($i == 0) { $growth .= "|"; }
				$growth .= $MediaName . ":" . $param;
			}
		}
		print STDERR $growth;
		unless(defined($growth)) {
			$application->add_message('warning', "Invalid growth parameter.");
			$fail = 1;
		}

		# Lock table
		my $StrainTable = $model->LockDBTable("STRAIN TABLE");
		my $IntervalTable = $model->database()->GetDBTable("INTERVAL TABLE");
		my $testStrainID = undef;
		my $testIntervalID = undef;

		# Make sure ID hasn't already been used; raise error if it has.
		$testStrainID   = $StrainTable->get_rows_by_key($ID, "ID");
		$testIntervalID = $IntervalTable->get_rows_by_key($ID, "ID");
		unless(!defined($testStrainID) && !defined($testIntervalID)) {
			$application->add_message('warning', "Strain ID ".$ID.
				" already in use by an existing strain or interval.");
			$fail = 1;
		}

		# Build and add row unless we have failed.
		unless($fail) {
			my $row = { 'ID' =>	["$ID"], 'BASE' => ["$oldID"], 'INTERVALS' => \@IntervalArray,
				"GROWTH" => ["$growth"], 'OWNER' => ["ALL"], 'DATE' => [time()] };
			$StrainTable->add_row($row);
			$StrainTable->save();
			# Run KO simulation
			$model->UnlockDBTable("STRAIN TABLE");
			$model->SimulateIntervalKO([$ID],'iBsu1103',$MediaArray);
			$application->redirect('StrainSelect');
			$application->add_message('info', "Sucessfully added strain ".$ID.".", 5);
			$application->do_redirect();
		}

		# Raise error if we have failed.
		if($fail) {
			$model->UnlockDBTable("STRAIN TABLE");
			$application->redirect('StrainViewer');
			$application->add_message('warning', "Strain was not added.");
			$application->do_redirect();
		}
	} elsif ($Action eq 'NEW') {
		$html .= "<div><h2>Create New Strain</h2>";
		if(defined($Strain)) {
			$html .= "<p style='width: 800px;'> Select intervals to combine with strain "
				. $Strain . ".</p>";
		}

		$html .= "<div id='form' style='align-left: true;'>";
		$html .= "<form method='post' id='straincreateform' enctype='multipart/form-data'
					action='seedviewer.cgi'>";
		# Select Growth Phenotype
		$html .= "<table>
				<tr><th>New Strain Name</th><td>
				<input type='text' name='id' />
				</td></tr>";
		my $Media = $self->GetArrayOfMedia();
		my $growthhdr = "<tr><th>Media Name</th>";
		my $growthselect = "<tr><th>Observed Growth</th>";
		foreach my $MediaName (@{$Media}) {
			$growthhdr 		.= "<td>$MediaName</td>";
			$growthselect 	.= "<td><select name='$MediaName'>
					<option value='-1'>Unknown</option>
					<option value='0'>No Growth</option>
					<option value='0.1'>Very Slow</option>
					<option value='0.4'>Slow</option>
					<option value='1'>Normal</option>
					<option value='1.1'>Fast</option>
					</select></td>";
		}
		$growthhdr .= "</tr>";
		$growthselect .= "</tr>";
		$html .= $growthhdr . $growthselect;
		my $StrainTable = $model->database()->GetDBTable('STRAIN TABLE');
		my $row = $StrainTable->get_row_by_key($Strain, 'ID');
		my @selected_intervals;
		my $selected_intervalSTR = '';
		if(defined($row)) {
			@selected_intervals = @{$row->{'INTERVALS'}};
			foreach my $k (@selected_intervals) {
				$selected_intervalSTR .= '<span style="padding-right: 4px;">'.
					'<a href="seedviewer.cgi?page=IntervalViewer&id='.$k.'">'.$k.'</a></span>';
			}
		}
		$html .= "<tr><th>Selected Intervals</th><td><div id='SelectedIntervalList'>".
					$selected_intervalSTR."</div></td></tr>";
		# Select Public / Private ownership
		#$html .= "<tr><th>Ownership</th><td>
		#		<input type='radio' name='ownership' value='public' /> public </td>
		#		<td stype='padding-right: 10px;'>
		#		<input type='radio' name='ownership' value='private' /> private </td>
		#		</tr>";
		$html .= "</table>";
		$html .= "<input type='hidden' name='page' value='StrainViewer' />
				  <input type='hidden' name='act' value='SUBMIT' />
				  <input type='hidden' name='old' value='$Strain' />
				  <input type='hidden' name='intervals' id='intervals' />";
		$html .= "<br><input type='button' value='SUBMIT' onClick='javascript: SubmitStrain();' />
				  </form>";
		$html .= $self->Make_interval_select_table($model, $interval_select_table, $Strain);
		$html .= $application->page->end_form();
		$html .= "</div></div>";
		return $html;
	} else {
		# getting the strain data
		my $StrainTable = $model->database()->GetDBTable("STRAIN TABLE");
		my $SimulationTable = $model->database()->GetDBTable("STRAIN SIMULATIONS");
		my $IntervalTable = $model->database()->GetDBTable("INTERVAL TABLE");

		if(defined($Strain) and $Action eq 'DISPLAY') {
			my $row = $StrainTable->get_row_by_key($Strain, "ID");
			unless($row) {
				$application->add_message('warning', "No strain found with ID $Strain");
			    return $self->display_strain_select();
			}
			my $Intervals = $row->{'INTERVALS'};
			my $genomeSize = 4214814;
			my $geneCount  = 0;
			my $rxnCount = 0;
			foreach my $interval (@{$Intervals}) {
				my $intervalRow = $IntervalTable->get_row_by_key($interval, 'ID');
				unless(defined($intervalRow)) { next; }
				my $start = $intervalRow->{'START'}->[0];
				my $stop  = $intervalRow->{'END'}->[0];
				$genomeSize = $genomeSize - ($stop - $start);
				my $genes = $model->genes_of_interval($start,$stop,'224308.1');
				$geneCount += @{$genes};
			}
			my $growth_display = $application->component('growth_display');
			my $growthstr = $growth_display->output($Strain);

			# Existing strain selected, find strain, load, print data
			$html .= "<h2>Strain " . $Strain . "</h2>";
			$html .= "<div style='padding-left: 10px;'>";
			$html .= "<a href='seedviewer.cgi?page=StrainViewer&id=".$Strain.
				"&act=NEW' >Create new strain using this one</a><br/>";
			$html .= "<table>";
			$html .= "<tr><th>Strain Size / Genome Size</th><td>". ($genomeSize/1000) .
					' / 4214.814 Kbp</td></tr>';
			$html .= '<tr><th>Intervals</th><td>'.@{$Intervals}.'</td></tr>';
			$html .= '<tr><th>Genes knocked out</th><td>'.$geneCount.'</td></tr>';
		#	$html .= '<tr><th>Reactions knocked out</th><td>'.$rxnCount.'</td></tr>';
			$html .= "<tr><th>Growth</th><td>" . $growthstr . "</td></tr>";
			$html .= "</table>";
			$html .= "</div>";

			## STRAIN SELECT TAB ##
			$strain_tv->add_tab('Strain Lineage', '', ['strain_select_tab', "id=$Strain"]);

			## GENE INFO TAB ##
			$strain_tv->add_tab('Gene Information', '',
				['gene_table_tab', "models=iBsu1103,figstr|224308.1.$Strain"]);
				
			## REACTION INFO TAB ##
			$strain_tv->add_tab('Reaction Information', '',
				['reaction_table_tab', "models=iBsu1103,figstr|224308.1.$Strain"]);

			## INTERVAL TAB ##
			my $interval_string = join(',',@{$Intervals});
			$strain_tv->add_tab('Intervals knocked out', '',
				['output', "IDList=$interval_string", 'IntervalTable|interval_table'] );

			## PREDICTION TAB ##
			$strain_tv->add_tab('Predictions', '', ['prediction_tab', "id=$Strain"]);

			## DISCUSSION TAB ##
			#my $strain_discussion = $application->component('strain_discussion');
			#$strain_discussion->ajax($ajax);
			#$strain_discussion->title('Discussion');
			#$strain_discussion->width(900);
			#my $strain_discussion_id = "figstr|224308.1.".$Strain;
			#my $DiscussionTabText = $strain_discussion->output($strain_discussion_id);
			#$strain_tv->add_tab('Discussion', $DiscussionTabText);

			## NOW PRINT TABVIEW ##
			$strain_tv->default(3);
			$html .= $strain_tv->output();
			return $html;

		} elsif(!defined($Strain) and $Action eq 'DISPLAY') {
			return $self->display_strain_select();
  		}
	}
}

sub display_strain_select {
    my ($self) = @_;
    my $app = $self->application();
	my $interval_select_table   = $app->component('interval_select_table');
	my $strain_tree 			= $app->component('strain_tree');
	my $strain_table			= $app->component('strain_table');
	my $strain_header			= $app->component('strain_header');
	my $strain_tv				= $app->component('strain_tv');
    my $html = "<div style='min-width: 1280px; overflow: scroll;'>
        <h2>Knockout results for Bacillus Subtilis</h2>";
    $html .= "<div>".$strain_header->output()."</div>";
    $strain_tv->add_tab('Strain Lineage', $strain_tree->output());
    $strain_tv->add_tab('Strain Table', $strain_table->output(800));
    $html .= $strain_tv->output();
    return $html;
}
    

sub gene_table_tab {
	my ($self,$Strain) = @_;
	my $application = $self->application();
	my $cgi = $application->cgi();
	unless(defined($cgi->param('models'))) {
		return '';
	}
	my $gene_table = $application->component('gene_table');
	$gene_table->base_table->show_top_browse(0);
	return $gene_table->output();
}

sub reaction_table_tab {
	my ($self,$Strain) = @_;
	my $application = $self->application();
	my $cgi = $application->cgi();
	unless(defined($cgi->param('models'))) {
		return '';
	}
	my $rxn_table = $application->component('ko_rxn_table');
	$rxn_table->base_table->show_top_browse(0);
	return $rxn_table->output();
}

sub prediction_tab {
	my ($self) = @_;
	my $application = $self->application();
	my $cgi = $application->cgi();

	unless(defined($cgi->param('id'))) {
		return '';
	}

	my $Strain = $cgi->param('id');

	my $model = $application->data_handle('FIGMODEL');
	my $StrainTable = $model->database()->GetDBTable('STRAIN TABLE');
	my $SimulationTable = $model->database()->GetDBTable("STRAIN SIMULATIONS");
	my $IntervalTable = $model->database()->GetDBTable("INTERVAL TABLE");

	my $PredictionsTabText = "<p>Our simulations provide predictions on coessential
		reactions missing from the strain and offer additional media conditions that
		may support strain growth.</p>";
	my $sim = $SimulationTable->get_row_by_key($Strain, 'ID');
	my $rxnSubTabText;
	my $cpdSubTabText;
	my $prediction_tv = $application->component('prediction_tv');
	my $tableMark = 'XX';
	# rescue media compounds
	if(defined($sim->{'RESCUE_MEDIA'}) and $sim->{'RESCUE_MEDIA'}->[0] ne 'NONE') {
		my $cpd_table = $application->component('cpd_table');
		my $cpdIds;
		for( my $i = 0; $i < @{$sim->{'MEDIA'}}; $i++) {
			my $mediaName = $sim->{'MEDIA'}->[$i];
			my $data;
			for( my $j = 0; $j < @{$sim->{'RESCUE_MEDIA'}}; $j++) {
				my @cpds = split(',', $sim->{'RESCUE_MEDIA'}->[$j]);
				foreach my $cpd (@cpds) {
					$data->{$cpd} = $tableMark;
					$cpdIds->{$cpd} = $cpd;
				}
			}
			$cpd_table->add_column({ name => $mediaName, position => 1,
					sortable => '1', filter => '0', data => $data });
		}
		$cpdSubTabText = $cpd_table->output(join(',', keys %{$cpdIds}));
		$prediction_tv->add_tab('Rescue Media', $cpdSubTabText);
	}
	# coessential reactions
	if(defined($sim->{'COESSENTIAL_REACTIONS'})) {
		my $rxn_table = $application->component('rxn_table');
		my $rxnIds;
		$rxnIds->{'iBsu1103'} = 'iBsu1103';
		for( my $i = 0; $i < @{$sim->{'MEDIA'}}; $i++) {
			my $mediaName = $sim->{'MEDIA'}->[$i];
			my $data;
			for( my $j = 0; $j < @{$sim->{'COESSENTIAL_REACTIONS'}}; $j++) {
				my @rxns = split(',', $sim->{'COESSENTIAL_REACTIONS'}->[$j]);
				foreach my $rxn (@rxns) {
					unless(defined($rxnIds->{substr($rxn, 1)})) {
						$rxnIds->{substr($rxn, 1)} = substr($rxn, 1);
					}
					my $mark = substr($rxn, 0, 1);
					if( $mark eq '+' ) { $mark = '=>'; }
					elsif( $mark eq '-') { $mark = '<='; }
					$data->{substr($rxn, 1)} = $mark;
				}
			}
			$rxn_table->add_column({ name => $mediaName, position => 1, width => 10,
					sortable => '1', filter => '0', data => $data });
		}
		$rxnSubTabText = $rxn_table->output(900, join(',', keys %{$rxnIds}));
		$prediction_tv->add_tab('Coessential reactions', $rxnSubTabText);
	}
	$prediction_tv->width(900);
	$prediction_tv->height(400);
	$PredictionsTabText .= $prediction_tv->output();
	return $PredictionsTabText;
}

sub strain_select_tab {
	my ($self) = @_;
	my $application = $self->application();
	my $cgi = $application->cgi();
	my $strain_table = $application->component('strain_table');
	my $strain_tree  = $application->component('strain_tree');
	my $Strain = $cgi->param('id');
	my $output;
	$output = "<div style='float: left;'>". $strain_tree->output($Strain) . "</div>";
	$output .= "<div style='float: left;'>" . $strain_table->output(800) . "</div>";
	return $output;
}

sub Make_interval_select_table {
	my ($self, $model, $interval_select_table, $Strain) = @_;

	my $application = $self->application();
	my $cgi = $application->cgi();
    my $interval_select_growth = $application->component('interval_select_growth');
	my $OrderedIntervalArray;
	my $OrderedIntervalValues;
	my $IntervalModel = $model->database()->GetDBTable("INTERVAL TABLE");
	my $StrainModel = $model->database()->GetDBTable("STRAIN TABLE");
	my $IntervalRank = $model->database()->GetDBTable("INTERVAL RANK");

	my $ColumnArray;
	push(@{$ColumnArray}, { name => 'Select', filter => 0, sortable => 0,
		width => '5', operand => $cgi->param( 'IntervalSelect' ) || "" });
	push(@{$ColumnArray}, { name => 'Interval', filter => 0, sortable => 0,
		width => '10', operand => $cgi->param( 'filterIntervalID' ) || "" });
	push(@{$ColumnArray}, { name => 'Rank', filter => 0, sortable => 1,
		width => '5', operand => $cgi->param( 'filterIntervalRank' ) || "" });
	push(@{$ColumnArray}, { name => 'Length', filter => 0, sortable => 1,
		width => '10', operand => $cgi->param( 'filterLength' ) || "" });
	push(@{$ColumnArray}, { name => 'Start', filter => 0, sortable => 0,
		width => '10', operand => $cgi->param( 'filterStart' ) || "" });
	push(@{$ColumnArray}, { name => 'Stop', filter => 0, sortable => 0,
		width => '10', operand => $cgi->param( 'filterStop' ) || "" });
	push(@{$ColumnArray}, { name => 'Growth Data', filter => 0, sortable => 0,
		width => '10', operand => $cgi->param( 'filterGrowth' ) || "" });

	my $rowhash;
	my $tabledata;
	my $row = 0;
	my $i;

	my $StrainRow = $StrainModel->get_row_by_key($Strain, 'ID');
	my @StrainIntervals = @{$StrainRow->{'INTERVALS'}};
	for(my $j=0; $j < $IntervalModel->size(); $j++) {
		$rowhash = $IntervalModel->get_row($j);
		push(@{$OrderedIntervalArray}, $rowhash->{'ID'}->[0]);
		for ($i = 0; $i < @{$ColumnArray}; $i++) {
			my $x;
			my $y;
			my $column_name = $ColumnArray->[$i]->{'name'};
			if($column_name eq 'Select') {
				my $set = 0;
				for my $k (@StrainIntervals) {
					if($k == $rowhash->{'ID'}->[0]) {
						$tabledata->[$row]->[$i] = 'CHECKEDBOX:'.$row;
						push(@{$OrderedIntervalValues}, '1');
						$set = 1;
					}
				}
				unless($set) {
					$tabledata->[$row]->[$i] = 'CHECKBOX:'.$row;
					push(@{$OrderedIntervalValues}, '0');
				}
			} elsif ($column_name eq 'Interval') {
				if(defined($x = $rowhash->{'ID'})) {
					$y = join(',', @{$x});
					$tabledata->[$row]->[$i] = "<a href='seedviewer.cgi?page=IntervalViewer&id=".
						$y."' >".$y."</a>";
				} else { $tabledata->[$row]->[$i] = "" }
			} elsif ($column_name eq 'Rank') {
				if(defined($x = $IntervalRank->get_row_by_key($rowhash->{'ID'}->[0], 'Interval'))) {
					$tabledata->[$row]->[$i] = $x->{'Rank'}->[0];
				} else { $tabledata->[$row]->[$i] = ''; }
			} elsif ($column_name eq 'Start') {
				if(defined($x = $rowhash->{'START'})) {$tabledata->[$row]->[$i] = join(',',@{$x}) }
				else {$tabledata->[$row]->[$i] = ""}
			} elsif ($column_name eq 'Stop') {
				if(defined($x = $rowhash->{'END'})) {$tabledata->[$row]->[$i] = join(',',@{$x}) }
				else {$tabledata->[$row]->[$i] = ""}
			} elsif ($column_name eq 'Length') {
				if(defined($x = $rowhash->{'END'}) &&
				   defined($y = $rowhash->{'START'})) {
					$x = join(',', @{$x});
					$y = join(',', @{$y});
					$tabledata->[$row]->[$i] = abs($x-$y);
				} else {$tabledata->[$row]->[$i] = ""}
			} elsif ($column_name eq 'Growth Data') {
				if(defined($x =$rowhash->{'GROWTH'})) {
					$tabledata->[$row]->[$i] .= $interval_select_growth->output($rowhash->{'ID'}->[0]);
				 } else {$tabledata->[$row]->[$i] = ""}
			} else { $tabledata->[$row]->[$i] = "" }
		}
		$row++;
	}
	my $ordered_interval_ids = join(',', @{$OrderedIntervalArray});
    my $ordered_interval_values = join(',', @{$OrderedIntervalValues});
  	my $html = "<script type='text/javascript' src='Html/StrainSelectTable.js'></script>";
	$html .= "<input type='hidden' id='ordered_interval_ids'
					value='$ordered_interval_ids' />";
	$html .= "<input type='hidden' id='ordered_interval_values'
					value='$ordered_interval_values' />";
	$interval_select_table->columns($ColumnArray);
	$interval_select_table->items_per_page(50);
	$interval_select_table->show_select_items_per_page(1);
	$interval_select_table->show_top_browse(1);
	$interval_select_table->data($tabledata);
	$interval_select_table->width(800);
	$html .= $interval_select_table->output();
	return $html;
}


# Find all the existing Media names, return as an array.
sub GetArrayOfMedia {
	my ($self) = @_;
	my $application = $self->application();
	my $model = $application->data_handle('FIGMODEL');
	my $StrainTable = $model->database()->GetDBTable('STRAIN TABLE');
	my @MediaArray;
	my @StrainIDs = $StrainTable->get_hash_column_keys('ID');
	foreach my $ID (@StrainIDs) {
		my $StrainRow = $StrainTable->get_row_by_key($ID, 'ID');
		my $StrainGrowthArray = $StrainRow->{'GROWTH'};
		foreach my $StrainGrowth (@{$StrainGrowthArray}) {
				my @MediaName = split(/:/, $StrainGrowth);
				my $found = 0;
				if(@MediaName) {
					for(my $i = 0; $i < @MediaArray; $i++) {
						if($MediaArray[$i] eq $MediaName[0]) {
							$found = 1;
							last;
						}
					}
					if($found == 0) { push(@MediaArray, $MediaName[0]); }
				}
		}
	}
	return \@MediaArray;
}

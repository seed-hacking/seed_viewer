package SeedViewer::WebPage::ReactionViewer;
use base qw( WebPage );
use strict;
use warnings;

=pod
=head1 NAME
ReactionViewer
=head1 DESCRIPTION
An instance of a WebPage in the SEEDViewer which displays information about reactions in the SEED biochemistry database.
=head1 METHODS
=over 4
=item * B<init> ()
Initialise the page
=cut
sub init {
  my $self = shift;
  $self->title('Model SEED Reaction Viewer');
  $self->application->register_component('TabView', 'reactiontabs');
}

=item * B<output> ()
Returns the html output of the Reaction Viewer page.
=cut
sub output {
	my ($self) = @_;
	my $application = $self->application();
	my $cgi = $application->cgi();
	my $figmodel = $application->data_handle('FIGMODEL');
	my $database = $figmodel->database();
	my $width = 800;
	#Getting ID of selected reaction
	my $rxn = $cgi->param('reaction');
	if (!defined($rxn)) {
		return "<span style=\"color:red;\">No reaction ID supplied. Reaction ID must be supplied</span>";
	}
	my $id = $rxn;
	if ($id !~ m/[br][ix][on]\d+/) {
		return "<span style=\"color:red;\">Reaction ".$id." not found in database!</span>";	
	}
	#Getting the model list
	my $modelList;
	my $modelString = "";
	my $SelectedModel = "NONE";
	if (defined($cgi->param('model'))) {
		my @tempList = split(/,/,$cgi->param('model'));
		$SelectedModel = $tempList[0];
		for (my $i=0; $i < @tempList; $i++) {
			if (length($modelString) > 0) {
				$modelString .= ",";
			}
			$modelString .= $tempList[$i];
			push(@{$modelList},$tempList[$i]);
		}
	}
	#Loading reaction data from database
	my $prefix;
	my $data;
	my $type = "rxn";
	if ($id =~ m/rxn\d+/) {
		$data = $figmodel->database()->get_object("reaction",{id => $id});
	} elsif ($id =~ m/bio\d+/) {
		$type = "bof";
		$data = $figmodel->database()->get_object("bof",{id => $id});
	}
	if (!defined($data)) {
		my $mdl;
		if ($SelectedModel ne "NONE") {
			$prefix = $SelectedModel;
			$mdl = $figmodel->get_model($SelectedModel);
		}
		if (defined($mdl)) {
			$data = $mdl->figmodel()->database()->get_object("reaction",{id => $id});
			$database = $mdl->figmodel()->database();
		}	
	}
	my $cpdHash;
	my $cpdObjs = $database->get_objects("compound");
	for (my $i=0; $i < @{$cpdObjs}; $i++) {
		$cpdHash->{$cpdObjs->[$i]->id()} = $cpdObjs->[$i];
	}
	if (!defined($data)) {
		return "<span style=\"color:red;\">Reaction ".$id." not found in database!</span>";	
	}
	if (defined($prefix)) {
		$id = $prefix.".".$data->id();
	}
	my $aliases = $database->get_objects("rxnals",{REACTION => $data->id()});
	my $aliashash;
	my $namelist;
	for (my $i=0; $i < @{$aliases}; $i++) {
		if ($aliases->[$i]->type() eq "name") {
			push(@{$namelist},$aliases->[$i]->alias());
		} elsif ($aliases->[$i]->type() ne "searchname") {
			push(@{$aliashash->{$aliases->[$i]->type()}},$aliases->[$i]->alias());
		}
	}
	#Creating the main table holding most of the reaction data
	my $overview = "";
	$overview .= '<table bordercolor="CCCCCC" align="left" cellspacing="0" cellpadding="0" border="1" width="'.($width-40).'">'."\n";
	$overview .= "<tr><th width=\"190\">Model SEED ID</th><td>".$id."</td></tr>";
	if (defined($data->name()) && $data->name() ne "" && $data->name() ne $id) {
		$overview .= "<tr><th>Primary name</th><td>".$data->name()."</td></tr>";
	}
	if ($type eq "rxn" && defined($data->abbrev()) && $data->abbrev() ne "" && $data->abbrev() ne $id) {
		$overview .= "<tr><th>Short name</th><td>".$data->abbrev()."</td></tr>";
	}
	if (defined($namelist) && @{$namelist} > 0) {
		$overview .= "<tr><th>Reaction names</th><td>".join(";&nbsp; ",@{$namelist})."</td></tr>";
	}
	my $Equation = $data->equation();
	$_ = $Equation;
	my @OriginalArray = /(cpd\d\d\d\d\d)/g;
	my %VisitedLinks;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($VisitedLinks{$OriginalArray[$i]})) {
			$VisitedLinks{$OriginalArray[$i]} = 1;
			my $Link = $figmodel->web()->CpdLinks($OriginalArray[$i],"NAME");
			my $Find = $OriginalArray[$i];
			$Equation =~ s/$Find/$Link/g;
		}
	}
	$overview .= "<tr><th>Reaction equation</th><td>".$Equation."</td></tr>";
	if ($type eq "rxn") {
		if (defined($data->enzyme()) && $data->enzyme() ne "" && $data->enzyme() ne "10000000") {
			my $enzymes = $data->enzyme();
			if ($enzymes =~ m/^\|(.+)\|$/) {
				$enzymes = $1;
			}
			my $enzymeList = [split(/\|/,$enzymes)];
			if (defined($enzymeList) && @{$enzymeList} > 0) {
				$overview .= "<tr><th>EC numbers</th><td>".$figmodel->ParseForLinks(join(",&nbsp; ",@{$enzymeList}),$modelString,"IDONLY")."</td></tr>";
			}
		}
		my $roles = $figmodel->web()->display_reaction_roles($id);
		if (length($roles) > 0 && lc($roles) ne "none") {
			$overview .= "<tr><th>Functional roles</th><td>".$roles."</td></tr>";
		}
		my $subsystems = $figmodel->web()->display_reaction_subsystems($id);
		if (length($subsystems) > 0 && lc($subsystems) ne "none") {
			$subsystems =~ s/_/ /g;
			$overview .= "<tr><th>Subsystems</th><td>".$subsystems."</td></tr>";
		}
		my $mapHash = $figmodel->get_map_hash({data => $id, type => "reaction"});
		if (defined($mapHash->{$id})) {
			my $list;
			foreach my $diagram (keys(%{$mapHash->{$id}})) {
				push(@{$list},$mapHash->{$id}->{$diagram}->name());
			}
			$overview .= "<tr><th>KEGG maps</th><td>".join(";<br>",@{$list})."</td></tr>";
		}
		if (defined($data->deltaG()) && $data->deltaG() ne "" && $data->deltaG() ne "10000000") {
			$overview .= "<tr><th>Thermodynamic reversibility</th><td>".$data->reversibility()."</td></tr>";
			$overview .= "<tr><th>Estimated energy of reaction (pH 7)</th><td>".$data->deltaG()." +/- ".$data->deltaGErr()." kcal/mol</td></tr>";
		}
	}
	if (defined($modelList)) {
		for (my $i=0; $i < @{$modelList}; $i++) {
			my $mdl = $figmodel->get_model($modelList->[$i]);
			my $modelrxn = $mdl->get_reaction_data($id);
			if (!defined($modelrxn)) {
				$overview .= '<tr><th>Status in '.$modelList->[$i]."</th><td>Reaction not found in model</td></tr>\n";
			} else {
				if (defined($modelrxn->{"ASSOCIATED PEG"})) {
					$overview .= '<tr><th>Associated gene in '.$modelList->[$i]."</th><td>".$figmodel->ParseForLinks(join("<br>",@{$modelrxn->{"ASSOCIATED PEG"}}),$modelList->[$i])."</td></tr>\n";
				}
			}
		}
	}
	$overview .= "</table>\n";
	#Creating table of database links
	my $dblinks = "";
	$dblinks .= '<table bordercolor="CCCCCC" align="left" cellspacing="0" cellpadding="0" border="1" width="'.($width-40).'">';
	$dblinks .= '<tr><th width="190">Database</th><th>ID</th></tr>';
	foreach my $type (keys(%{$aliashash})) {
		$dblinks .= "<tr><th>".$type."</th><td>".$figmodel->ParseForLinks(join("<br>",@{$aliashash->{$type}}))."</td></tr>";
	}
	$dblinks .= "</table>";
	#Creating table with reactants and products displayed
	my $rxnequation = "";
	my ($Reactants,$Products) = $figmodel->get_reaction()->substrates_from_equation({equation => $data->equation()});	
	$rxnequation .= "<table><tr><th>Reactants of reaction ".$id."</th></tr>\n";
	$rxnequation .= '<tr><td><div style="width:100%;overflow:scroll;clear:right;"><table align="left" cellspacing="0" cellpadding="0" border="1">'."\n";
	$rxnequation .= '<table align="left" cellspacing="0" cellpadding="0" border="1">'."\n";
	#Printing the compound ID and coefficient
	$rxnequation .= "<tr>";
	for (my $i=0; $i < @{$Reactants}; $i++) {
		$rxnequation .= "<td>(".$Reactants->[$i]->{"COEFFICIENT"}->[0].") ".$figmodel->web()->CpdLinks($Reactants->[$i]->{"DATABASE"}->[0],"ID").$Reactants->[$i]->{"COMPARTMENT"}->[0]."</td>";
	}
	#Printing the compound names
	$rxnequation .= "</tr><tr>";
	for (my $i=0; $i < @{$Reactants}; $i++) {
		if (defined($cpdHash->{$Reactants->[$i]->{"DATABASE"}->[0]})) {
			$rxnequation .= "<td>".$cpdHash->{$Reactants->[$i]->{"DATABASE"}->[0]}->name()."</td>";
		}
	}
	#Printing the compound formula
	$rxnequation .= "</tr><tr>";
	for (my $i=0; $i < @{$Reactants}; $i++) {
		if (defined($cpdHash->{$Reactants->[$i]->{"DATABASE"}->[0]})) {
			$rxnequation .= "<td>".$cpdHash->{$Reactants->[$i]->{"DATABASE"}->[0]}->formula()."</td>";
		}
	}
	#Printing the compound charge
	$rxnequation .= "</tr><tr>";
	for (my $i=0; $i < @{$Reactants}; $i++) {
		if (defined($cpdHash->{$Reactants->[$i]->{"DATABASE"}->[0]})) {
			$rxnequation .= "<td>pH 7 charge: ".$cpdHash->{$Reactants->[$i]->{"DATABASE"}->[0]}->charge()."</td>";
		}
	}
	#Printing the compound image
	$rxnequation .= "</tr><tr>";
	for (my $i=0; $i < @{$Reactants}; $i++) {
		$rxnequation .= '<td><a href="'.$figmodel->config("jpeg web directory")->[0].$Reactants->[$i]->{"DATABASE"}->[0].'.jpeg"><img name=img0 src="'.$figmodel->config("jpeg web directory")->[0].$Reactants->[$i]->{"DATABASE"}->[0].'.jpeg" border=0></a></td>';
	}
	$rxnequation .= '</tr></table></div></td></tr>'."\n";
	$rxnequation .= "<tr><th>Products of reaction ".$id."</th></tr>\n";
	$rxnequation .= '<tr><td><div style="width:100%;overflow:scroll;clear:right;"><table align="left" cellspacing="0" cellpadding="0" border="1">'."\n";
	#Printing the compound ID and coefficient
	$rxnequation .= "<tr>";
	for (my $i=0; $i < @{$Products}; $i++) {
		$rxnequation .= "<td>(".$Products->[$i]->{"COEFFICIENT"}->[0].") ".$figmodel->web()->CpdLinks($Products->[$i]->{"DATABASE"}->[0],"ID").$Products->[$i]->{"COMPARTMENT"}->[0]."</td>";
	}
	#Printing the compound names
	$rxnequation .= "</tr><tr>";
	for (my $i=0; $i < @{$Products}; $i++) {
		if (defined($cpdHash->{$Products->[$i]->{"DATABASE"}->[0]})) {
			$rxnequation .= "<td>".$cpdHash->{$Products->[$i]->{"DATABASE"}->[0]}->name()."</td>";
		}
	}
	#Printing the compound formula
	$rxnequation .= "</tr><tr>";
	for (my $i=0; $i < @{$Products}; $i++) {
		if (defined($cpdHash->{$Products->[$i]->{"DATABASE"}->[0]})) {
			$rxnequation .= "<td>".$cpdHash->{$Products->[$i]->{"DATABASE"}->[0]}->formula()."</td>";
		}
	}
	#Printing the compound charge
	$rxnequation .= "</tr><tr>";
	for (my $i=0; $i < @{$Products}; $i++) {
		if (defined($cpdHash->{$Products->[$i]->{"DATABASE"}->[0]})) {
			$rxnequation .= "<td>pH 7 charge: ".$cpdHash->{$Products->[$i]->{"DATABASE"}->[0]}->charge()."</td>";
		}
	}
	#Printing the compound image
	$rxnequation .= "</tr><tr>";
	for (my $i=0; $i < @{$Products}; $i++) {
		$rxnequation .= '<td><a href="'.$figmodel->config("jpeg web directory")->[0].$Products->[$i]->{"DATABASE"}->[0].'.jpeg"><img name=img0 src="'.$figmodel->config("jpeg web directory")->[0].$Products->[$i]->{"DATABASE"}->[0].'.jpeg" border=0></a></td>';
	}
	$rxnequation .= '</tr></table></div></td></tr>'."\n";
	$rxnequation .= '</table>'."\n";
	#Creating tab control
	my $tabletabs = $self->application()->component('reactiontabs');
    $tabletabs->add_tab( 'Reaction Overview',$overview);
    $tabletabs->add_tab( 'Database Links',$dblinks);
    $tabletabs->add_tab( 'Reaction Equation',$rxnequation);
    $tabletabs->width('100%');
    $tabletabs->default(0);
	return $tabletabs->output();
}

1;
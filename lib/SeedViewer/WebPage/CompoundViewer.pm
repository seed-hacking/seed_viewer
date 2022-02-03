package SeedViewer::WebPage::CompoundViewer;
use base qw( WebPage );
use strict;
use warnings;

=pod
=head1 NAME
ReactionViewer
=head1 DESCRIPTION
An instance of a WebPage in the SEEDViewer which displays information about compounds in the SEED biochemistry database.
=head1 METHODS
=over 4
=item * B<init> ()
Initialise the page
=cut

sub init {
  my $self = shift;
  $self->title('Model SEED Compound Viewer');
  $self->application->register_component('ReactionTable', 'CompoundReactionTable');
  $self->application->register_component('TabView', 'compoundtabs');
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
	my $cpd = $cgi->param('compound');
	if (!defined($cpd)) {
		return "<span style=\"color:red;\">No compound ID supplied. Compound ID must be supplied.</span>";
	}
	my $id = $cpd;
	if ($id !~ m/cpd\d\d\d\d\d/) {
		my $cpdObj;
		my @searchNames = $figmodel->convert_to_search_name($cpd);
		for (my $i=0; $i < @searchNames; $i++) {
			$cpdObj = $figmodel->database()->get_object("cpdals",{alias => $searchNames[$i],type => "searchname"});
			if (defined($cpdObj)) {
				last;	
			}
		}
		if (!defined($cpdObj)) {
			$cpdObj = $figmodel->database()->get_object("cpdals",{alias => $cpd});
		}
		if (!defined($cpdObj)) {
			return "<span style=\"color:red;\">Specified compound could not be found in database!</span>";
		}
		$id = $cpdObj->COMPOUND();
	}
	my $modelList;
	my $SelectedModel = "NONE";
	if (defined($cgi->param('model')) && $cgi->param('model') !~ m/none/i) {
		push(@{$modelList},split(/,/,$cgi->param('model')));
		$SelectedModel = $modelList->[0];
	}
	my $prefix;
	my $compoundData = $figmodel->database()->get_object("compound",{id => $id});
	if (!defined($compoundData)) {
		my $mdl;
		if ($SelectedModel ne "NONE") {
			$prefix = $SelectedModel;
			$mdl = $figmodel->get_model($SelectedModel);
		}
		if (defined($mdl)) {
			$compoundData = $mdl->figmodel()->database()->get_object("compound",{id => $id});
			$database = $mdl->figmodel()->database();
		}	
	}
	if (!defined($compoundData)) {
		return "<span style=\"color:red;\">Specified compound could not be found in database!</span>";
	}
	my $id = $compoundData->id();
	if (defined($prefix)) {
		$id = $prefix.".".$compoundData->id();
	}
	my $aliases = $database->get_objects("cpdals",{COMPOUND => $compoundData->id()});
	my $aliashash;
	my $namelist;
	for (my $i=0; $i < @{$aliases}; $i++) {
		if ($aliases->[$i]->type() eq "name") {
			push(@{$namelist},$aliases->[$i]->alias());
		} elsif ($aliases->[$i]->type() ne "searchname") {
			push(@{$aliashash->{$aliases->[$i]->type()}},$aliases->[$i]->alias());
		}
	}
	#Starting the main table holding most of the compound data
	my $overview = "";
	$overview .= '<table bordercolor="CCCCCC" align="left" cellspacing="0" cellpadding="0" border="1" width="'.($width-40).'">'."\n";
	$overview .= "<tr><th width=\"190\">Model SEED ID</th><td>".$id."</td></tr>";
	$overview .= "<tr><th>Primary name</th><td>".$compoundData->name()."</td></tr>";
	$overview .= "<tr><th>Short name</th><td>".$compoundData->abbrev()."</td></tr>";
	if (defined($namelist) && @{$namelist} > 0) {
		$overview .= "<tr><th>Compound names</th><td>".join(";&nbsp; ",@{$namelist})."</td></tr>";
	}
	if (defined($compoundData->mass()) && $compoundData->mass() ne "" && $compoundData->mass() ne "0" && $compoundData->mass() ne "10000000") {
		$overview .= "<tr><th>Molecular weight (pH 7)</th><td>".$compoundData->mass()."</td></tr>";
	}
	if (defined($compoundData->charge()) && $compoundData->charge() ne "" && $compoundData->charge() ne "10000000") {
		$overview .= "<tr><th>pH 7 charge</th><td>".$compoundData->charge()."</td></tr>";
	}
	if (defined($compoundData->deltaG()) && $compoundData->deltaG() ne "" && $compoundData->deltaG() ne "10000000") {
		$overview .= "<tr><th>Estimated formation energy (pH 7)</th><td>".$compoundData->deltaG()." +/- ".$compoundData->deltaGErr()." kcal/mol</td></tr>";
	}
	if (defined($compoundData->pKa()) && $compoundData->pKa() ne "" && $compoundData->pKa() ne "10000000") {
		my $pkas = [split(/;/,$compoundData->pKa())];
		my $pklist;
		for (my $i=0; $i < @{$pkas}; $i++) {
			my $temparray = [split(/\:/,$pkas->[$i])];
			push(@{$pklist},$temparray->[0]);
		}
		$overview .= "<tr><th>Estimated pKa</th><td>".join(",&nbsp; ",@{$pklist})."</td></tr>";
	}
	if (defined($compoundData->pKb()) && $compoundData->pKb() ne "" && $compoundData->pKb() ne "10000000") {
		my $pkbs = [split(/;/,$compoundData->pKb())];
		my $pklist;
		for (my $i=0; $i < @{$pkbs}; $i++) {
			my $temparray = [split(/\:/,$pkbs->[$i])];
			push(@{$pklist},$temparray->[0]);
		}
		$overview .= "<tr><th>Estimated pKb</th><td>".join(",&nbsp; ",@{$pklist})."</td></tr>";
	}
	#Printing the row with the compound structure data
	if (-e $figmodel->config("jpeg absolute directory")->[0].$id.".jpeg") {
		$overview .= '<tr><th>Molecular structur (pH 7)</th><td><a href="'.$figmodel->config("jpeg web directory")->[0].$id.'.jpeg"><img name=img0 src="'.$figmodel->{"jpeg web directory"}->[0].$id.'.jpeg" border=0></a></td></tr>';
	}
	$overview .= "</table>\n";
	#Creating table of database links to reaction
	my $dblinks = "";
	$dblinks .= '<table bordercolor="CCCCCC" align="left" cellspacing="0" cellpadding="0" border="1" width="'.($width-40).'">';
	$dblinks .= '<tr><th width="190">Database</th><th>ID</th></tr>';
	foreach my $type (keys(%{$aliashash})) {
		$dblinks .= "<tr><th>".$type."</th><td>".$figmodel->ParseForLinks(join("<br>",@{$aliashash->{$type}}))."</td></tr>";
	}
	$dblinks .= "</table>";
	#Creating table of reactions involving compound
	my $rxnObjs = $figmodel->database()->get_objects("cpdrxn",{COMPOUND => $id}); 
	my $ReactionIDList;
	for (my $i=0; $i < @{$rxnObjs}; $i++) {
		push(@{$ReactionIDList},$rxnObjs->[$i]->REACTION());
	}
	my $reaction_table = $application->component('CompoundReactionTable');
	my $reactionstable = $reaction_table->output(($width-20),$ReactionIDList);
	#Creating tab control
	my $tabletabs = $self->application()->component('compoundtabs');
    $tabletabs->add_tab( 'Compound Overview',$overview);
    $tabletabs->add_tab( 'Database Links',$dblinks);
    $tabletabs->add_tab( 'Reactions involving compound',$reactionstable);
    $tabletabs->width('100%');
    $tabletabs->default(0);
	return $tabletabs->output();
}

1;
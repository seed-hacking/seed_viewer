package SeedViewer::WebPage::ModelSelect;

use base qw( WebPage );

1;

use strict;
use warnings;

use FIG;
use FIGV;

=pod

#TITLE OrganismSelectPagePm

=head1 NAME

OrganismSelect - an instance of WebPage which lets the user select an organism

=head1 DESCRIPTION

Display an organism select box

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('Organism Selection');
  $self->application->register_component('ModelTable', 'ModelListTable');

  return 1;
}

=item * B<output> ()

Returns the html output of the OrganismSelect page.

=cut

sub output {
  my ($self) = @_;

  # fetch application, cgi and fig
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $fig = $application->data_handle('FIG');

  #Getting the list of currently selected models
  my $SelectedModels = $cgi->param('model');
  my $PrimaryModel = "Complete database";
  my $CompareModel;
  if (defined($SelectedModels) && length($SelectedModels) > 0) {
    my @ModelList = split(/,/,$SelectedModels);
    if ($model->model_is_valid($ModelList[0])) {
      $PrimaryModel = $ModelList[0];
    }
    foreach $SingleModel (@ModelList) {
      if ($model->model_is_valid($SingleModel) == 1) {
        push(@{$CompareModel},$SingleModel);
      }
    }
  }
  $SelectedModels = $PrimaryModel.",".join(",",@{$CompareModel});

  #Adding category to the menu
  my $menu = $application->menu();
  $menu->add_category('&raquo;Models');
  $menu->add_entry('&raquo;Models', 'Select model', '?page=ModelSelect&model='.$SelectedModels);
  $menu->add_entry('&raquo;Models', 'Model maps', '?page=ModelKEGG&model='.$SelectedModels);
  $menu->add_entry('&raquo;Models', 'Model reactions', '?page=ReactionViewer&model='.$SelectedModels);
  $menu->add_entry('&raquo;Models', 'Model compounds', '?page=CompoundViewer&model='.$SelectedModels);

  #Creating model object which is almost certain to be necessary
  my $model = new FIGMODEL->new();

  #Loading the model table
  my $select_table = $application->component('ModelListTable');

  #Printing scripts
  $html = '<script type="text/javascript"><!--'."\n";
    $html .= 'function SubmitForm(Page) {'."\n";
      $html .= "document.getElementById('page').value = Page;\n";
      $html .= 'modelselect.submit();'."\n";
    $html .= "}\n";
    $html .= 'function RemoveCompareReaction() {'."\n";
      $html .= 'var NewCompare = "";'."\n";
      $html .= 'var SelectedCompare = document.getElementById("compareselect").value;'."\n";
      $html .= 'var CurrentCompare = document.getElementById("compare").value;'."\n";
      $html .= 'var CurrentCompares = new Array();'."\n";
      $html .= 'CurrentCompares = CurrentCompare.split(/,/);'."\n";
      $html .= 'for (n=0;n<CurrentCompares.length;n++) {'."\n";
        $html .= 'if (CurrentCompares[n] != SelectedCompare) {'."\n";
          $html .= 'if (NewCompare.length > 0) {'."\n";
            $html .= 'NewCompare = NewCompare + ",";'."\n";
          $html .= '}'."\n";
          $html .= 'NewCompare = NewCompare + CurrentCompares[n];'."\n";
          $html .= 'document.getElementById("compareselect").remove(n);'."\n";
        $html .= '}'."\n";
      $html .= '}'."\n";
      $html .= 'document.getElementById("compare").value = NewCompare;'."\n";
      $html .= 'if (NewCompare == "") {'."\n";
        $html .= 'document.getElementById("removecomparebutton").disabled=true;'."\n";
      $html .= '}'."\n";
    $html .= '}'."\n";
    $html .= 'function ChangeCompare() {'."\n";
      $html .= "document.getElementById('removecomparebutton').disabled=false;\n";
    $html .= '}'."\n";
    $html .= 'function SelectPrimary() {'."\n";
      $html .= "document.getElementById('model').value = document.getElementById('model').value;\n";
    $html .= '}'."\n";
    $html .= 'function SelectCompare(CurrentSelect) {'."\n";
      $html .= 'var CurrentCompare = document.getElementById("compare").value;'."\n";
      $html .= 'if (CurrentCompare == "NONE") {'."\n";
        $html .= 'CurrentCompare = "";'."\n";
      $html .= '}'."\n";
      $html .= 'if (CurrentCompare != "") {'."\n";
        $html .= 'var CurrentCompares = new Array();'."\n";
        $html .= 'CurrentCompares = CurrentCompare.split(/,/);'."\n";
        $html .= 'if (CurrentCompares.length == 4) {'."\n";
          $html .= 'return;'."\n";
        $html .= '}'."\n";
        $html .= 'for (n=0;n<CurrentCompares.length;n++) {'."\n";
          $html .= 'if (CurrentCompares[n] == CurrentSelect) {'."\n";
            $html .= 'CurrentSelect = "";'."\n";
          $html .= '}'."\n";
        $html .= '}'."\n";
        $html .= 'if (CurrentSelect != "") {'."\n";
          $html .= 'CurrentCompare = CurrentCompare + "," + CurrentSelect;'."\n";
        $html .= '}'."\n";
      $html .= '} else {'."\n";
        $html .= 'CurrentCompare = CurrentSelect;'."\n";
      $html .= '}'."\n";
      $html .= 'document.getElementById("compare").value = CurrentCompare;'."\n";
      $html .= "document.getElementById('removecomparebutton').disabled=false;\n";
      $html .= 'var optn = document.createElement("OPTION");'."\n";
      $html .= 'optn.text = CurrentSelect;'."\n";
      $html .= 'optn.value = "";'."\n";
      $html .= 'document.getElementById("compareselect").options.add(optn);'."\n";
    $html .= '}'."\n";
  $html .= '</script>'."\n";

  #Printing out the page
  my $html = '<div style="width:1800px;"><table>'."\n";
  $html .= '<tr><th>Primary selected model/database</th></tr>';
  $html .= '<tr><td><span id="PrimaryModel">'.$PrimaryModel.'</span></td></tr>';
  $html .= '<tr><th>Models selected for comparison</th></tr>';
  $html .= '<tr><td><SELECT size="4" name="compareselect" id="compareselect" onchange="ChangeCompare();">';
  foreach $SingleModel (@ModelList) {
    $html .= '<OPTION value="Component_1_a">Component_1</OPTION>';
  }
  $html .= '</SELECT></td></tr>';
  $html .= '<tr><td><input type=button id="removecomparebutton" value="Remove compare model" disabled="true" onclick="RemoveCompareReaction();" style="width:220;cursor:pointer;"></td></tr>';
  $html .= '<tr><td><table><tr>';
  $html .= '<td><a style="text-decoration:none" onclick="SubmitForm('."'ModelKEGG'".');">View maps</a></td>';
  $html .= '<td><a style="text-decoration:none" onclick="SubmitForm('."'ReactionViewer'".');">View reactions</a></td>';
  $html .= '<td><a style="text-decoration:none" onclick="SubmitForm('."'CompoundViewer'".');">View compounds</a></td>';
  $html .= '</tr></table></tr>';
  $html .= '<tr><th>Current list of models in database</th></tr>';
  $html .= "<tr><td>".$select_table->output()."</td></tr>\n";
  $html .= "</table></div>\n";

  $html .= '<form name="modelselect" method="post" action="seedviewer.cgi">'."\n";
  $html .= '<input type="hidden" name="page" id="page" value="ModelSelect">'."\n";
  $html .= '<input type="hidden" name="model" id="model" value="'.$PrimaryModel.'">'."\n";
  $html .= '<input type="hidden" name="compare" id="compare" value="'.$CompareModel.'">'."\n";
  $html .= '</form>'."\n";
  
  return $html;


  # get the public genomes from the SEED
  my $genome_info = $fig->genome_info();
  my %genome_hash;
  
  # hash the attributes
  foreach my $genome (@$genome_info) {
    unless ($self->blacklist->{$genome->[0]}) {
      $genome_hash{$genome->[0]} = $genome->[1];
    }
  }
  
  #Get the model list
  my $Models = $model->GetListOfCurrentModels();
  
  #Assign organism names to each model
  my $ModelList;
  my $NumModels = 0;
  for (my $i=0; $i < @{$Models}; $i++) {
    #Checking if this is a published model in which its name and id will be the same
    my $OrganismName;
    if (defined($Models->[$i]->{"ORGANISM ID"}) && defined($Models->[$i]->{"MODEL ID"})) {
      if (defined($Models->[$i]->{"JOB ID"}) && $Models->[$i]->{"JOB ID"}->[0] =~ m/^\d+$/) {
        my $RastJobUser = FIGMODEL::LoadSingleColumnFile("/vol/rast-prod/jobs/".$Models->[$i]->{"JOB ID"}->[0]."/USER","");
        if ($user && ($RastJobUser->[0] eq $user->login() || $user->login() eq "chenry")) {
          my $OrganismName = FIGMODEL::LoadSingleColumnFile("/vol/rast-prod/jobs/".$Models->[$i]->{"JOB ID"}->[0]."/TAXONOMY","");
          if ($OrganismName->[0] =~ m/;\s([^;]+$)/) {
            $OrganismName->[0] = &RefineOrganismName($1);
            $ModelList->[$NumModels]->{"NAME"} = "Private ".$OrganismName->[0]." (".$Models->[$i]->{"ORGANISM ID"}->[0].")";
            $ModelList->[$NumModels]->{"ID"} = $Models->[$i]->{"MODEL ID"}->[0];
            $NumModels++;
          }
        }
      } elsif (defined($genome_hash{$Models->[$i]->{"ORGANISM ID"}->[0]})) {
        $OrganismName = &RefineOrganismName($genome_hash{$Models->[$i]->{"ORGANISM ID"}->[0]});
        if ($Models->[$i]->{"MODEL ID"}->[0] =~ /Core/) {
          $ModelList->[$NumModels]->{"NAME"} = "Core ".$OrganismName." (".$Models->[$i]->{"ORGANISM ID"}->[0].")";
	  $ModelList->[$NumModels]->{"ID"} = $Models->[$i]->{"MODEL ID"}->[0];
        } elsif ($Models->[$i]->{"MODEL ID"}->[0] =~ /Fit/) {
          $ModelList->[$NumModels]->{"NAME"} = "Fit ".$OrganismName." (".$Models->[$i]->{"ORGANISM ID"}->[0].")";
	  $ModelList->[$NumModels]->{"ID"} = $Models->[$i]->{"MODEL ID"}->[0];
        } else {
          $ModelList->[$NumModels]->{"NAME"} = $Models->[$i]->{"MODEL ID"}->[0].": ".$OrganismName." (".$Models->[$i]->{"ORGANISM ID"}->[0].")";
	  $ModelList->[$NumModels]->{"ID"} = $Models->[$i]->{"MODEL ID"}->[0];
        }
        $NumModels++;
      }
    }
  }
  
  # sort models alphabetically by name
  @$ModelList = sort { lc($a->{"NAME"}) cmp lc($b->{"NAME"}) } @$ModelList;
  
  #Populating the value and id arrays
  my $ModelIDs;
  my $ModelNames;
  push(@$ModelIDs,"NONE");
  push(@$ModelNames,"View entire database");
  for (my $i=0; $i < @{$ModelList}; $i++) {
    push(@$ModelIDs,$ModelList->[$i]->{"ID"});
    push(@$ModelNames,$ModelList->[$i]->{"NAME"});
  }
  
  # initialize select box
  my $select_box = $application->component('ModSelect'.$self->id);
  $select_box->name($self->name());
  $select_box->width(220);

  $select_box->multiple($self->multiple());
  
  # fill the select box
  $select_box->values($ModelIDs);
  $select_box->labels($ModelNames);
  $select_box->size(11);

  return $select_box->output();





  # create the select organism component
  my $organism_select_component = $application->component('OrganismSelect');
  $organism_select_component->width(500);

  # contruct introductory text
  my $html = "<h2>Select Organism</h2>";
  $html .= "<div style='text-align: justify; width: 800px;'>The SEED provides access to a large number public organisms. For each of these organisms, we provide a number of services:<ul style='list-style-type: disc;'><li>The first page you will see is the <b>General Information</b> page, where you will find some statistical information about the organism. Notice that from the menu <i>'Organism'</i> you will have access to multiple functions.</li><li>The <b>Genome Browser</b> will allow both tabular and graphical browsing of the genome.</li><li>You can access the <b>Scenarios</b>, which provide insight about the presence or absence of metabolic pathways.</li><li>You can <b>Compare Metabolic Reconstruction</b> of the chosen organism to another, e.g. to examine the differences in metabolism to a close relative.</li><li>Finally, you can <b>Export</b> our annotations in a format of your choice.</li></ul>Select from the list below to display the according organism page.</div>";

  if ($application->bot()) {
    
    my $genome_info = $fig->genome_info();
    foreach my $genome (@$genome_info) {
      $html .= "Detailed information about the $genome->[3] $genome->[1] ($genome->[0]) can be found on its organism overview page: <a href='".$application->url()."?page=Organism&organism=$genome->[0]'>$genome->[1]</a>. It has $genome->[2] basepairs, $genome->[4] protein encoding genes and belongs to the taxonomy line $genome->[7].<br>";
    }
  } else {

    # create select organism form
    $html .= $self->start_form( 'organism_select_form', { 'page' => 'Organism' } );
    $html .= $organism_select_component->output();
    $html .= "<br><input type=submit value='display'><br><br>";
    $html .= $self->end_form();
  }
  
  return $html;
}

sub supported_rights {
  return [ [ 'view', 'genome', '*' ] ];
}

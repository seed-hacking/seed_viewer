package SeedViewer::WebPage::DifferentialExpression;

use strict;
use warnings;
use POSIX;
use File::Basename;
use Data::Dumper;
use File::Copy;
use File::Temp;
use File::Path;
use Archive::Tar;
use FreezeThaw qw( freeze thaw );
use URI::Escape;
use File::Glob;

use FIG_Config;
use WebConfig;
use SAPserver;

use base qw( WebPage ); 1;


=pod

=head1 NAME

UploadMicroarray - upload a microarray 

=head1 DESCRIPTION

Upload page for microarray data.

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
    my $self = shift;
    $self->title("Run Differential Expression");
    my $app = $self->application();
    $app->register_component("Table", "MicroarrayTable");
    $app->register_component("Table", "upTable");
    $app->register_component("TabView", "resultsTv");
    $app->register_component('FilterSelect', 'genomeselect' );
    $app->register_component("FilterSelect", "upload_1_1");
    $app->register_component("FilterSelect", "upload_2_1");
    $app->register_component("Ajax", "ajax");
    $app->register_component("Table", "arTable");
    $app->register_component("Table", "ssTable");
    $self->require_javascript_ordered([
        "$FIG_Config::cgi_url/Html/jquery-1.3.2.min.js",
        "$FIG_Config::cgi_url/Html/DifferentialExpression.js",
        ]);
}


=item * B<output> ()

Returns the html output of the page.

=cut

sub output {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $self->application()->cgi();
    my $model = $app->data_handle("FIGMODEL");
    $self->{"errors"} = [];
    my $ajax = $app->component('ajax');
    my $html = $ajax->output(); 
    if (defined($cgi->param("upload_1_c")) && defined($cgi->param("upload_2_c"))) {
        $html .= $self->performFCA(); 
    } elsif (defined($cgi->param("genome_id"))) {
	    $html .= $self->displayUploadForm2();
    } else {
        $html .= $self->displayUploadForm1();
    }
    return $html;
}

sub genome_select_box {
    my ($self, $string) = @_;
    my $application = $self->application();
    my $filter = $application->component('genomeselect');
    $filter->width(500);
    $filter->size(10);
    $filter->dropdown(1);
    $filter->initial_text("type here to search available genomes");

    # Build the genome Id to name mapping
    my $sapObject = SAPserver->new();
    my $expressedGenomes = $sapObject->expressed_genomes();
    my $geneIds = $sapObject->genome_names({-ids => $expressedGenomes});
    my $labels = [];
    my $values = [];
    foreach my $id (sort { $geneIds->{$a} cmp $geneIds->{$b} } keys %{$geneIds} )
    {
	push(@{$labels},$geneIds->{$id}." (".$id.")");
    	push(@{$values},$id);
    }
    $filter->name("select_single_genome");
    $filter->labels($labels);
    $filter->values($values);
    my $html = "<table><tr>";
    my $buttonText = "Load Expression Samples for Genome";
    $html .= "<td>".$filter->output().'</td><td><input type="button" value="'.$buttonText.'" onClick="select_genome(\'select_single_genome\');"></td>';
    $html .= '</tr></table>';
    $html .= "<i>(Example search: 'bacillus', 'coli', '83333.1')</i>";
    return $html;
}

sub new_expression_set_box_ajax {
    my ($self) = @_;
    my $cgi = $self->application()->cgi();
    my $queryName = $cgi->param('queryName');
    my $genome = $cgi->param('genome');
    my $sapObject = SAPserver->new();
    my $expressionSamples = $sapObject->genome_experiments({ -ids=>[$genome] });
    return $self->expression_set_box('upload_2_1', $expressionSamples->{$genome}, $queryName);
}
    

sub expression_set_box {
    my ($self, $componentName, $expressionSamples, $queryName) = @_;
    my $application = $self->application();
    my $cgi = $application->cgi();
    my $filter = $application->component($componentName);
    $filter->width(500);
    $filter->size(10);
    $filter->dropdown(1);
    $filter->initial_text("type here to search expression samples");
    my $labels = [];
    my $values = [];
    foreach my $id (sort @{$expressionSamples})
    {
	my $name = $id =~ /(.*)\.CEL\.gz/i ? $1 : $id;
	push(@{$labels},$name);
    	push(@{$values},$id);
    }
    $queryName = $componentName if(not defined($queryName));
    $filter->html_id($queryName);
    $filter->name($queryName);
    $filter->labels($labels);
    $filter->values($values);
    return $filter->output();
}

sub displayUploadForm1 {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();
    my $content = <<TNETNOC;
    <div style='min-width: 1000px; width: 80%; margin: auto;'>
    <h3>Run Differential Expression</h3>
TNETNOC
    # create upload information form
    $content .= "<form id='UploadForm1' action='seedviewer.cgi' enctype='multipart/form-data' method='post'>".
                "<input type='hidden' name='page' value='DifferentialExpression'>";
    $content .= "<fieldset id='genome' ><legend>Select a Genome</legend><table><tr><td>";
    $content .= $self->genome_select_box;
    $content .= "</td></tr></table></fieldset>";
    my $genome_id = $cgi->param("genome_id");
    if (defined($genome_id)) {
    	$content  .= "  <input type='hidden' id='genome_id' name='genome_id' value='$genome_id'>\n";
    } else {
    	$content .= "  <input type='hidden' id='genome_id' name='genome_id' value=''>\n";
    }
    $content .= "  <input type='hidden' id='page' name='page' value='DifferentialExpression'>\n";
    $content .= "</form>\n";
    return $content;
}

sub displayUploadForm2 {
    my ($self) = @_;
    my $app = $self->application();
    my $sapObject = SAPserver->new();
    my $cgi = $app->cgi();
    my $genome_id = $cgi->param("genome_id");
    my $geneIds = $sapObject->genome_names({-ids => [$genome_id]});
    my $genome_name = $geneIds->{$genome_id};
    my $expressionSamples = $sapObject->genome_experiments({ -ids=>[$genome_id] });

    my $content = <<TNETNOC;
    <div style='min-width: 1000px; width: 80%; margin: auto;'>
    <h3>Run differential expression for 
TNETNOC
    $content .= $genome_name." (".$genome_id.")</h3>";
#    $content .= "<input id='genome_id' type='hidden' value='".$genome_id."'></input>";
    # create upload information form
    $content .= "<form id='UploadForm2' action='seedviewer.cgi' enctype='multipart/form-data' method='post'>".
                "<input type='hidden' name='page' value='DifferentialExpression'>";
    $content .= <<TNETNOC;
    <p>Select one or more expression samples for each replicate set</p>
<input id='rep1Count' type='hidden' name='upload_1_c' value='1'/>
<fieldset id='rep1' ><legend>Replicate Set 1</legend><table>
    <tr><td>Set Name:</td><td><input type='text' name='upload_1_n' value='Rep1'></td></tr>
    <tr><td>Expression Sample 1:</td><td>
TNETNOC
    $content .= $self->expression_set_box('upload_1_1', $expressionSamples->{$genome_id});
    $content .= <<TNETNOC;
</td></tr></table>
<input type='button' value='Add Another Expression Sample' onClick='addAnotherUpload(1, "$genome_id");'/>
</fieldset>
<input id='rep2Count' type='hidden' name='upload_2_c' value='1'/>
<fieldset id='rep2' ><legend>Replicate Set 2</legend><table>
    <tr><td>Set Name:</td><td><input type='text' name='upload_2_n' value='Rep2'></td></tr>
    <tr><td>Expression Sample 1:</td><td>
TNETNOC
    $content .= $self->expression_set_box('upload_2_1', $expressionSamples->{$genome_id});
    $content .= <<TNETNOC;
</td></tr></table>
<input type='button' value='Add Another Expression Sample' onClick='addAnotherUpload(2, "$genome_id");'/>
</fieldset>
TNETNOC
    $content  .= "  <input type='hidden' id='genome_id' name='genome_id' value='$genome_id'>\n";
    $content .= "<p><input type='submit' name='nextsetp' value='Run Analysis'></p></form></div>";
    return $content;
}

sub performFCA {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();

    my $rep1Name = $cgi->param("upload_1_n");
    my $rep2Name = $cgi->param("upload_2_n");

    my %samples_to_reps;
    my @upload_c = [""];
    $upload_c[1] = $cgi->param("upload_1_c");
    $upload_c[2] = $cgi->param("upload_2_c");
    unless(defined($upload_c[1]) && defined($upload_c[2])) {
        $self->addError("There was an error in the upload form (1)");
    }
    for(my $j=1; $j < @upload_c; $j++) {
        unless($upload_c[$j] >= 1) {
            $self->addError("You must have at least one expression sample per replicate set. (2.$j)");
            next;
        }
        for(my $i=1; $i <= $upload_c[$j]; $i++) {
            unless(defined($cgi->param("upload_$j"."_$i")) &&
                $cgi->param("upload_$j"."_$i") ne "") {
                $self->addError("You must provide a file for each of the " . $upload_c[$j] .
                    " supplied Expression Sample fields in Replicate Set $j (3.$j.$i)");
                last;
            }
        }
    }
    if (@{$self->{'errors'}} > 0) { 
        my $str = join('<br/>', @{$self->{'errors'}});
        if(@{$self->{'errors'}} > 1) {
            $app->add_message("warning", "There were errors in uploading your experiment:<br/>" . $str);
        } else {
            $app->add_message("warning", "There was an error in uploading your experiment:<br/>" . $str);
        }
        return $self->displayUploadForm2();
    }

    my @repSampleNames = (undef, [], []);
    my @expression_samples;
    for(my $j=1; $j < @upload_c; $j++) {
        for(my $i=1; $i <= $upload_c[$j]; $i++) {
            my $sample = $cgi->param("upload_$j"."_$i");
	    push @expression_samples, $sample;
	    $samples_to_reps{$sample} = $j;
	    my $s_name = $sample =~ /(.*)\.CEL\.gz/i ? $1 : $sample;
	    push @{$repSampleNames[$j]}, $s_name;
        }
    }

    my $genome_id = $cgi->param("genome_id");
    my $sapObject = SAPserver->new();
    my $dataHash = $sapObject->genome_experiment_levels({ -genome => $genome_id, -experiments => \@expression_samples});
    my $fca = {};
    foreach my $fid (keys %$dataHash) {
	my $rep1 = 0;
	my $rep2 = 0;
	foreach my $datum (@{$dataHash->{$fid}}) {
	    if (defined $samples_to_reps{$datum->[0]}) {
		if ($samples_to_reps{$datum->[0]} == 1) {
		    $rep1 += $datum->[2];
		}
		else {
		    $rep2 += $datum->[2];
		}
	    }
	    else {
		print STDERR "Unrecognized sample for $fid: ", $samples_to_reps{$datum->[0]}, "\n";
	    }
	}
	
	$rep1 = $rep1/(scalar @{$repSampleNames[1]});
	$rep2 = $rep2/(scalar @{$repSampleNames[2]});

	if ($rep1 == 0) {
	    print STDERR "Rep1 is zero for $fid, can't do upregulation\n";
	}
	else {
	    $fca->{$fid} = $rep2/$rep1;
	}
    }

    return $self->displayUtilityPage($rep1Name, $rep2Name, (join ", ", @{$repSampleNames[1]}), (join ", ", @{$repSampleNames[2]}), $fca);
}

sub displayUtilityPage {
    my ($self, $rep1Name, $rep2Name, $rep1SampleNames, $rep2SampleNames, $fca) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();
    my $genome_id = $cgi->param("genome_id");
    my $functionMap = $self->getPegFunctionHash($genome_id);
    my $atomicRegulonMap = $self->getAtomicRegulonMap($genome_id);
    my $ssMap = $self->getSubsystemsMap($genome_id);
    my %problems;

    # output for atomic regulon gene set analysis
    my $workingDir = File::Temp::tempdir();
    chmod 0770, $workingDir || return $self->raiseError("Unable to chmod a file: $@ (4)");
    my ($tmpValues, $tmpGS, $tmpGSnames);
    open ($tmpValues, ">$workingDir/gene_values.txt");
    open ($tmpGS, ">$workingDir/gene_sets.txt");
    open ($tmpGSnames, ">$workingDir/gene_set_names.txt");
    print STDERR "workingDir is $workingDir\n";

    # @fids_in_order is an array of fids sorted by increase in fold change
    my @fids_in_order = (sort { $fca->{$b} <=> $fca->{$a} } keys %{$fca});
    # %fids_in_order is a hash that keeps track of the index of each fid in @fids_in_order
    my %fids_in_order;
    my $i=0;
    map { $fids_in_order{$_} = ++$i } @fids_in_order;
    my $peg_to_ar = {};
    my %ar_length;

    # do two things at once
    foreach my $ar (keys %$atomicRegulonMap) {
	my (undef, $ar_name) = split ":", $ar;
	$ar_length{$ar_name} = scalar @{$atomicRegulonMap->{$ar}};
	# the next loop does two things: (1) fills in %$peg_to_ar; (2) collects the
	# indexes of each fid in the ar for the gene-set-analysis

	my @ordered;
	foreach my $fid (@{$atomicRegulonMap->{$ar}}) {
	    $peg_to_ar->{$fid} = $ar_name;
	    my $index = $fids_in_order{$fid};
	    if (defined $index) {
		push @ordered, $index;
	    }
	    else {
		push @{$problems{$fid}}, "Atomic Regulon: $ar_name;";
	    }
	}

	print $tmpGSnames $ar_name, "\n";
	my $ordered = join ",", @ordered;
	print $tmpGS $ordered, "\n";
    }

    # finishing up the first thing
    foreach my $fid (@fids_in_order) {
	print $tmpValues $fca->{$fid}, "\n";
    }

    close($tmpGSnames);
    close($tmpGS);
    close($tmpValues);

    # finishing up the second
    chdir($workingDir) || return $self->raiseError("Unable to chdir: $@ (7)");
    my $rc = system("$FIG_Config::bin/GeneSet_P_Values > out 2> err");
    $rc == 0 or $self->raiseError("Error running GeneSet_P_Values: rc=$rc");

    my $arArray = [];
    open (GSA, $workingDir."/gsa_output.txt") or die($!);
    while (<GSA>) {
	chomp;
	my @stuff = split " ";
	my $regulon = shift @stuff;
	@stuff  = map { sprintf("%.3f",$_) } @stuff;
	unshift @stuff, $ar_length{$regulon};
	unshift @stuff, "<a href=\"javascript:void(0)\"onclick=\"window.open(\'".$FIG_Config::cgi_url."/seedviewer.cgi?page=AtomicRegulon&regulon=".$regulon."&genome=".$genome_id."\')\">Atomic regulon ".$regulon."</a>"; 
	push(@$arArray, \@stuff);
    }

    close GSA;
    rename("$workingDir/gsa_output.txt", "$workingDir/gsa_output1.txt");

    # repeat for Subsystems - in the same working directory
    open ($tmpGS, ">$workingDir/gene_sets.txt");
    open ($tmpGSnames, ">$workingDir/gene_set_names.txt");

    my (%ss_length, %fid_to_ss);
    foreach my $ss (keys %$ssMap) {
	$ss_length{$ss} = scalar @{$ssMap->{$ss}};
	my @ordered;
	foreach my $fid (@{$ssMap->{$ss}}) {
	    push @{$fid_to_ss{$fid}}, $ss;
	    my $index = $fids_in_order{$fid};
	    if (defined $index) {
		push @ordered, $index;
	    }
	    else {
		push @{$problems{$fid}}, "Subsystem: $ss;";
	    }
	}
	unless (@ordered == 0) {
	    print $tmpGSnames $ss, "\n";
	    my $ordered = join ",", @ordered;
	    print $tmpGS $ordered, "\n";
	}
    }

    $rc = system("$FIG_Config::bin/GeneSet_P_Values > out 2> err");
    $rc == 0 or $self->raiseError("Error running GeneSet_P_Values: rc=$rc");

    my $ssArray = [];
    open (GSA, $workingDir."/gsa_output.txt") or die($!);
    while (<GSA>) {
	chomp;
	my @stuff = split "\t";
	my $ss = shift @stuff;
	@stuff  = map { sprintf("%.3f",$_) } @stuff;
	unshift @stuff, $ss_length{$ss};
	unshift @stuff, "<a href=\"javascript:void(0)\"onclick=\"window.open(\'".$FIG_Config::cgi_url."/seedviewer.cgi?page=Subsystems&subsystem=".$ss."&genome=".$genome_id."\')\">".$ss."</a>"; 
	push(@$ssArray, \@stuff);
    }

    my $upArray = [];
    $i = 0;
    foreach my $fid (@fids_in_order) {
        push(@$upArray, $self->processResultLine($genome_id, $fid, ++$i, $fca->{$fid}, $functionMap, \%fid_to_ss, $peg_to_ar));
    }

    my $num_fids = scalar @fids_in_order;
    my $upTable = $app->component("upTable");
    my $colDefU =  [ { name => "Feature" , sortable => 1, filter => 1},
                    { name => "Rank (out of $num_fids)" , sortable => 1,},
                    { name => "Ratio Rep2 to Rep1" , sortable => 1,},
                    { name => "Function", sortable => 1, filter => 1},
                    { name => "Subsystems", sortable => 1, filter => 1},
                    { name => "Atomic Regulon", sortable => 1, filter => 1},
                  ];
    $upTable->columns($colDefU);
    $upTable->data($upArray);
    $upTable->items_per_page(50);
    $upTable->show_top_browse(1);
    $upTable->show_bottom_browse(1);
    $upTable->show_export_button({"strip_html" => 1, "hide_invisible_columns" => 0});
    $upTable->show_select_items_per_page(0);
   
    my $arTable = $app->component("arTable");
    my $colDefAR =  [ { name => "Atomic Regulon" , sortable => 1, filter => 1},
		      { name => "AR Size", sortable => 1 },
		      { name => "Mean" , sortable => 1 },
		      { name => "Over Expressed p-value", sortable => 1 },
		      { name => "Under Expressed p-value", sortable => 1 },
                  ];
    $arTable->columns($colDefAR);
    $arTable->data($arArray);
    $arTable->items_per_page(50);
    $arTable->show_top_browse(1);
    $arTable->show_bottom_browse(1);
    $arTable->show_export_button({"strip_html" => 1, "hide_invisible_columns" => 0});
    $arTable->show_select_items_per_page(0);

    my $ssTable = $app->component("ssTable");
    my $colDefSS =  [ { name => "Subsystem" , sortable => 1, filter => 1},
		      { name => "Size", sortable => 1 },
		      { name => "Mean" , sortable => 1 },
		      { name => "Over Expressed p-value", sortable => 1 },
		      { name => "Under Expressed p-value", sortable => 1 },
                  ];
    $ssTable->columns($colDefSS);
    $ssTable->data($ssArray);
    $ssTable->items_per_page(50);
    $ssTable->show_top_browse(1);
    $ssTable->show_bottom_browse(1);
    $ssTable->show_export_button({"strip_html" => 1, "hide_invisible_columns" => 0});
    $ssTable->show_select_items_per_page(0);

    my $resultsTv = $app->component('resultsTv');
    $resultsTv->add_tab('Subsystems', $ssTable->output());
    $resultsTv->add_tab('Genome Features', $upTable->output());
    $resultsTv->add_tab('Atomic Regulons', $arTable->output());
    my $problemString = join "<br />", map { "No expression data for <a href=\"javascript:void(0)\"onclick=\"window.open(\'".$FIG_Config::cgi_url."/seedviewer.cgi?page=Annotation&feature=".$_."\')\">".$_."</a> in @{$problems{$_}}" } sort keys %problems;
    my $outStr = "<div style='min-width: 1000px; width: 80%; margin: auto;'>".
              "<h2>Results</h2><p>Using the following expression samples:<ol><li>$rep1Name".
              ": " .$rep1SampleNames . "</li><li>$rep2Name".": " . $rep2SampleNames ."</li></ol></p>".
              $resultsTv->output() . "</div>".
	      "<div style='min-width: 1000px; width: 80%; margin: auto;'>".
	      "<h2>Problems</h2><p>".$problemString."</div>";
    return $outStr;
}
            
sub toPegLink {
    my ($self, $objs) = @_;
    my $app = $self->application();
    for (my $i = 0; $i < @$objs; $i++) {
        next unless(defined($objs->[$i]->{'id'}));
        my $linkBlock = "<a href='seedviewer.cgi?page=Annotation&feature=".
            $objs->[$i]->{'id'}."' target='_blank'>REPLACE</a><br/>";
        my $finalLinks = "";
        if ( defined($objs->[$i]->{'mappings'})) {
            foreach my $key (sort { $a cmp $b } keys %{$objs->[$i]->{'mappings'}}) {
                my $newLink = $linkBlock;
                my $newLinkText = $key . " : " . $objs->[$i]->{'mappings'}->{$key};
                $newLink =~ s/REPLACE/$newLinkText/;
                $finalLinks .= $newLink;
            }
        } else {
            my $pegId = $objs->[$i]->{'id'};
            $linkBlock =~ s/REPLACE/$pegId/;
            $finalLinks .= $linkBlock;
        }
        $objs->[$i] = $finalLinks;
    }
    return $objs;
}

sub addError {
    my ($self, $errorMsg) = @_;
    push(@{$self->{'errors'}}, $errorMsg);
}

sub raiseError {
    my ($self, $errorMsg) = @_;
    $self->addError($errorMsg);
    my $finalMsg = join('</br>', @{$self->{'errors'}});
    my $app = $self->application();
    $app->add_message("warning", "There has been an unrecoverable error:<br/>".$finalMsg);
    return "";
}

sub raiseErrorResults {
    my ($self, $key, $errorMsg) = @_;
    $self->addError("Results from analysis script: ");
    my $workingDir = $self->{'path to working dirs'} . $key;
    if(-d $workingDir && -e $workingDir . "/err") {
        open(my $errFH, "<", $workingDir . "/err");
        while (<$errFH>) {
            chomp $_;
            $self->addError($_);
        }
        close($errFH);
    }
    return raiseError("");
}

sub processResultLine {
    my ($self, $genome_id, $peg, $rank, $fc, $featureHash, $fid_to_ss, $arMap) = @_;
    my @line = ("<a href=\"javascript:void(0)\"onclick=\"window.open(\'".$FIG_Config::cgi_url."/seedviewer.cgi?page=Annotation&feature=".$peg."\')\">".$peg."</a>", $rank, sprintf("%.3f",$fc));
    my $feature = $featureHash->{$peg};
    if (defined($feature)) {
	push (@line, $feature);
    }
    else {
	push (@line, "");
    }
    if (exists $fid_to_ss->{$peg}) {
	my $ss_line = join "<br />", map { "<a href=\"javascript:void(0)\"onclick=\"window.open(\'".$FIG_Config::cgi_url."/seedviewer.cgi?page=Subsystems&subsystem=".$_."&genome=".$genome_id."\')\">".$_."</a>" } @{$fid_to_ss->{$peg}};
	push @line, $ss_line;
    }
    else {
	push @line, "";
    }
    my $ar_name = $arMap->{$peg};
    if (defined($ar_name)) {
	push (@line, "<a href=\"javascript:void(0)\"onclick=\"window.open(\'".$FIG_Config::cgi_url."/seedviewer.cgi?page=AtomicRegulon&feature=".$peg."&regulon=".$ar_name."&genome=".$genome_id."\')\">Atomic regulon ".$ar_name."</a>");
    }
    return \@line;
}


sub getPegFunctionHash {
    my ($self, $genome) = @_;
    my $pegToFunctions = {};
    my $sap = SAPserver->new();
    my $result = $sap->all_features({ -ids => [$genome] });
    my $allPegs = $result->{$genome};
    $pegToFunctions = $sap->ids_to_functions({ -ids => $allPegs });
    return $pegToFunctions;
}

sub getAtomicRegulonMap {
    my ($self, $genome) = @_;
    my $sap = SAPserver->new();
    return $sap->atomic_regulons({ -id => $genome });
}

sub getSubsystemsMap {
    my ($self, $genome) = @_;
    my $sap = SAPserver->new();
    my $genome_to_subsystems = $sap->genomes_to_subsystems({ -ids => [$genome], -all => 1 });
    my @ss;
    foreach my $pair (@{$genome_to_subsystems->{$genome}}) {
	push @ss, $pair->[0] unless $pair->[1] =~ "-1";
    }
    return $sap->ids_in_subsystems({ -subsystems => \@ss, -genome => $genome, -roleForm => "none" });
}

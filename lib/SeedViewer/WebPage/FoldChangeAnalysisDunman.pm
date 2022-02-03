# fold change analysis tool for Paul Dunman

package SeedViewer::WebPage::FoldChangeAnalysisDunman;
$ENV{'SAS_SERVER'} = 'PSEED';

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
use FIGMODEL;
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
    $self->title("Run Fold Change Analysis");
    my $app = $self->application();
    $app->register_component("Table", "MicroarrayTable");
    $app->register_component("Table", "upTable");
    $app->register_component("Table", "downTable");
    $app->register_component("Table", "allTable");
    $app->register_component("TabView", "resultsTv");
    $app->register_component("FilterSelect", "media_fs");
    $app->register_component("FilterSelect", "experiment_fs");
}


=item * B<output> ()

Returns the html output of the page.

=cut

sub output {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $self->application()->cgi();
    my $model = $app->data_handle("FIGMODEL");
    $self->{"path to microarrayData"} = $model->{"database root directory"}->[0]."microarrayData/";
    $self->{"path to working dirs"} = $self->{"path to microarrayData"}."temp/";
    $self->{"errors"} = [];
    my $html; 
    if (defined($cgi->param("upload_1_c")) && defined($cgi->param("upload_2_c"))) {
        return $self->saveUpload(); 
    } elsif (defined($cgi->param("saved"))) {
        my $workingDir = $self->{'path to working dirs'} . $cgi->param("saved");
        if ( -d $workingDir ) {
            return $self->displayUtilityPage($cgi->param("saved"));
        } else {
            return $self->displayUploadForm();
        }
    } else {
        return $self->displayUploadForm();
    }
}

=item * B<displayUploadForm> ()

Returns the file upload page parts for metagenomes

=cut

sub displayUploadForm {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();
    my $model = $app->data_handle("FIGMODEL");
    my $content = <<TNETNOC;
    <div style='min-width: 1000px; width: 80%; margin: auto;'>
    <h3>Run fold change analysis on a new experiment</h3>
    <p>At least two CHP files are required for each dataset. Set names are optional.</p>
TNETNOC
    unless(defined($app->session()->user())) {
        $app->add_message("warning", "You must login to run the fold change analysis tool.");
        return;
    }
    # create upload information form
    $content .= "<form id='UploadForm' action='seedviewer.cgi' enctype='multipart/form-data' method='post'>".
                "<input type='hidden' name='page' value='FoldChangeAnalysisDunman'>";
    $content .= <<TNETNOC;
<input id='rep1Count' type='hidden' name='upload_1_c' value='1'/>
<fieldset id='rep1' ><legend>Replicate Set 1</legend><table>
    <tr><td>Set Name:</td><td><input type='text' name='upload_1_n'></td></tr>
    <tr><td>CHP File 1:</td><td><input type='file' name='upload_1_1'></td></tr>
    <tr><td>CHP File 2:</td><td><input type='file' name='upload_1_2'></td></tr></table>
<input type='button' value='Add Another CHP File' onClick='addAnotherUpload(1);'/>
</fieldset>
<input id='rep2Count' type='hidden' name='upload_2_c' value='1'/>
<fieldset id='rep2' ><legend>Replicate Set 2</legend><table>
    <tr><td>Set Name:</td><td><input type='text' name='upload_2_n'></td></tr>
    <tr><td>CHP File 1:</td><td><input type='file' name='upload_2_1'></td></tr>
    <tr><td>CHP File 2:</td><td><input type='file' name='upload_2_2'></td></tr></table>
<input type='button' value='Add Another CHP File' onClick='addAnotherUpload(2);'/>
</fieldset>
TNETNOC
    # Build the genome Id to name mapping
    my $geneIds = {};
    open(my $geneMapFH, "<", $self->{"path to microarrayData"} . "s.aureus.genomes");
    if (defined($geneMapFH)) {
        while(<$geneMapFH>) {
            my @parts = split(/\t/, $_);
            map { chomp $_ } @parts;
            next unless(@parts == 2);
            $geneIds->{$parts[1]} = $parts[0];
        }
        # Now only allow genomes that have an alias file 
        my $genomeAliasPath = $self->{"path to microarrayData"} . "gene_aliases/";
        my $allowedIds = {};
        foreach my $genome (glob($genomeAliasPath."*")) {
            $genome =~ s/$genomeAliasPath//;
            $allowedIds->{$genome} = 1;
        }
        $content .= "<fieldset id='genomePicker' ><legend>Select Genome</legend><table>".
            "<tr><td>Select the genome to map probes to:</td><td><select name='genome'>";
        # Add the genome select
        $content .= "<option value='158878.14'>Staphylococcus aureus subsp. aureus Mu50 (158878.14)</option>";
        foreach my $id (sort { $geneIds->{$a} cmp $geneIds->{$b} } keys %$geneIds) {
            next if ($id eq '158878.14');
            next unless(defined($allowedIds->{$id}));
            $content .= "<option value='$id'>".$geneIds->{$id}. " ($id) </option>";
        }
        $content .= "</select></td></tr></table><p><em>By default, we map probes to the Mu50 strain.</em></p></fieldset>";
    }
    $content .= "<p><input type='submit' name='nextsetp' value='Run Analysis'></p></form></div>";
    return $content;
}

=pod

=item * B<saveUpload> ()

Stores a file from the upload input form to the incoming directory
in the rast jobs directory. If successful the method writes back 
the two cgi parameters I<upload_file> and I<upload_type>.

=cut

sub saveUpload {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();
    my $model = $app->data_handle("FIGMODEL");
    unless(defined($app->session()->user())) {
        $self->addError("You must be logged in to upload a dataset.");
    }
    my @upload_c = [""];
    $upload_c[1] = $cgi->param("upload_1_c");
    $upload_c[2] = $cgi->param("upload_2_c");
    unless(defined($upload_c[1]) && defined($upload_c[2])) {
        $self->addError("There was an eror in the upload form (1)");
    }
    for(my $j=1; $j < @upload_c; $j++) {
        unless($upload_c[$j] >= 2) {
            $self->addError("You must have at least two CHP files per replicate set. (2.$j)");
            next;
        }
        for(my $i=1; $i <= $upload_c[$j]; $i++) {
            unless(defined($cgi->param("upload_$j"."_$i")) &&
                $cgi->param("upload_$j"."_$i") ne "") {
                $self->addError("You must provide a file for each of the " . $upload_c[$j] .
                    " supplied CHP file fields in Replicate Set $j (3.$j.$i)");
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
        return $self->displayUploadForm();
    }
    my $userName = $app->session()->user()->login(); 
    # Now make Temp dir with Rep1 and Rep2 subdiriectories
    my $workingDir = File::Temp::tempdir("XXXXXXXX", DIR => $self->{"path to working dirs"});
    chmod 0770, $workingDir || return $self->raiseError("Unable to chmod a file: $@ (4)");
    mkdir $workingDir . "/Rep1";
    mkdir $workingDir . "/Rep2";
    my $Filenames = [];
    for(my $j=1; $j < @upload_c; $j++) {
        my $repFilenames = [];
        for(my $i=1; $i <= $upload_c[$j]; $i++) {
            my $uploadFh = $cgi->upload("upload_$j"."_$i");	
            my $uploadFilename = $cgi->param("upload_$j"."_$i");
            push(@$repFilenames, "\"$uploadFilename\"");
            my $filePath = $workingDir . "/Rep$j"; 
            if(! -d $filePath) {
                mkdir $filePath || return $self->raiseError("Unable to create file: $@ (5)");
            }
            # Clean the uploaded filename
            $uploadFilename =~ s/\s/_/g; # replace whitespace with underscores
            $uploadFilename =~ s/[\?&=;]//g;
            # Save file
            my $fh;
            open($fh, "> $filePath/$uploadFilename") || return $self->raiseError("Unable to open file: $@ (6)");
            while ( <$uploadFh> ) {
                print $fh $_;
            }
            $fh->close();
        }
        push(@$Filenames, join(', ', @$repFilenames));
    }
    chdir($workingDir) || return $self->raiseError("Unable to chdir: $@ (7)");
    system("Rscript ../../sa_fold_change_analysis_Dunman.R . ../../S_aureus.psi > out 2> err");
    # save the names given to reps
    if (defined($cgi->param("upload_1_n")) &&
        defined($cgi->param("upload_2_n"))) {
        open(my $rep1Name, ">", "rep1Name") || die($@);
        open(my $rep2Name, ">", "rep2Name") || die($@);
        print $rep1Name $cgi->param("upload_1_n") . "\t" . $Filenames->[0] . "\n";
        print $rep2Name $cgi->param("upload_2_n") . "\t" . $Filenames->[1] . "\n";
        close($rep1Name);
        close($rep2Name);
    }
    # Save the genome ID if defined
    my $genome;
    if (defined($genome = $cgi->param("genome")) && -e "../../gene_aliases/$genome") {
        open(my $genomeFH, ">", "$workingDir/genome");
        print $genomeFH $genome . "\n";
        close($genomeFH);
    } 
    my $path = $self->{"path to working dirs"};
    $workingDir =~ s/$path//;
    return $self->displayUtilityPage($workingDir);
}

sub displayUtilityPage {
    my ($self, $key) = @_;
    my $workingDir = $self->{"path to working dirs"} . $key . "/"; 
    my $app = $self->application();
    my $model = $app->data_handle("FIGMODEL");
    # Get the names of the replicate sets
    my $rep1Name = "Replicate 1";
    my $rep2Name = "Replicate 2";
    my ($Filenames1, $Filenames2) = "";
    if ( -e "$workingDir/rep1Name" && -e "$workingDir/rep2Name" ) {
        open(my $rep1NameFH, "<", "$workingDir/rep1Name") || die($@);
        open(my $rep2NameFH, "<", "$workingDir/rep2Name") || die($@);
        while ( <$rep1NameFH> ) {
            ($rep1Name, $Filenames1) = split(/\t/, $_);
            chomp $Filenames1; 
        }
        while ( <$rep2NameFH> ) {
            ($rep2Name, $Filenames2) = split(/\t/, $_);
            chomp $Filenames2; 
        }
        close($rep1NameFH);
        close($rep2NameFH);
    }
    # Get the genome name if provided
    my $genome = undef;
    if (-e $workingDir."genome") {
        open(genomeFH, $workingDir . "genome");
        while (<genomeFH>) {
            chomp $_;
            $genome = $_;
            last if(length($genome) > 0);
        }
        close(genomeFH);
    }
    my ($probeMap, $functionMap);
    if ( defined($genome)) {
        # Need to map the mu50 peg Ids into the proper strain id
        $probeMap = $self->buildGeneTranslationHash($genome);
        $functionMap = $self->getPegFunctionHash($genome);
        
    } else {
        $genome = "158878.14";
        $probeMap = $self->buildGeneTranslationHash($genome);
        $functionMap = $self->getPegFunctionHash($genome);
    }
    # Need to add consensus sequences to table based on probe id
    my $sequenceHash = $self->buildConsensusSequenceHash();
    # Read up and down - regulated files
    my $upArray = [];
    unless(-e "$workingDir/upregulated.txt") {
        $app->add_message("warning", "There was an error in completing the analysis.");
        return $self->displayUploadForm();
    }
    open(my $upregFD, "< $workingDir/upregulated.txt") || return $self->raiseErrorResults($key, $@);
    while( <$upregFD> ) {
        push(@$upArray, $self->processResultLine($_, $probeMap, $functionMap, $sequenceHash));
    }
    close($upregFD);
    my $downArray = [];
    unless(-e "$workingDir/downregulated.txt") {
        return $self->raiseErrorResults($key, $@);
    }
    open(my $downregFD, "< $workingDir/downregulated.txt") || return $self->raiseErrorResults($key, $@);
    while( <$downregFD> ) {
        push(@$downArray, $self->processResultLine($_, $probeMap, $functionMap, $sequenceHash));
    }
    close($downregFD);
    my $allArray = [];
    open(my $allFD, "< $workingDir/complete.txt") || return $self->raiseErrorResults($key, $@);
    while( <$allFD> ) {
        push(@$allArray, $self->processResultLine($_, $probeMap, $functionMap, $sequenceHash));
    }
    close($allFD);
    my $downTable = $app->component("downTable");
    my $upTable = $app->component("upTable");
    my $allTable = $app->component("allTable");
    my $colDefU =  [ { name => "Probe" , sortable => 1, filter => 1},
                    { name => "Fold Increase $rep2Name" , sortable => 1,},
                    { name => "$rep1Name Normalized" , sortable => 1},
                    { name => "$rep1Name Flags" , sortable => 1, filter => 1},
                    { name => "$rep1Name Raw" , sortable => 1,},
                    { name => "$rep2Name Normalized" , sortable => 1,},
                    { name => "$rep2Name Flags" , sortable => 1, filter => 1},
                    { name => "$rep2Name Raw" , sortable => 1,},
                    { name => "SEED Functional Role", sortable => 1, filter => 1},
                    { name => "Gene name", sortable => 1, filter => 1},
                    { name => "Gene locus", sortable => 1, filter => 1},
                    { name => "Gene ID", sortable => 1, filter => 1},
                    { name => "Probe Consensus Sequence", "visible" => 0},
                  ];
    $upTable->columns($colDefU);
    $upTable->data($upArray);
    $upTable->items_per_page(50);
    $upTable->show_top_browse(1);
    $upTable->show_bottom_browse(1);
    $upTable->show_export_button({"strip_html" => 1, "hide_invisible_columns" => 0});
    $upTable->show_select_items_per_page(0);
    my $colDefD =  [ { name => "Probe" , sortable => 1, filter => 1},
                    { name => "Fold Increase $rep1Name" , sortable => 1,},
                    { name => "$rep1Name Normalized" , sortable => 1,},
                    { name => "$rep1Name Flags" , sortable => 1, filter => 1},
                    { name => "$rep1Name Raw" , sortable => 1,},
                    { name => "$rep2Name Normalized" , sortable => 1,},
                    { name => "$rep2Name Flags" , sortable => 1, filter => 1},
                    { name => "$rep2Name Raw" , sortable => 1},
                    { name => "SEED Functional Role", sortable => 1, filter => 1},
                    { name => "Gene name", sortable => 1, filter => 1},
                    { name => "Gene locus", sortable => 1, filter => 1},
                    { name => "Gene ID", sortable => 1, filter => 1},
                    { name => "Probe Consensus Sequence", "visible" => 0},
                  ];

    $downTable->columns($colDefD);
    $downTable->data($downArray);
    $downTable->items_per_page(50);
    $downTable->show_top_browse(1);
    $downTable->show_bottom_browse(1);
    $downTable->show_export_button({"strip_html" => 1, "hide_invisible_columns" => 0});
    $downTable->show_select_items_per_page(0);
   
    # All table, still using same headers as in down-table... 
    my $colDefAll =  [ { name => "Probe" , sortable => 1, filter => 1},
                    { name => "Fold Increase $rep1Name" , sortable => 1,},
                    { name => "Fold Increase $rep2Name" , sortable => 1,},
                    { name => "$rep1Name Normalized" , sortable => 1,},
                    { name => "$rep1Name Flags" , sortable => 1, filter => 1},
                    { name => "$rep1Name Raw" , sortable => 1,},
                    { name => "$rep2Name Normalized" , sortable => 1,},
                    { name => "$rep2Name Flags" , sortable => 1, filter => 1},
                    { name => "$rep2Name Raw" , sortable => 1},
                    { name => "SEED Functional Role", sortable => 1, filter => 1},
                    { name => "Gene name", sortable => 1, filter => 1},
                    { name => "Gene locus", sortable => 1, filter => 1},
                    { name => "Gene ID", sortable => 1, filter => 1},
                    { name => "Probe Consensus Sequence", "visible" => 0},
                  ];

    $allTable->columns($colDefAll);
    $allTable->data($allArray);
    $allTable->items_per_page(50);
    $allTable->show_top_browse(1);
    $allTable->show_bottom_browse(1);
    $allTable->show_export_button({"strip_html" => 1, "hide_invisible_columns" => 0});
    $allTable->show_select_items_per_page(0);
    
    my $resultsTv = $app->component('resultsTv');
    $resultsTv->add_tab('Upregulated', $upTable->output());
    $resultsTv->add_tab('Downregulated', $downTable->output());
    $resultsTv->add_tab('All', $allTable->output());
    
    my $outStr = "<div style='min-width: 1000px; width: 80%; margin: auto;'>".
              "<h2>Results</h2><p>Using the following files with each replicate set:<ol><li>$rep1Name".
              ": " .$Filenames1 . "</li><li>$rep2Name".": " . $Filenames2 ."</li></ol></p>".
              "<p>These results can be reached again by visiting the following link:<br/>".
              "<a href='$FIG_Config::cgi_url/seedviewer.cgi?page=FoldChangeAnalysisDunman&saved=$key'>".
              "$FIG_Config::cgi_url/seedviewer.cgi?page=FoldChangeAnalysisDunman&saved=$key</a></p>".
              $resultsTv->output() . "</div>";
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
    push(@{$self-{'errors'}}, $errorMsg);
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
    my ($self, $readLine, $probeMap, $featureHash, $sequenceHash) = @_;
    my @line = split(/\t/, $readLine);
    map { chomp $_ } @line;
    my $roles = [];
    my $objs = [];
    my $geneNames = [];
    my $geneLoci = [];
    my $geneIds = [];
    if(defined($probeMap->{$line[0]})) {
        foreach my $obj (@{$probeMap->{$line[0]}}) {
	    my $peg = $obj->{'id'};
            my $feature = $featureHash->{$peg};
	    my $locus = $obj->{'mappings'}->{'locus'};
	    my $geneid = $obj->{'mappings'}->{'geneID'};
            push(@$roles, "<a href=\"javascript:void(0)\"onclick=\"window.open(\'http://bio-data-1.mcs.anl.gov/public-pseed/FIG/seedviewer.cgi?page=Annotation&feature=".$peg."\')\">".$feature."</a>") if (defined($feature));
            push(@$geneNames, $obj->{'mappings'}->{'gene_name'}) if (defined($obj->{'mappings'}->{'gene_name'}));
            push(@$geneLoci, "<a href=\"javascript:void(0)\"onclick=\"window.open(\'http://cmr.jcvi.org/tigr-scripts/CMR/shared/GenePage.cgi?locus=".$locus."\')\">".$locus."</a>") if (defined($locus));
            push(@$geneIds, "<a href=\"javascript:void(0)\"onclick=\"window.open(\'http://www.ncbi.nlm.nih.gov/gene/".$geneid."\')\">".$geneid."</a>") if (defined($geneid));
        } 
    }
    push (@line, join(', ', @$roles));
    push (@line, join(', ', @$geneNames));
    push (@line, join(', ', @$geneLoci));
    push (@line, join(', ', @$geneIds));
    # Add sequence by matching against probe id
    if(defined($sequenceHash->{$line[0]})) { 
        push(@line, $sequenceHash->{$line[0]});
    } else {
        push(@line, "");
    }
    return \@line;
}


sub buildConsensusSequenceHash {
    my ($self) = @_;
    my $sequenceHash = {};
    my $sequenceFile = $self->{"path to microarrayData"} . "consensus_sequence.txt";
    my $seqFH;
    if ( !-e $sequenceFile || !open($seqFH, "<", $sequenceFile) ) {
        return $sequenceHash;
    }
    my $headerHash = {};
    while ( <$seqFH> ) {
	chomp;
        if ( scalar(keys %$headerHash) == 0) {
            my @fileHeaders = split(/\t/, $_);
            for(my $i=0; $i<@fileHeaders; $i++) {
                $headerHash->{$fileHeaders[$i]} = $i;
            }
        } else {
            my @parts = split(/\t/, $_);
            my $locusId = $parts[0];
            my $sequence = $parts[10];
            if(defined($locusId) && defined($sequence)) {
                $sequenceHash->{$locusId} = $sequence;
            }
        }
    }
    close($seqFH);
    return $sequenceHash; 
}

sub buildGeneTranslationHash {
    my ($self, $targetGenome) = @_;
    my $geneAliasFilename = $self->{'path to microarrayData'} . "gene_aliases/$targetGenome.new";
    my $geneTranslation = {};
    my $geneAliasFH;
    unless( -e $geneAliasFilename && open($geneAliasFH, "<", $geneAliasFilename)) {
        return $geneTranslation;
    }
    while ( <$geneAliasFH> ) {
	chomp;
        my ( $mu50Id, $targetId, $confidence, $mappings, $probeIds ) = split(/\t/, $_);
        next unless(defined($targetId) && defined($probeIds));
        my @parts = split(/,/, $mappings);
        my $mappingsHash = {};
        foreach my $part (@parts) {
            my ($key, $val) = split(/\|/, $part);
            next unless(defined($key) && defined($val));
            $mappingsHash->{$key} = $val;
        }
        my $obj = { 'id' => $targetId, 'confidence' => $confidence,
            'mappings' => $mappingsHash };
        my @probes = split(/,/, $probeIds);
        foreach my $probe (@probes) {
            $geneTranslation->{$probe} = [] unless(defined($geneTranslation->{$probe}));
            push(@{$geneTranslation->{$probe}}, $obj);
        }
    }
    return $geneTranslation;
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

sub require_javascript {
    my ($self) = @_;
    return ["$FIG_Config::cgi_url/Html/DunmanUtil.js", "$FIG_Config::cgi_url/Html/jquery-1.3.2.min.js"];
}

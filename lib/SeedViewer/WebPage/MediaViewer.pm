package SeedViewer::WebPage::MediaViewer;

use base qw( WebPage );

1;

use strict;
use warnings;

use FIGMODEL;
use FIGV;
use UnvSubsys;

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

    $self->title('Media Viewer');

    # register components
    $self->application->register_component('Table', 'MediaTable');
    $self->application->register_component('Table', 'CompoundTable');
    $self->application->register_component('FilterSelect', 'fs');
    $self->application->register_component('Table', 'compound_select_table');
    $self->application->register_component('EventManager', 'event_manager');
    $self->application->register_component('Ajax', 'ajax');
}

=item * B<output> ()

Returns the html output of the Reaction Viewer page.

=cut

sub output {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();
    my $ajax = $app->component('ajax');
    my $event = $app->component('event_manager');
    my $html = $ajax->output();
    if (defined($cgi->param("m"))) {
        # m == media id
        $html .= $self->output_media_details();
    } elsif(defined($cgi->param("new"))) {
        # n == old-media id or empty
        $html .= $self->new_media_select();
    } elsif(defined($cgi->param('o'))) {
        $html .= $self->display_temp_table();
    } else {
        $html .= $self->output_media_table();
    }
    return $html . $event->output();
}

sub display_temp_table {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();
    my $MediaTable = $app->component("MediaTable");
    my $html = "<div style='min-width: 1000px; width: 80%; margin: auto;'>";
    $MediaTable->columns( [ { name => 'Name', sortable => 1, filter => 1},
                            { name => 'Compounds', sortable => 1, filter => 1},
                            { name => 'Metabolic Overview', sortable => 0, filter => 0, width => 200 },
                            { name => 'Owner', sortable => 1, filter => 1},
                            { name => 'Added On', sortable => 1, filter => 1},
                          ]);
    my $col2 = <<COLUMN2;
<a title="cpd00239" href="?page=CompoundViewer&amp;compound=cpd00239&amp;model=NONE" style="text-decoration: none;">Hydrogen sulfide</a>, <a title="cpd00541" href="?page=CompoundViewer&amp;compound=cpd00541&amp;model=NONE" style="text-decoration: none;">Lipoate</a>, <a title="cpd00793" href="?page=CompoundViewer&amp;compound=cpd00793&amp;model=NONE" style="text-decoration: none;">Thiamin monophosphate</a>, <a title="cpd00046" href="?page=CompoundViewer&amp;compound=cpd00046&amp;model=NONE" style="text-decoration: none;">CMP</a>, <a title="cpd00091" href="?page=CompoundViewer&amp;compound=cpd00091&amp;model=NONE" style="text-decoration: none;">UMP</a>, <a title="cpd00018" href="?page=CompoundViewer&amp;compound=cpd00018&amp;model=NONE" style="text-decoration: none;">AMP</a>, <a title="cpd00126" href="?page=CompoundViewer&amp;compound=cpd00126&amp;model=NONE" style="text-decoration: none;">GMP</a>, <a title="cpd00311" href="?page=CompoundViewer&amp;compound=cpd00311&amp;model=NONE" style="text-decoration: none;">Guanosine</a>, <a title="cpd00182" href="?page=CompoundViewer&amp;compound=cpd00182&amp;model=NONE" style="text-decoration: none;">Adenosine</a>, <a title="cpd00035" href="?page=CompoundViewer&amp;compound=cpd00035&amp;model=NONE" style="text-decoration: none;">L-Alanine</a>, <a title="cpd00051" href="?page=CompoundViewer&amp;compound=cpd00051&amp;model=NONE" style="text-decoration: none;">L-Arginine</a>, <a title="cpd01048" href="?page=CompoundViewer&amp;compound=cpd01048&amp;model=NONE" style="text-decoration: none;">Arsenic acid</a>, and <a href='?page=MediaViewer&m=ArgonneLBMedia'>52 more compounds</a>
COLUMN2

    my $row1 = [ "ArgonneLBMedia", $col2, "<table><tr><td>Large Carbohydrates</td><td>2 g/ml</td></tr><tr><td>Amino acids</td><td>1 g/ml</td></tr><tr><td>Lipids</td><td>5 g/ml</td></tr></table>",
                 "Public", "1 April 2010"];
    $MediaTable->data([$row1]);
    $MediaTable->width(1000);
    $html .= $MediaTable->output();
    return $html . "</div>"
}

=item * B<ouput_media_details> ()

Outputs details for a selected media.

=cut

sub output_media_details {
    my ($self, $mediaId) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();
    my $model = $app->data_handle("FIGMODEL");
    my $html = "";
    my $errors = [];
    unless(defined($mediaId)) {
        $mediaId = $cgi->param("m");
    }
    my $mediaDB = $model->database()->get_object_manager("media");
    my $mediaCompoundDB = $model->database()->get_object_manager("mediacpd");
    my $compoundDB = $model->database()->get_object_manager("compound");
    unless(defined($mediaDB) && defined($mediaCompoundDB) && defined($compoundDB)) {
        warn "Unable to load media table!";
    }
    # Get media object from DB
    my $mediaRow = $mediaDB->get_objects({'id' => $mediaId});
    (@$mediaRow > 0) ? $mediaRow = $mediaRow->[0] : push(@$errors,
        "Unable to find media: $mediaId in media table!");
    # Get media compound information
    my $compoundInfo = [];
    my $mediaCompounds = $mediaCompoundDB->get_objects({"MEDIA" => $mediaId});
    for(my $i=0; $i<@$mediaCompounds; $i++) {
        push(@$compoundInfo, @{$compoundDB->get_objects({"id" => $mediaCompounds->[$i]->COMPOUND()})});
    }
    if(@$errors == 0) {
        my $owner = ($mediaRow->owner() eq 'master') ? 'Public' : $mediaRow->owner();
        my $creationDate = $mediaRow->creationDate();
        my $modificationDate = $mediaRow->modificationDate(); 
        my $aerobic = ($mediaRow->aerobic()) ? 'Aerobic' : "Anaerobic";
        $html .= <<META;
    <div style='margin: auto; width:80%; min-width: 1000px;'>
    <h2>$mediaId Details</h2>
    <div id='general_info'>
      <div style='float: right;'>
        <span style='padding:5px; margin-right: 5px; background-color: rgb(100,126,178); color: white;'>Download</span>
        <span style='padding:5px; margin-right: 5px; background-color: rgb(100,126,178); color: white;'>Edit</span>
      </div>
      <table>
      <tr><td>Created by:</td><td>$owner</td></tr>
      <tr><td>Created on:</td><td>$creationDate</td></tr>
      <tr><td>Last modified on:</td><td>$modificationDate</td></tr>
      <tr><td>Type:</td><td>$aerobic</td></tr>
      <tr><td>References:</td><td><em>None.</em></td></tr>
      <tr><td>Description:</td><td>My favorite kind of media.</td></tr>
      </table>
    </div>
META
        my $cpdTableData = []; 
        my $compoundTable = $app->component("CompoundTable");
        $compoundTable->columns( [ { name => 'Names', filter => 1, sortable => 1},
                                   { name => 'Image', filter => 1, sortable => 1},
                                   { name => 'Formula', filter => 1, sortable => 1},
                                   { name => 'Max', filter => 1, sortable => 1},
                                   { name => 'Min', filter => 1, sortable => 1},
                               ]);
        for(my $i=0; $i<@$compoundInfo; $i++) {
            my $id = $compoundInfo->[$i]->id();
            my $cpdRow = [];
            push(@$cpdRow, $compoundInfo->[$i]->name());
            my $cpdImage = '';
            if(-e $model->{'jpeg absolute directory'}->[0].$id.".jpeg") {
                $cpdImage = "<div style='width:150px; height: 100px;'><img src='".
                $model->{'jpeg web directory'}->[0].$id.".jpeg' height='100%' width='100%'></img></div>";
            }
            push(@$cpdRow, $cpdImage);
            push(@$cpdRow, $compoundInfo->[$i]->formula());
            push(@$cpdRow, $mediaCompounds->[$i]->concentration());
            push(@$cpdRow, $mediaCompounds->[$i]->maxFlux());
            push(@$cpdTableData, $cpdRow);
        }
        $compoundTable->data($cpdTableData);
        $html .= $compoundTable->output();
        return $html . "</div>";
    }
}
        

=item * B<new_media_select> ()

First page in new media creator. Allows user to select method of input.

=cut

sub new_media_select {
    my ($self) = @_;
    my $app = $self->application();
    my $username = $app->session()->user();
    unless(defined($username)) {
        $app->add_message('info', "You must login to create new media formulations");
        return $self->output_media_table();
    }
    my $cgi = $app->cgi();
    my $html;
    my $method = $cgi->param('new');
    my $model = $app->data_handle('FIGMODEL');
    # Figure out if new == existing media
    my $methodIsExistingMedia = 0;
    my $parsedMediaData = 0;
    if (defined($method) && $methodIsExistingMedia) { # Got existing media as new
        $html .= "<form id='formOneB'><input type='hidden' name='media' value='$parsedMediaData'></form>".
                    "<img src='$FIG_Config::cgi_url/Html/clear.gif' onLoad='EM.raiseEvent(\"OneB\", \"formOneB\");'/>";
    } elsif (defined($method) && $method eq 'file') {
        $html .= <<FOOBAR;
        <div id='oneContent' style='background-color: rgb(164, 210, 140); margin-bottom: 10px; padding: 10px;'>
        <h3>Step 1B: Upload formulation</h3>
        <p>Paste your media formulation into the text box below. Required format:
        <ul><li>Entry consists of compound name, concentration and maximum flux. These are semicolon delineated.</li>
            <li>Compound name can be one of the accepted names or the compound ID.</li>
            <li>One entry per line.</li>
        </ul>
        For example:<br/>
<pre>
compoundName;concentration;maxFlux
compoundName;concentration;maxFlux</pre>
        </p>
        <form id='formOneB' enctype='multipart/form-data'>
            <textarea name='fileText' cols='100' rows='15'></textarea><br/>
            <input type='button' onClick='EM.raiseEvent("OneB", "formOneB");' value='Next'></input><br/>
            </form>
        </div>
FOOBAR
    } elsif(defined($method) && $method eq 'existing') {
        # Setup media filter select
        my $fs = $app->component('fs');
        my $db = $model->database()->get_object_manager('media');
        my $media = $db->get_objects();
        my $labels = [];
        my $values = [];
        for(my $i=0; $i<@$media; $i++) {
            my $m = $media->[$i];
            push(@$labels, $m->id());
            push(@$values, $m->id());
        }
            
        $fs->labels($labels);
        $fs->values($values);
        $fs->size(8);
        $fs->width(250);
        $fs->dropdown(1);
        $fs->name('media');
        my $out = $fs->output();
        $html .= <<FOOBAR;
        <div id='oneContent'>
            <h3>Step 1B: Select existing formulation</h3>
            <p>Select an existing media conditon.</p>
            <form id='formOneB' onSubmit='EM.raiseEvent("OneB", "formOneB")'>
                $out
            </form>
            <input type='button' onClick='EM.raiseEvent("OneB", "formOneB");' value='Next'></input><br/>
        </div>
FOOBAR
    } elsif(defined($method) && $method eq 'empty') {
        $html .= "<img src='$FIG_Config::cgi_url/Html/clear.gif'".
                    "onLoad='EM.raiseEvent(\"OneB\", \"new=empty\");'/>"
    } else {
        # Return method choice (Step OneA) 
        my $event = $app->component("event_manager");
        $event->addEvent("OneB", "parseOneB");
        $html .= <<FOOBAR;
        <div id='one' style='background-color: rgb(164, 210, 140); margin-bottom: 10px; padding: 10px;'>
        <div id='oneContent'>
        <h3>Step 1: Select base media or upload media details</h3>   
        <p>Would you like to start with an existing media formulation in the database, upload the formulation from a file or start with an empty media formulation?</p>
        <form id='formOneA' action='' type='POST'>
            <input type='radio' name='new' value='existing' checked> Start with an existing media formulation</input><br/>
            <input type='radio' name='new' value='file'> Upload the formulation from a file</input><br/>
            <input type='radio' name='new' value='empty'> Start with an empty formulation</input><br/>
        </form>
            <input type='button' onClick='execute_ajax("new_media_select", "one", "formOneA", "Loading..", 0);'  value='Next'></input>
        </div>
        </div>
        <div id='two' style='background-color: rgb(221, 221, 221); margin-bottom: 10px; padding: 10px;'>
            <h3>Step 2: Make changes and Confirm formulation</h3>
        </div>
        <div id='three' style='background-color: rgb(221, 221, 221); margin-bottom: 10px; padding: 10px;'>
            <h3>Step 3: Name and Set Permissions</h3>
        </div>
FOOBAR
    }
    return $html;
}

sub new_media_parse_file {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();
    my $errors = [];
    unless(defined($cgi->param('fileUpload'))) {
        push(@$errors, "No file provided.");
    }
    my $uploadFH = $cgi->upload('fileUpload');
    warn $uploadFH;
    my $uploadFileName = $cgi->param('fileUpload');
    my $media = [];
    my $lineNumber = 1;
    while( <$uploadFH> ) {
        chomp;
        my @lines = split(/;/, $_);
        if (@lines > 1) {
            foreach my $line (@lines) {
                my @compoundInfo = split(/,/, $line);
                unless(@compoundInfo == 3) {
                    push(@$errors, "Error in line: " .
                        $lineNumber . " of media definition.");
                    next;
                }
                my $id = $self->resolve_cpd($compoundInfo[0]);
                unless(defined($id)) {
                    push(@$errors, "Unknown compound: " .
                        $compoundInfo[0] . " on line: " . $lineNumber);
                    next;
                }
                $compoundInfo[0] = $id;  
                push(@$media,join(',', @compoundInfo));
            }
        }
        my @compoundInfo = split(/,/, $lines[0]);
        unless(@compoundInfo == 3) {
            push(@$errors, "Error in line: " .
                $lineNumber . " of media definition.");
            next;
        }
        my $id = $self->resolve_cpd($compoundInfo[0]);
        unless(defined($id)) {
            push(@$errors, "Unknown compound: " .
                $compoundInfo[0] . " on line: " . $lineNumber);
            next;
        }
        $compoundInfo[0] = $id;  
        push(@$media,join(',', @compoundInfo));
        $lineNumber++;
    }
    return $self->new_media_step_two(join(';',@$media), join('<br/>', @$errors));
}


sub resolve_cpd {
    my ($self, $name) = @_;
    if(defined($self->{'cpd_lookup'})) {
        my $id = $self->{'cpd_lookup'}->{$name};
        if(defined($id)) {
            my @arr = split(';', $id); # if cpdId is passed in, result is cpdId;officialCpdName 
            if(@arr == 1) { # otherwise get the official name
                my $idAndName = $self->{'cpd_lookup'}->{$id};
                @arr = split(';', $idAndName);
            }
            return \@arr;
        } else { 
            return [undef, $name];
        }
    } else { # Build the lookup table
        my $app = $self->application();
        my $model = $app->data_handle('FIGMODEL');
        my $compoundAliasDb = $model->database()->get_object_manager('cpdals');
        my $compoundDb = $model->database()->get_object_manager('compound');
        my $hash = {};
        my $aliases = $compoundAliasDb->get_objects({'type' => 'name'});
        push(@$aliases, @{$compoundAliasDb->get_objects({'type' => 'KEGG'})});
        for(my $i=0; $i<@$aliases; $i++) {
            my $al = $aliases->[$i];
            $hash->{$al->alias()} = $al->COMPOUND();
        }
        my $realCpds = $compoundDb->get_objects();
        for(my $i=0; $i<@$realCpds; $i++) {
            my $cpd = $realCpds->[$i];
            $hash->{$cpd->id()} = $cpd->id().';'.$cpd->name();
            $hash->{$cpd->name()} = $cpd->id();
        }
        $self->{'cpd_lookup'} = $hash;
        return $self->resolve_cpd($name);
    }
}
        
sub new_media_step_two {
    my ($self, $media, $errors) = @_;
    my $app = $self->application();
    my $model = $app->data_handle('FIGMODEL');
    my $cgi = $app->cgi();
    if(not defined($media)) {
        $media = $cgi->param('media');
    }
    my $html = "";
    if(defined($errors)) {
        $html .= $errors;
    }
    $errors = [];
    $html .= '<div style="background-color: rgb(184, 230, 160); margin-bottom: 5px; padding: 10px;">'.
             '<table id="mediaTable"><thead><tr><th style="width: 400px;">Compound Name</th><th>Concentration</th>'.
             '<th>Maximum Flux</th><th>Remove</th><th style="visibility: hidden;">Errors</th></tr></thead><tbody></tbody>';
    my $mediaDb = $model->database()->get_object_manager('media');
    my $newMedia = $mediaDb->get_objects({'id' => $media});
    my $compoundDb = $model->database()->get_object_manager('compound');
    if(defined($newMedia) && @$newMedia > 0) {
        my $mediaCompoundDb = $model->database()->get_object_manager('mediacpd');
        my $compounds = $mediaCompoundDb->get_objects({'MEDIA' => $newMedia->[0]->id()});
        $media = []; 
        for(my $i=0; $i<@$compounds; $i++) {
            my $mediaCpd = $compounds->[$i];
            my $cpds = $compoundDb->get_objects({'id' => $mediaCpd->COMPOUND()});
            my $cpd = $cpds->[0];
            push(@$media, $cpd->id().';'.$cpd->name().';'.$mediaCpd->concentration().';'.$mediaCpd->maxFlux());
        }
    } else {
        my @elements = split(/\n/, $media);
        $media = [];
        for(my $i=0; $i<@elements; $i++) {
            my ($name, $conc, $maxFlux) = split(/;/, $elements[$i]);
            my $j = $i + 1;
            unless(defined($name) && defined($conc) && defined($maxFlux)) {
                if(chomp($elements[$i]) eq '') {
                    push(@$errors, "Unable to parse line $j : Line may be empty.</br>"); 
                } else {
                    push(@$errors, "Unable to parse line $j : ".$elements[$i]."</br>"); 
                }
                next;
            }
            my $id = undef;
            my $idAndRealName = $self->resolve_cpd($name);
            $id = $idAndRealName->[0];
            $name = $idAndRealName->[1];
            unless(defined($id)) {
                push(@$errors, "Unable to resolve compound name for $name in ".
                    $elements[$i] . ", line $j</br>");
                next;
            }
            push(@$media, $id.';'.$name.';'.$conc.';'.$maxFlux);
        }
    }
    if(defined($media)) {
        # parse media string and continue
        for(my $i=0; $i<@$media; $i++) {
            my ($id, $name, $conc, $max) = split(/;/, $media->[$i]);
            $html .= "<tr id='$id' ><td><a href='seedviewer.cgi?page=CompoundViewer&compound=$id'>$name</a><input class='cpdId' type='hidden' value='$id' /></td>".
                     "<td><input id='$id"."_conc' type='text' value='$conc'/></td>".
                     "<td><input type='text' id='$id"."_max' value='$max'/></td>".
                     "<td><input type='button' onClick='removeCompound(\"$id\");' value='remove'/></td></td></tr>";
        }
    }
    my $table = $app->component('compound_select_table');
    $table->columns( [ { 'name' => 'Select', 'filter' => 0, 'sortable' => 1},
                       { 'name' => 'Compound', 'filter' => 1, 'sortable' => 1},
                       { 'name' => 'Names', 'filter' => 1, 'sortable' => 1},
        #               { 'name' => 'Aliases', 'filter' => 1, 'sortable' => 1},
                       { 'name' => 'Formula', 'filter' => 1, 'sortable' => 1},
                    ]);
    my $tableData = [];
    my $compoundAliasDb = $model->database()->get_object_manager('cpdals');
    my $compounds = $compoundDb->get_objects();
    my $aliasMap = {};
    my $aliases = $compoundAliasDb->get_objects({'type' => 'name'});
    push(@$aliases, @{$compoundAliasDb->get_objects({'type' => 'KEGG'})});
    for (my $i=0; $i<@$aliases; $i++) {
        if(defined($aliasMap->{$aliases->[$i]->COMPOUND()})) {
            push(@{$aliasMap->{$aliases->[$i]->COMPOUND()}}, $aliases->[$i]->alias());
        } else {
            $aliasMap->{$aliases->[$i]->COMPOUND()} = [$aliases->[$i]->alias()];
        }
    }
    for(my $i=0; $i<@$compounds; $i++) {
        my $cpd = $compounds->[$i];
        my $row = [ "<input type='button' value='Add' onClick='addCompound(\"".$cpd->id()."\", \"".$cpd->name()."\");'/>" ];
        push(@$row, $cpd->id());
        push(@$row, $cpd->name() . ', ' . join(', ', @{$aliasMap->{$cpd->id()}}));
        push(@$row, $cpd->formula());
        push(@$tableData, $row);
    }
    $table->data($tableData);
    $table->items_per_page(25);
    $table->show_select_items_per_page(0);
    $table->show_top_browse(1);
    $table->show_bottom_browse(1);
    $table->width(900);
    my $out = $table->output();
    $html .= <<FOOBAR;
        <div style='width: 100\%; background-color: white;'>
        $out
        </div></div>
    <p>Once you are done modifying the media formulation, click 'Next' to name and set permissions on your media.</p>
    <input type='button' onClick='parseTwo();' value='Next Step'/>
FOOBAR
    my $errorText = '';
    if(@$errors > 0) {
        $errorText = "<p>There were the following errors in uploading your media formulation:</br>".
            join('</br>', @$errors) . "</p>";
    }
    return "<h3>Step 2: Make changes and confirm media formulation</h3>" . $errorText . $html;
}


sub new_media_completed_two {
    my ($self) = @_;
    my $app = $self->application();
    my $model = $app->data_handle("FIGMODEL");
    my $cgi = $app->cgi();
    my $media = $cgi->param('media');
    my $html = <<FOOBAR;
    <h3>Step 2: Final Media Formulation</h3>
    <table id="mediaTable"><thead><tr><th style="width: 400px;">Compound Name</th>
    <th>Concentration</th><th>Maximum Flux</th></thead><tbody>
FOOBAR
    if(defined($media)) {
        my @compounds = split(/:/, $media);
        my $compoundDb = $model->database()->get_object_manager('compound');
        foreach my $compound (@compounds) {
            my ($id, $conc, $maxFlux) = split(/,/, $compound);
            unless(defined($id) && defined($conc) && defined($maxFlux)) {
                next;
            }
            my $cpd = $compoundDb->get_objects({'id' => $id});
            if(defined($cpd) && @$cpd > 0) {
                $id = $cpd->[0]->name();
            }
            $html .= "<tr><td>".$id."</td><td>".$conc."</td><td>".$maxFlux."</td></tr>";
        }
    }
    $html .= "</tbody></table>";
    return $html;
} 

sub new_media_step_three {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();
    my $media = $cgi->param('media');
    my $html = <<FOOBAR;
        <h3>Step 3: Name and Set permissions</h3>
        <form id='formThree' method='POST'>
            <table>
            <tr><td>Name:</td><td><input type='text' size='50' name='name'></td></tr>
            <tr><td>Permissions:</td><td><input type='radio' name='owner' value='private' checked/>Private</td></tr>
            <tr><td></td><td><input type='radio' name='owner' value='public'/>Public</td></tr>
            </table>
            <input type='hidden' name='media' value='$media'/>
        </form>
            <input type='button' value='Upload' onClick='saveMedia();'></input>
FOOBAR
    return $html;
}

sub new_media_final {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();
    my $html;
    my $errors = [];
    my $name = $cgi->param('name');
    my $owner = $cgi->param('owner');
    my $media = $cgi->param('media');
    my $aerobic = 0;
    unless(defined($name) && defined($owner) && defined($media)) {
        push(@$errors, "Incomplete result from form.");
    }
    my $model = $app->data_handle("FIGMODEL");
    my $mediaDB = $model->database()->get_object_manager('media');
    my $compoundDB = $model->database()->get_object_manager('compound');
    my $mediaCompoundDB = $model->database()->get_object_manager('mediacpd');
    # Build compound Id hash
    my $cpdIdHash = {};
    my $compounds = $compoundDB->get_objects();
    for(my $i=0; $i<@$compounds; $i++) {
        $cpdIdHash->{$compounds->[$i]->id()} = 1;
    }
    # Check that all compounds are well defined
    my @media = split(/:/, $media);
    my $mediaCompoundRows = [];
    for(my $i=0; $i<@media; $i++) {
        my ($id, $conc, $maxFlux) = split(/,/, $media[$i]);
        unless(defined($id) && defined($conc) && defined($maxFlux)) {
            push(@$errors, "Unknown compound specification in row: $i.");
        }
        unless(defined($cpdIdHash->{$id})) {
            push(@$errors, "Unknown compound ID: $id.");
        }
        if($id eq "cpd00009") { $aerobic = 1; }
        push(@$mediaCompoundRows, [$id, $conc, $maxFlux]); 
    }
    my $existingMediaWithSameName = $mediaDB->get_objects({'id' => $name});
    if(@$existingMediaWithSameName > 0) {
        push(@$errors, "Media already exists with name: $name.");
    }
    # Check for login one last time
    my $username = $app->session()->user();
    ($username) ? $username = $username->login() : push(@$errors,
        "You must be logged in to add a media formulation.");
    
    if(@$errors == 0) {
        my $mediaObj = $mediaDB->create( { 'id' => $name,
                        'owner' => $username,
                        'modificationDate' => time(),
                        'creationDate' => time(),
                        'aerobic' => $aerobic,
                    });
        for(my $i=0; $i<@$mediaCompoundRows;$i++) {
            my $cpd = $mediaCompoundRows->[$i];
            $mediaCompoundDB = $model->database()->get_object_manager('mediacpd');
            my $realRow = $mediaCompoundDB->create( { 'COMPOUND' => $cpd->[0],
                                'MEDIA' => $name, 'concentration' => $cpd->[1],
                                'maxFlux' => $cpd->[2] });
        }
        return "<img src='./Html/clear.gif' onLoad='window.location.href=\"$FIG_Config::cgi_url/seedviewer.cgi?page=MediaViewer&m=$name\";'/>";
    } else {
        push(@$errors, "Media formulation not added to database due to errors.");
        warn join('\n', @$errors);
        $app->add_message('warning', join('<br/>', @$errors));
        return $self->new_media_select();
    }
}
    
        
    
        
    
        

sub output_media_table {
    my ($self) = @_;
    my $application = $self->application();
    my $cgi = $application->cgi();
    my $model = $application->data_handle('FIGMODEL');
    my $html = '<h1>Media Formulations</h1>'.
        '<p>Public and your private media formulations are listed below.'.
        ' Click on the media name for more details. Compounds are listed in '.
        'order of their concentration in the media. You may also <a href="?page=MediaViewer&new">'.
        ' create a new formulation</a>.</p>';
    my $mediaData = [];
    my $mediaDb = $model->database()->get_object_manager('media');
    my $mediaCompoundDb = $model->database()->get_object_manager('mediacpd');
    my $compoundDb = $model->database()->get_object_manager('compound');
    my $cpdIdToName = {};
    my $compounds = $compoundDb->get_objects();
    for(my $i=0; $i<@$compounds; $i++) {
        unless(defined($cpdIdToName->{$compounds->[$i]->id()})) {
            $cpdIdToName->{$compounds->[$i]->id()} = $compounds->[$i]->name();
        }
    }
    my $media = $mediaDb->get_objects({ 'owner' => 'master'});
    if(defined($application->session()->user()) &&
        defined(my $username = $application->session()->user()->login())) {
        push(@$media, @{$mediaDb->get_objects({'owner' => $username})});
    }
    my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    my $mediaCompoundsByMediaName = {};
    my $mediaCompounds = $mediaCompoundDb->get_objects();
    for(my $i=0; $i<@$mediaCompounds; $i++) {
        my $mc = $mediaCompounds->[$i];
        if(defined($mediaCompoundsByMediaName->{$mc->MEDIA()})) {
            push(@{$mediaCompoundsByMediaName->{$mc->MEDIA()}}, $mc);
        } else {
            $mediaCompoundsByMediaName->{$mc->MEDIA()} = [$mc];
        }
    }
    for(my $i=0; $i<@$media; $i++) {
        my $id = $media->[$i]->id();
        my $row = ["<a href='?page=MediaViewer&m=$id'>$id</a>"];
        #my $mediaCompounds = $mediaCompoundDb->get_objects({'MEDIA' => "$id"});
        my $mediaCompounds = $mediaCompoundsByMediaName->{$id} || [];
        my %concMap;
        for(my $j=0; $j<@$mediaCompounds; $j++) {
            my $num = @$mediaCompounds;
            my $cpd = $mediaCompounds->[$j];
            if(not defined($cpd)) {
                warn "$id and $j and $num";
                next;
            }
            $concMap{$cpd->COMPOUND()} = $cpd->concentration();
        }
        my @sortedCpds = sort { $concMap{$a} cmp $concMap{$b} } keys %concMap;
        #my @sortedCpds = keys %concMap;
        my $cpdString = [];
        my $overflow = '';
        for(my $j=0; $j<@sortedCpds; $j++) {
            my $cpdName = $sortedCpds[$j];
            my $link = "<a href='?page=CompoundViewer&compound=$cpdName' title='$cpdName'";
            if($j == 24) {
                my $count = @sortedCpds - 24;
                $overflow = "<span>and $count more...";
            }
            if($j >= 24) {
                $link .= "style='display: none;'>".$cpdIdToName->{$cpdName}."</a>";
                $overflow .= $link;
            } else {
                $link .= ">".$cpdIdToName->{$cpdName}."</a>";
                push(@$cpdString, $link);
            }
        }
        if ($overflow ne '') {
            push(@$cpdString, $overflow."</span>");
        }
        push(@$row, join(', ', @$cpdString)); 
        push(@$row, "");
        push(@$row, ($media->[$i]->owner() eq 'master') ? 'Public' : $media->[$i]->owner());
        my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($media->[$i]->creationDate());
        $year += 1900;
        push(@$row, "$months[$mon] $mday, $year");
        push(@$mediaData, $row);
    }
    my $media_table = $application->component('MediaTable');
    $media_table->columns( [ { name => 'Media name', filter => 1, sortable => 1},
                           { name => 'Compounds', filter => 1, sortable => 1, width => 400},
                           { name => 'Metabolic Overview', filter => 0, sortable => 0},
                           { name => 'Owner', filter => 1, sortable => 1},
                           { name => 'Added On', 'filter' => 1, sortable => 1, width => 100},
                        ]);
    $media_table->data($mediaData);
    $media_table->items_per_page(50);
    $media_table->show_select_items_per_page(0);
    $media_table->show_top_browse(1);
    $media_table->show_bottom_browse(1);
    #$media_table->width(1200);
    $html .= $media_table->output();
    return $html;
}

sub require_javascript {
    return ["$FIG_Config::cgi_url/Html/MediaViewer.js"];
}

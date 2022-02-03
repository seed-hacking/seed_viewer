package SeedViewer::WebPage::ModelEdit;

use base qw( WebPage );

1;

use strict;
use warnings;
use Tracer;
use URI::Escape;

use FIG_Config;

use WebComponent::WebGD;
use WebColors;
use WebLayout;

=pod

=head1 NAME

Model Edit

=head1 DESCRIPTION

A simple tool for editing models by uploading a text file of the revised model.

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
    my ($self) = @_;
    $self->{'fileLocation'} = "/vol/model-dev/MODEL_DEV_DB/TempEditedModels/";
    $self->title('Model SEED | Upload a revised model');
    $self->application->register_component('Ajax', 'ajax');
    return 1;
}

=item * B<output> ()

=cut

sub output {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();
    my $figmodel = $app->data_handle('FIGMODEL');
    my $user;
    my $ajax = $app->component('ajax');
    my $html = $ajax->output();
    my $uploadFile = $cgi->param("u");
    my $selectedModel = $cgi->param("m");
    # Check if user is logged in
    if(not defined($app->session->user)) {
        $html = $self->redirectToMV($selectedModel);
        return $html;
    }
    $user = $app->session->user->login;
    # Check if model is given 
	my $mdl;
    if (defined($selectedModel)) {
    	$mdl = $figmodel->get_model($selectedModel);
    }
    if (!defined($mdl) ) {
    	$html = "<p>Input model not found</p>".$self->redirectToMV($selectedModel);
        return $html;
    }
    if ($mdl->owner() ne $user) {
    	$html = "<p>User does not own model</p>".$self->redirectToMV($selectedModel);
        return $html;
    }
    if(defined($uploadFile)) {
        # Do file parsing and upload
        my $uploadFh = $cgi->upload("u"); 
        my $uploadFilename = $cgi->param("u");
        my $filePath = $self->{'fileLocation'};
        if(! -d $filePath) {
            mkdir $filePath or die $@;
        }
        # Clean the uploaded filename
        $uploadFilename =~ s/\s/_/g; # replace whitespace with underscores
        $uploadFilename =~ s/[\?&=;]//g;
        # Save file
        my $fh;
        my $filename = $mdl->directory().$mdl->id()."-uploadtable.tbl";
        open($fh, "> $filename") || die $@;
        while ( <$uploadFh> ) {
            print $fh $_;
        }
        $fh->close();
        # Do parsing on $filePath/$uploadFilename #
        $mdl->integrateUploadedChanges();
        # finally redirect to ModelViewer
        $html = $self->redirectToMV($selectedModel);
    } else {
        # We're preparing upload form
        # Check if user owns model
        my @tmp = split(/\./, $selectedModel);
        my $modelOwnerId = $tmp[@tmp-1];
        if ($app->session->user->_id() != $modelOwnerId) {
            $html = $self->redirectToMV($selectedModel);
            return $html;
        }
        # Ok, print out upload form
        $html .= <<FOOBAR;
<div id='main'><h2>Upload model revision for: $selectedModel</h2>
    <p> Select a file to upload:</p>
    <form id='mu' action='seedviewer.cgi' enctype='multipart/form-data' method='post'>
        <input type='hidden' name='page' value='ModelEdit'></input>
        <input type='hidden' name='m' value='$selectedModel'></input>
        <input type='file' name='u'></input>
        <input type='submit' value='Submit'/>
    </form>
</div>
FOOBAR
        return $html;
    }
}


sub redirectToMV {
    my ($self, $model) = @_;
    my $app = $self->application();
    my $html = "<img src='Html/clear.gif' onLoad='window.location = \"seedviewer.cgi?page=ModelView";
    if (defined($model)) {
        $html .= "&model=$model\";'/>";
    } else {
        $html .= "\";'/>";
    }
    return $html;
}

package SeedViewer::WebPage::ModelControls;

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
    $self->title('Model Controls');
    $FIG_Config::static_url = $FIG_Config::cgi_url . "/Html/";
    $self->require_css_ordered([$FIG_Config::static_url.'ModelControls.css']);
    $self->require_javascript_ordered([$FIG_Config::static_url.'jquery-1.3.2.min.js',
                                       $FIG_Config::cgi_url.'/Web_Config.cgi?prefix=web_config',
                                       $FIG_Config::static_url.'ModelControls.js']);
    return 1;
}

=item * B<output> ()

=cut

sub output {
    my ($self) = @_;
    my $app = $self->application();
    my $cgi = $app->cgi();
    my $model_id = $cgi->param('m') || undef;
    unless(defined($model_id)) {
        return $self->my_redirect();
    }
    unless(defined($app->session()) && defined($app->session()->user())) {
        return $self->my_redirect("You must login to access this page");
    }
    my $figmodel = $app->data_handle('FIGMODEL');
    $figmodel->authenticate({'cgi' => $cgi}); 
    my $model = $figmodel->get_model($model_id);
    unless(defined($model)) {
        return $self->my_redirect("Could not find model with id '$model_id'! Do you have access to this model?");
    }
    my $rights = $figmodel->database()->get_object_rights($model->ppo(), 'model');
    unless(defined($rights->{'admin'}) or defined($rights->{'edit'})) {
        return $self->my_redirect("You do not have write/admin access to this model!");
    } 
    my $html = $self->model_control_forms();
	return $html;
}

sub model_control_forms {
    my ($self) = @_;
    my $model_id = $self->application()->cgi()->param('m');
    my $html = <<LMTH;
<div id='controls' style='margin: auto; min-width: 800px; width: 70%;'><h2>Model controls for $model_id</h2>
<form class='control' id='gapfill'><fieldset>
<span class='submit_message' style='display: none;'>Queuing additional gapfilling...</span>
<legend>Add additional gapfilling media condictions</legend>
<p>This will trigger gapfilling on the model to grow on the new media conditions. Existing
model constraints will be preserved; this only increases the constraints on a model.</p>
<input class='param' type='hidden' value='$model_id' name='model'/>
<ol>
    <li><label>Media name</label><input class='param' type='text' name='media'/></li>
    <li><label></label><button>Queue gapfilling</button></li>
</ol>
</fieldset></form>
</fieldset>
</form>
<form class='control' id='autocomplete'><fieldset>
<span class='submit_message' style='display: none;'>Queuing model rebuild...</span>
<legend>Re-run autocompletion on new media</legend>
<p>This will remove all existing gapfilling media and completely rebuild
the model using the specified media.</p>
<input class='param' type='hidden' value='$model_id' name='model'/>
<input class='param' type='hidden' value='1' name='deletePrevious'/>
<ol><li><label>Autocompletion media</label><input class='param' type='text' name='media'/></li>
    <li><label></label><button>Queue Reconstruction</button></li>
</ol>
</fieldset>
</form>
<form class='control' id='add_reaction'><fieldset>
<span class='submit_message' style='display: none;'>Adding reaction...</span>
<legend>Add reaction to model</legend>
<input class='param' type='hidden' value='$model_id' name='model'/>
<input class='param' type='hidden' value='json' name='encoding'/>
<ol>
    <li><label>Reaction Id</label><input class='param' type='text' name='reaction'/></li>
    <li><label>Compartment</label><input class='param' type='text' name='compartment' value='c'/></li>
    <li><label>Directionality</label><select class='param' name='directionality'>
        <option value="forward"> =&rang; </option>
        <option value="both"> &lang;=&rang; </option>
        <option value="reverse"> &lang;= </option>
        </select></li>
    <li><label>Peg(s)</label><input class='param' type='text' name='pegs'/></li>
    <li><label>Notes</label><input class='param' type='text' name='note'/></li>
    <li><label></label><button>Add reaction</button></li>
</ol>
</fieldset>
</form>
<form class='control' id='remove_reaction'><fieldset>
<span class='submit_message' style='display: none;'>Removing reaction...</span>
<legend>Remove reaction from model</legend>
<input class='param' type='hidden' value='$model_id' name='model'/>
<input class='param' type='hidden' value='remove_reaction' name='function'/>
<input class='param' type='hidden' value='json' name='encoding'/>
<ol>
    <li><label>Reaction Id</label><input class='param' type='text' name='reaction'/></li>
    <li><label>Compartment</label><input class='param' type='text' name='compartment' value='c'/></li>
    <li><label></label><button>Remove reaction</button>
</ol>
</div>
LMTH
    return $html;
}

sub my_redirect {
    my ($self, $message) = @_;
    my $html = <<LMTH;
<script type='text/javascript'>
        alert("$message");
        window.location.href = 'seedviewer.cgi?page=ModelView';
</script>
LMTH
    return $html;
}

package SeedViewer::WebPage::ModelImport;

use base qw( WebPage );

1;

use strict;
use warnings;
use Tracer;
use URI::Escape;

use FIG_Config;

sub init {
    my ($self) = @_;
    $self->title('Import your model');
    $self->require_javascript_ordered([
         $FIG_Config::cgi_url . '/Html/jquery-1.4.2.min.js',
         $FIG_Config::cgi_url . '/Html/swfobject.js',
         $FIG_Config::cgi_url . '/Html/jquery.uploadify.v2.1.4.js',
         $FIG_Config::cgi_url . '/FIG_Config.cgi',
         $FIG_Config::cgi_url . '/Html/ModelImport.js']);
    $self->require_css_ordered([
         $FIG_Config::cgi_url . '/Html/ModelImport.css']);
    return 1;
}

sub output {
    my ($self) = @_;
    my $app = $self->application();
    my $username = "";
    my $html = <<LMTH;
<form method='POST' enctype='multipart/form-data' id='importForm'>
<fieldset><legend>General Information</legend><ol>
<li>
    <label for='name'>Model Name</label>
    <input class='uparam' type='text' name='name'/>
</li>
<li>
    <label for='id'>Model Id</label>
    <input class='uparam' type='text' name='id'/>
</li>
</ol>
</fieldset>
<fieldset><legend>Upload Files</legend><ol>
<li>
    <label>Upload Format</label>
        <input class='qparam' type='radio' name='format' value='sbml'>SBML</input>
        <input class='qparam' type='radio' name='format' value='tdf'>Tab delimited files</input>
    </label>
</li>
<li class='tdf' id='rxn' style='display:none;'>
    <fieldset>
        <legend> Upload two tab-delimited files: First, a reaction file containing one reaction per line;
        this file includes the biomass objective function(s). This must include the reaction equation.
        Second, a compound file containing the list of compounds.</legend>
        <label><input id='rxnf' class='qparam' type='file' name='rxnf'/></label>
    </fieldset>
</li>
<li class='tdf' id='cpd' style='display:none;'>
    <fieldset>
        <legend> Upload two tab-delimited files: First, a reaction file containing one reaction per line;
        this file includes the biomass objective function(s). This must include the reaction equation.
        Second, a compound file containing the list of compounds.</legend>
        <label><input id='cpdf' class='qparam' type='file' name='rxnf'/></label>
    </fieldset>
</li>
<li class='tdf' id='rxnft' style='display:none;'></li>
<li class='tdf' id='cpdft' style='display:none;'></li>
<li class='sbml' id='sbml' style='display:none;'>
    <fieldset>
        <legend> Upload a SBML file. See <a href='http://sbml.org'>sbml.org</a> for formatting details.
        In order for us to properly identify compounds (species) and reactions, you need to include some
        information with each compound. We can process your model if the compund contains one
        of the following:</br>
        <ul><li>SEED compound ids (e.g. cpd00101)</li>
        <li>KEGG compound ids (e.g. C00101)</li>
        </ul>
        Additionally, we are able to process some compounds simply by their name; however this is
        less accurate. Note that you <em>can</em> upload models with arbitrary compounds and reactions,
        you just won't be able to compare them against other models very well.</br>
        For reactions, we also accept SEED reactions and KEGG reactions (e.g. rxn14000 and R10001).</legend>
        <label><input id='sbmlf' class='qparam' type='file' name='rxnf'/></label>
    </fieldset>
</li>
<li class='sbml' id='sbmlft' style='display:none;'></li>

</ol></fieldset>
<fieldset id='stats' style='display:none;'>
</fieldset>
    
</form>
LMTH
#    $html .= "<form action='http://bioseed.mcs.anl.gov/~devoid/FIG/ModelImport_server.cgi' id='rxnf_form'".
#                " method='POST' enctype='multipart/form-data'><input type='file' name='rxnf'>".
#                "<input type='none' name='function' value='uploadFile'/>".
#                "<input type='none' name='encoding' value='json' /></form>";
    return $html;
}


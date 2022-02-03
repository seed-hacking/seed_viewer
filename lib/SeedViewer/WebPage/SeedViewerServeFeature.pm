package SeedViewer::WebPage::SeedViewerServeFeature;

#
# This file is part of an application created with create-new-page.
# The implementation module is FigKernelScripts/ServFeature.pm.
# The SeedViewer page module is SeedViewer/WebPage/SeedViewerServeFeature.pm.
# The CGI script is FigWebServices/serv_feature.cgi.
#
# The SeedViewer url is http://yourseed/seedviewer.cgi?page=SeedViewerServeFeature
# The CGI url is http://yourseed/serv_feature.cgi
#


use base qw(SimpleWebPage);

use SAPserver;
use Sapling;
use ServFeature;

use strict;
use FIG_Config;

sub page_title
{
    return "My title";
}

sub page_content
{
    my($self, $fig, $cgi, $user_name, $my_url) = @_;


	#my $sapdb = Sapling->new(dbName => 'pubseed_sapling_08', dbhost => 'oak.mcs.anl.gov');
	#my $sap = SAPserver->new(sapDB => $sapdb, url => 'localhost');

	my $sap = SAPserver->new();
	my $sapdb;
    
    my $env = {fig => $fig,
           cgi => $cgi,
           sap => $sap,
           sapdb => $sapdb,
           user => $user_name,
           url => $my_url,
	   hidden_form_var => "<input type='hidden' name='page' value='SeedViewerServeFeature'>",
           seedviewer_page_obj => $self
    };

if ($cgi->param('kb'))
{
    require Bio::KBase::CDMI::CDMIClient;
    my $kbO = Bio::KBase::CDMI::CDMIClient->new_for_script();
    $env->{kbase} = $kbO;
}

     my($html, $title) = ServFeature::run($env);


#    my($html, $title) = ServFeature::run($fig, $cgi, $sap, $user_name, $my_url, "<input type='hidden' name='page' value='SeedViewerServeFeature'>", $self); 

    $self->title($title);
    return $html;
}

1;


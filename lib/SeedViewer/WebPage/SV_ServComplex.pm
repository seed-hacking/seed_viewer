package SeedViewer::WebPage::SV_ServComplex;

#
# This file is part of an application created with create-new-page.
# The implementation module is FigKernelPackages/ServComplex.pm.
# The SeedViewer page module is SeedViewer/WebPage/SV_ServComplex.pm.
# The CGI script is FigWebServices/serv_complex.cgi.
#
# The SeedViewer url is http://yourseed/seedviewer.cgi?page=SV_ServComplex
# The CGI url is http://yourseed/serv_complex.cgi
#


use base qw(SimpleWebPage);

use SAPserver;
use ServComplex;

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
           hidden_form_var => "<input type='hidden' name='page' value='SV_ServComplex'>",
           seedviewer_page_obj => $self
    };

if ($cgi->param('kb'))
{
    require Bio::KBase::CDMI::CDMIClient;
    my $kbO = Bio::KBase::CDMI::CDMIClient->new_for_script();
    $env->{kbase} = $kbO;
}


     my($html, $title) = ServComplex::run($env);
    #my($html, $title) = ServComplex::run($fig, $cgi, $sap, $user_name, $my_url, "<input type='hidden' name='page' value='SV_ServComplex'>", $self);
				       

    $self->title($title);
    return $html;
}

1;


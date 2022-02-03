package SeedViewer::WebPage::SVServIndex;

#
# This file is part of an application created with create-new-page.
# The implementation module is FigKernelPackages/ServIndex.pm.
# The SeedViewer page module is SeedViewer/WebPage/SVServIndex.pm.
# The CGI script is FigWebServices/serv_index.cgi.
#
# The SeedViewer url is http://yourseed/seedviewer.cgi?page=SVServIndex
# The CGI url is http://yourseed/serv_index.cgi
#


use base qw(SimpleWebPage);

use SAPserver;
use ServIndex;

use strict;
use FIG_Config;

sub page_title
{
    return "My title";
}

sub page_content
{
    my($self, $fig, $cgi, $user_name, $my_url) = @_;

    my $sap = SAPserver->new();

    my($html, $title) = ServIndex::run($fig, $cgi, $sap, $user_name, $my_url,
				      "<input type='hidden' name='page' value='SVServIndex'>", $self);
				       

    $self->title($title);
    return $html;
}

1;


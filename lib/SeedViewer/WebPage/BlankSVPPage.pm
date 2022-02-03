
package SeedViewer::WebPage::BlankSVPPage;

use base qw(SimpleWebPage);

use SAPserver;
use BlankSVP;

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

    my($html, $title) = BlankSVP::run($fig, $cgi, $sap, $user_name, $my_url,
				      "<input type='hidden' name='page' value='BlankSVP'>");
				       

    $self->title($title);
    return $html;
}

1;

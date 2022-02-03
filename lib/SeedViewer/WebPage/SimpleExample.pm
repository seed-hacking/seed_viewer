
package SeedViewer::WebPage::SimpleExample;

use base qw(SimpleWebPage);

use strict;
use FIG_Config;

sub page_title
{
    return "My title";
}

sub page_content
{
    my($self, $fig, $cgi, $user_name, $my_url) = @_;

    return "Simple page for $user_name at $my_url\n";
}

1;

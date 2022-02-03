
package SeedViewer::WebPage::SubsystemPrimer;

use base qw(SimpleWebPage);

use strict;
use FIG_Config;
use SubsystemPrimer;

sub page_title
{
    return "Subsystem Request Constructor";
}

sub page_content
{
    my($self, $fig, $cgi, $user_name, $my_url) = @_;

    my $html = SubsystemPrimer::page($cgi, $user_name, $fig, $my_url,
				     "<input type='hidden' name='page' value='SubsystemPrimer'>");
    return join("\n", @$html);
}

1;

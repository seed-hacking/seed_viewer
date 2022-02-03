use strict;
use warnings;
no warnings 'once';

use CGI;
use Tracer;

use FIG_Config;

my $cgi = new CGI;
ETracing($cgi);
my $kegg_base_path = $FIG_Config::kegg || "$FIG_Config::data/KEGG";
$kegg_base_path .= "/pathway/map/";
my $img = "$kegg_base_path/map".$cgi->param('map').".png";
print $cgi->header(-content_type => 'image/png');
Trace("Kegg file at $img.") if T(3);
Open(\*FH, "<$img");
while (<FH>) {
    print;
}
close FH;

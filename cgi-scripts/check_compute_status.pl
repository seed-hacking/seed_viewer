#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#

use strict;
use warnings;

use CGI;
use FIG_Config;

my $cgi = new CGI;
my $org = $cgi->param('org');
my $ref = $cgi->param('ref');
my $cache_dir = $FIG_Config::GenomeComparisonCache ? $FIG_Config::GenomeComparisonCache : "$FIG_Config::temp/GenomeComparisonCache";
if (-s $cache_dir."/".$ref."/".$org) {
    print $cgi->header();
    print $cgi->start_html();
    print "<img src='Html/clear.gif' onload='parent.location.reload(1);'>";
    print $cgi->end_html();
} else {
    print $cgi->header();
    print $cgi->start_html( -head => ["<meta http-equiv=refresh content=30>"] );
    print $cgi->end_html();
}

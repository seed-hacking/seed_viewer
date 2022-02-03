
package SeedViewer::WebPage::AlignTreeViewer;

use base qw( SimpleWebPage );

use strict;

use CGIAlignTreeViewer;
use SAPserver;
use AlignsAndTreesServer;

sub page_title
{
    return "SeedViewer: Alignments and Trees";
}

sub page_content
{
    my( $self, $fig, $cgi, $user, $my_url ) = @_;

    my $sap = SAPserver->new();
    
    my $hidden = qq(<INPUT Type='hidden' Name='page' Value='AlignTreeViewer' />\n);

    local $AlignsAndTreesServer::ReferenceFIG = $fig;
    my( $html, $title ) = CGIAlignTreeViewer::run( $fig, $cgi, $sap, $user, $my_url, $hidden );
				       
    $html ||= "<H2>No HTML returned by page</H2>\n";
    $html   = join( '', @$html ) if ref( $html ) eq 'ARRAY';

    $self->title( $title ) if $title;

    return $html;
}

1;

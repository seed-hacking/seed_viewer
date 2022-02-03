package SeedViewer::WebPage::GoogleResult;

use strict;
use warnings;

use base qw( WebPage );

use URI::Escape;
use SOAP::Lite;

1;

=pod

=head2 NAME

SearchResult - search result page of the SeedViewer

=head2 DESCRIPTION

Displays a search result

=head2 METHODS

=over 4

=item * B<init> ()

Initialise the page

=cut

sub init {
  my $self = shift;

  $self->title('Search Result');
  $self->application->no_bot(1);

}

=pod

=item * B<output> ()

Returns the html output of the SearchResult page.

=cut

sub output {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi();

  my $content = qq~<!-- Google CSE Search Box Begins  -->
<form action="http://seed-viewer.theseed.org/" id="cse-search-box">
  <input type="hidden" name="page" value="GoogleResult" />
  <input type="hidden" name="cx" value="003555725462294590071:8nvkkjaria4" />
  <input type="hidden" name="cof" value="FORID:9" />
  <input type="text" name="q" size="25" />
  <input type="submit" class="button" name="sa" value="Search" />
</form>
<script type="text/javascript" src="http://www.google.com/coop/cse/brand?form=cse-search-box&lang=en"></script>
<!-- Google CSE Search Box Ends -->

<!-- Google Search Result Snippet Begins -->
<div id="cse-search-results"></div>
<script type="text/javascript">
  var googleSearchIframeName = "cse-search-results";
  var googleSearchFormName = "cse-search-box";
  var googleSearchFrameWidth = 600;
  var googleSearchDomain = "www.google.com";
  var googleSearchPath = "/cse";
</script>
<script type="text/javascript" src="http://www.google.com/afsonline/show_afs_search.js"></script>

<!-- Google Search Result Snippet Ends -->
~;
  
  return $content;
}

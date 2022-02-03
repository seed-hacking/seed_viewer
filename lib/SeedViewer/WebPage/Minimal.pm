package SeedViewer::WebPage::Minimal;

use base qw( WebPage );

use FIG_Config;

use URI::Escape;

use strict;
use warnings;

use Time::HiRes 'gettimeofday';
use Sphinx::Search;
use SeedSearch;
use ANNOserver;
use Tracer;
use HTML;
use FFs;
use FIGRules;
use SeedViewer::SeedViewer;
use SAPserver;

use Data::Dumper;
use FreezeThaw qw( freeze thaw );

1;

=pod

=head1 NAME

Find - find stuff.

=head1 DESCRIPTION

Find stuff. Quickly.

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instantiated.

=cut

sub init {
  my ($self) = @_;

  $self->title('The SEED');

  return 1;
}

=item * B<output> ()

Returns the html output of the Annotation page.

=cut

sub output {
    my ($self) = @_;
    
    my $application = $self->application;
    my $cgi = $application->cgi;

    my $banner = $FIG_Config::seedviewer_banner || "Welcome to the SEED";
    my $html = <<END;
<div style="text-align: center">
<h2>$banner</h2>
<p>Type a search string:</p>
<form name="search" method="POST">
<input type="hidden" name="act" value="do_search">
<input type="hidden" name="page" value="Find">
<input type="text" size="100" name="pattern" value="">
<br>
<input type="submit" name="submit" value="Search">
</form>
</div>
END

  return $html;
}


1;

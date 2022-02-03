package SeedViewer::WebPage::PGHome;

use base qw( WebPage );

use FIG_Config;

use URI::Escape;

use strict;
use warnings;

use gjocolorlib;
use Tracer;
use HTML;
use FFs;
use FIGRules;
use SeedViewer::SeedViewer;
use Cwd 'abs_path';
use PG;
use Template;

use Data::Dumper;
use FreezeThaw qw( freeze thaw );

1;

=pod

=head1 NAME

PGHome - top page for the pangenera stff.

=head1 DESCRIPTION

View the available PG data sets and tools.

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instantiated.

=cut


sub init {
  my ($self) = @_;
  
  $self->title('Pangenome Datasets');

  return 1;
}

=item * B<output> ()

Returns the html output of the Annotation page.

=cut

sub output {
    my ($self) = @_;
    
    my $application = $self->application;
    my $cgi = $application->cgi;

    my $template = Template->new({  ABSOLUTE => 1 } );

    my @datasets = PG->get_available_datasets();

    my %vars;

    my $sets = [];
    $vars{datasets} = $sets;

    my @targets = (["Inconsistent Families (all roles)", "PGInconsistentFamilies2"],
		   ["Inconsistent Families (only roles in models)", "PGInconsistentFamilies2", ["model_only=1"]]);

    my @sr_targets = (["Solid Rectangles (all roles)", "PGInconsistentFamilies2", ["sr_mode=1"]],
		      ["Solid Rectangles (only roles in models roles)", "PGInconsistentFamilies2", ["sr_mode=1", "model_only=1"]]);
    
    for my $ds (@datasets)
    {
	my($name, $dir, $sr) = @$ds;

	my $base_url = $self->application->url;

	my $tlist = $sr eq 'SR' ? \@sr_targets : \@targets;

	my $links = [];
	for my $targ (@$tlist)
	{
	    my($label, $page, $params) = @$targ;
	    my $url = "$base_url?page=$page&pgname=$name";
	    if ($params && @$params)
	    {
		$url .= "&" . join("&", @$params);
	    }
	    push @$links, { url => $url, text => $label };
	}
	
	push @$sets, { name => $name, dir => $dir, links => $links };

    }

    my $output;

    my $tfile = "$FIG_Config::fig/CGI/Html/PGHome.tt2";
    if (!$template->process($tfile, \%vars, \$output) )
    {
	$output = $template->error;
    }

    return $output;
}

sub mk_link
{
    my($self, $fid) = @_;
    return $self->application->url . "?page=Annotation&feature=$fid";
}

1;

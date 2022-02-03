package SeedViewer::WebPage::PGViewFamilySet;

use base qw( WebPage );

use FIG_Config;

use URI::Escape;

use strict;
use warnings;

use ANNOserver;
use Tracer;
use HTML;
use FFs;
use FIGRules;
use SeedViewer::SeedViewer;
use Cwd 'abs_path';

use Data::Dumper;
use FreezeThaw qw( freeze thaw );

1;

=pod

=head1 NAME

PGViewFamilySet - view a set of pangenome families.

=head1 DESCRIPTION

View a pangenome family.

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instantiated.

=cut

sub init {
  my ($self) = @_;
  
  $self->title('Pangenome Family');
  $self->application->register_component('RegionDisplay','ComparedRegions');
  $self->application->register_component('Ajax', 'ComparedRegionsAjax');

  return 1;
}

=item * B<output> ()

Returns the html output of the Annotation page.

=cut

sub output {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;

  my $html = '';

  my $fam_dir = "/vol/ross/BrucellaPanGenome/Data";

  my $file = $cgi->param('set_file');
  
  #
  # Read the newick tree to get order of genomes.
  #
  my @genomes;
  if (open(my $fh, "<", "$fam_dir/phylo.nwk"))
  {
      while (<>)
      {
	  my(@g) = /[\(,]\s+(\d+\.\d+):/g;
	  push(@genomes, @g);
      }
  }

  my $path = abs_path("$fam_dir/$file");
  if ($path !~ /^$fam_dir/)
  {
      return "bad path";
  }

  my $data = [];
  if (open(my $fh, "<", "$fam_dir/$file"))
  {
      while (<$fh>)
      {
	  chomp;
	  my($fam, $peg, $fn) = split(/\t/);
      }
  }

  return $self->show_family($fam_dir, $fam, $core_flag);
}

sub show_family
{
    my($self, $fam_dir, $fam, $core_flag) = @_;

    my $file = $core_flag ? "core.families.with.function" : "families.with.function";
    open(my $fh, "$fam_dir/$file") or return "Family $fam not found in $file";

    my @members;
    while (<$fh>)
    {
	chomp;
	my($id, $peg, $fn) = split(/\t/);
	if ($id eq $fam)
	{
	    my $org = FIG::genome_of($peg);
	    push(@members, [$peg, $fn, $org]);
	}
	else
	{
	    last if @members;
	}
    }
    close($fh);

    $self->application->cgi->param('organism', map { $_->[2] } @members);
    my $fig = $self->application->data_handle('FIG');

    my $hdrs = ["Peg", "Function"];
    my @tbl;
    my $u = $self->application->url;

    for my $m (@members)
    {
	my($peg, $fn) = @$m;
	my $l = $self->mk_link($peg);
	push(@tbl, [qq(<a href="$l">$peg</a>), $fn]);
    }
    my $nextid = $fam + 1;
    my $previd = $fam - 1;
    my($next, $prev) = ("", "");
    $next = "<a href='$u?page=PGViewFamily&family=$nextid&core=$core_flag'>next family ($nextid)</a>";
    if ($previd > 0)
    {
	$prev = "<a href='$u?page=PGViewFamily&family=$previd&core=$core_flag'>previous family ($previd)</a>";
    }
	

    my $tbl = &HTML::make_table($hdrs, \@tbl, "$prev | Features in family | $next");

    my $html = $tbl;

    $html .= $self->application->component('ComparedRegionsAjax')->output();

    my $args = join("&",
		    (map { ("feature=$_->[0]", "organism=$_->[2]") } @members),
		    'color_by_function=1');

    $html .= "<br /><div id='cr'><img src=\"$FIG_Config::cgi_url/Html/clear.gif\" onload='execute_ajax(\"compared_region\", \"cr\", \"$args\");'></div><br>";

    # my $reg = $self->compared_region(\@members);

    return $html;
}

sub mk_link
{
    my($self, $fid) = @_;
    return $self->application->url . "?page=Annotation&feature=$fid";
}

sub compared_region {
  my ($self, $members) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;

  my $fig = $application->data_handle('FIG');

  my $cr = $application->component('ComparedRegions');
  $cr->line_select(1);
  $cr->fig($fig);

#  my $pegs = [map { $_->[0] } @$members];
#  $cgi->param('color_by_function', 1);
#  $cgi->param(-name => 'feature', -value => $pegs);
  my $o = $cr->output();

  return $o;
}


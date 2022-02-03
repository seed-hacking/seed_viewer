package SeedViewer::WebPage::PGViewPubs;

use base qw( WebPage );

use FIG_Config;

use URI::Escape;
use IPC::Run;

use strict;
use warnings;

use gjocolorlib;
use Tracer;
use HTML;
use FFs;
use FIGRules;
use SeedViewer::SeedViewer;
use Cwd 'abs_path';
use DBrtns;

use Data::Dumper;
use FreezeThaw qw( freeze thaw );

1;

=pod

=head1 NAME

PGViewPubs - view a set of pangenome families.

=head1 DESCRIPTION

View a pangenome family.

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instantiated.

=cut

my @colors= qw(LightBlue LightCoral Lime MintCream Teal YellowGreen Goldenrod);

our $anno_db;

sub init {
  my ($self) = @_;
  
  $self->title('Pangenome Inconstent Role');
  $self->application->register_component('Table', 'FamilyTable');
  $self->application->register_component('RegionDisplay','ComparedRegions');
  $self->application->register_component('Ajax', 'ComparedRegionsAjax');

  my $fam_dir = "/vol/ross/BrucellaPanGenome/Data";
  $self->{fam_dir} = $fam_dir;
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

    #
    # Read the anno seed file so we know which are the annotator seed genomes,
    # for use in creating links.
    #
    my %anno;
    if (open(my $fh, "<", "$fam_dir/anno.seed"))
    {
	while (<$fh>)
	{
	    chomp;
	    $anno{$_} = 1;
	}
	close($fh);
    }
    $self->{anno} = \%anno;

    my %gorder;
    my @gorder;
    {
	if(open(G, "<", "$fam_dir/phylo.nwk"))
	{
	    my $i = 0;
	    while (<G>)
	    {
		foreach my $g (/[\(,]\s+(\d+\.\d+):/g)
		{
		    $gorder{$g} = $i++;
		    push(@gorder, $g);
		}
	    }
	    close(G);
	}
	else
	{
	    open(G, "<", "$fam_dir/genomes.with.job.and.genomeID");
	    my $i = 0;
	    while (<G>)
	    {
		chomp;
		my($name, $src, $job, $g) = split(/\t/);
		$gorder{$g} = $i++;
		push(@gorder, $g);
	    }
	    close(G);
	}
    }

    $cgi->param('organism',  @gorder);
    print STDERR "Set up orgs\n";
    my $fig = $self->application->data_handle('FIG');

    my @tbl;

    my $fh;
    open($fh, "<", "$fam_dir/publications");
    while (<$fh>)
    {
	chomp;
	my($name, $locus, $pegs, $desc, $pmid) = split(/\t/);

	my @pegs = split(/,/, $pegs);

	my $fam_url = $self->application->url . "?page=PGInconsistentFamily&peg=" . uri_escape($pegs[0]);

	my $ps = "<table>\n";
	for my $p (@pegs)
	{
	    my $l = $self->mk_peg_link($p, 1);
	    my $f = $fig->function_of($p);
	    $ps .= "<tr><td>$l</td><td>$f</td></tr>\n";
	}
	$ps .= "</table>\n";
	
	push(@tbl, ["<a target='_blank' href='$fam_url'>$name</a>",
		    "<a target='_blank' href='http://www.ncbi.nlm.nih.gov/gene/?term=$locus'>$locus</a>",
		    "<a target='_blank' href='http://www.ncbi.nlm.nih.gov/pubmed/?term=$pmid'>$pmid</a>",
		    $ps]);
    }
    my $table = $self->application->component("FamilyTable");
    $table->columns([{ name => 'Name' },
		 { name => 'Locus' },
		 { name => 'Pubmed' },
		 { name => 'Pegs' }]);
    $table->data(\@tbl);

    return $table->output;
		    
    #return HTML::make_table(["Index", "Peg1", "Func1", "Peg2", "Func2", "Role", "SS"], \@tbl);
}
    

sub find_families_with_pegs
{
    my($self, $fam_dir, @pegs) = @_;

    my %pegs = map { $_ => 1 } @pegs;

    my %matches;
    open(F, "<", "$fam_dir/protein.families") or die "cannot open $fam_dir/protein.families: $!";
    
    while (<F>)
    {
	chomp;
	my @fpegs = split(/\t/);

	for my $fpeg (@fpegs)
	{
	    if ($pegs{$fpeg})
	    {
		push(@{$matches{$fpeg}}, [$., \@fpegs]);
	    }
	}
    }

    return \%matches;
}

sub mk_link
{
    my($txt, $url, $newpage) = @_;
    my $t = $newpage ? "target='_blank'" : "";
    return "<a $t href='$url'>$txt</a>";
}

sub mk_peg_link
{
    my($self, $peg, $newpage) = @_;
    my $u;
    if ($self->{anno}->{FIG::genome_of($peg)})
    {
	$u = $self->mk_anno_url($peg);
    }
    else
    {
	$u = $self->mk_rast_url($peg);
    }
    return mk_link($peg, $u, $newpage);
}

sub mk_anno_url
{
    my($self, $fid) = @_;
    my $l = "http://anno-3.nmpdr.org/anno/FIG/seedviewer.cgi?page=Annotation&feature=$fid";
    return$ l;
}

sub mk_rast_url
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

  my $html = '';

#  $html .= '<script type="text/javascript" src="scripts/jquery.imagemapster.js"><script>';
#  $html .= q($('img').mapster(););

  my $o = $cr->output();

  $html .= $o;

  return $html;
}

sub anno_function_of
{
    my($self, $fid) = @_;
    if (!$anno_db)
    {
	$anno_db = DBrtns->new("mysql", "fig_anno_v5", "seed", undef, undef, "seed-db-read.mcs.anl.gov");
    }
    my $res = $anno_db->SQL("select assigned_function FROM assigned_functions WHERE prot = ?", undef,
			    $fid);
    if (@$res)
    {
	return $res->[0]->[0];
    }
    return undef;
}

1;

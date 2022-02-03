package SeedViewer::WebPage::PGInconsistentFamilies;

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

use Data::Dumper;
use FreezeThaw qw( freeze thaw );

1;

=pod

=head1 NAME

PGInconsistentFamilies - view a set of pangenome families.

=head1 DESCRIPTION

View a pangenome family.

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instantiated.

=cut

my @colors= qw(LightBlue LightCoral Lime MintCream Teal YellowGreen Goldenrod);

our $md5_to_peg;
our $md5_to_anno_peg;
our $peg_to_md5;

sub init {
  my ($self) = @_;
  
  $self->title('Pangenome Family');
  $self->application->register_component('Table', 'FamilyTable');

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
    $self->{fam_dir} = $fam_dir;
    
    my $jobs = "/vol/rast-prod/jobs";
    
    my %gorder;
    my @gorder;
    {
	if (open(G, "<", "$fam_dir/phylo.nwk"))
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

    my(@anno, %anno);
    open(A, "<", "$fam_dir/anno.seed");
    while (<A>)
    {
	if (/(\d+\.\d+)/)
	{
	    $anno{$1} = 1;
	    push(@anno, $1);
	}
    }
    close(A);

    #
    # Read in the md5 data.
    #
    if (!defined($md5_to_peg))
    {
	$md5_to_peg = {};
	$md5_to_anno_peg = {};
	$peg_to_md5 = {};

	open(F, "<", "$fam_dir/md5sums") or return "Cannot open $fam_dir/md5sums: $!";
	while (<F>)
	{
	    chomp;
	    my($peg, $md5) = split(/\t/);
	    $peg_to_md5->{$peg} = $md5;
	    push(@{$md5_to_peg->{$md5}}, $peg);
	    if ($peg =~ /^fig\|(\d+\.\d+)/ && $anno{$1})
	    {
		push(@{$md5_to_anno_peg->{$md5}}, $peg);
	    }
	}
	close(F);
    }


    #
    # Read role inconsistencies.
    #
    
    my %inconsistent_roles;
    if (open(R, "<", "$fam_dir/role.inconsistencies"))
    {
	while (<R>)
	{
	    chomp;
	    my($d_peg1, $d_func1, $d_peg2, $d_func2, $d_anno, $d_role, $d_ss) = split(/\t/);
	    $inconsistent_roles{$d_role}++;
	}
	close(R);
    }

    my $model_only = $self->application->cgi->param("model_only");

    my $model_roles = {};

    if (open(RF, "<", "$self->{fam_dir}/roles.used.in.models"))
    {
	while (<RF>)
	{
	    chomp;
	    $model_roles->{$_} = 1;
	}
	close(RF);
    }
    else
    {
	print STDERR "Cannot open $self->{fam_dir}/roles.used.in.models: $!\n";
    }

    $self->application->cgi->param('organism',  @gorder);
    my $fig = $self->application->data_handle('FIG');

    open(F, "<", "$fam_dir/protein.families") or die "cannot open $fam_dir/protein.families: $!";
    
    my @set;
    
    my $n_families = 0;
    my $n_inconsistent_families = 0;
    my $n_pegs = 0;
    my $n_pegs_in_inconsistent_families = 0;
    while (<F>)
    {
	chomp;
	my @pegs = split(/\t/);
	my @npegs;
	for my $peg (@pegs)
	{
	    if ($fig->is_real_feature($peg))
	    {
		push(@npegs, $peg);
	    }
	}
	@pegs = @npegs;
#	print STDERR Dumper(1, \@pegs);
#	@pegs = grep { my $ok = $fig->is_real_feature($_); print STDERR "$_ ok=$ok\n"; $ok } @pegs;
#	print STDERR Dumper(2, \@pegs);
	
	#
	# Find any annotator seed genome pegs that correspond to the
	# pegs in this family.
	#
	my %a;
	my $peg_to_link = $pegs[0];
	for my $peg (@pegs)
	{
	    my $md5 = $peg_to_md5->{$peg};
	    if (my $l = $md5_to_anno_peg->{$md5})
	    {
		$a{$_} = 1 foreach @$l;
	    }
	}
	my @only_family_pegs = @pegs;
	# print STDERR Dumper($., \@pegs, \%a);
	push(@pegs, keys %a);

	my $func_tbl = $fig->function_of_bulk(\@pegs);

	my @fns = map { [$_, $func_tbl->{$_}] } @pegs;
	my @fam_fns = map { [$_, $func_tbl->{$_}] } @only_family_pegs;
	my @mr = ();
        {
	    my %roles = map { $_ => 1 } map { SeedUtils::roles_of_function($_->[1]) } @fns;
	    @mr = grep { $model_roles->{$_} } keys %roles;
	}
	if ($model_only)
	{
	    next unless @mr;
	}
	    
	$n_families++;
	$n_pegs += @pegs;
	
	my %fns;
	if (1 || $cgi->param('no_comments'))
	{
	    $_->[1] =~ s/\s*\#.*$// foreach @fns;
	}
	$fns{$_->[1]}++ foreach @fns;
	my $n = keys %fns;
	my %fam_fns;
	$fam_fns{$_->[1]}++ foreach @fam_fns;
	my $n = keys %fns;
	my $nf = keys %fam_fns;
	my $consistent_only = $cgi->param('consistent');
	if (($consistent_only && $nf == 1) ||
	    (!$consistent_only && $nf > 1))
	{
	    my %byg;
	    for my $e (@fns)
	    {
		my($g) = $e->[0] =~ /^fig\|(\d+\.\d+)/;
		if (!defined($g))
		{
		    warn "no g: " . Dumper($e, \@pegs);
		}
		$byg{$g} = $e;
		push(@$e, $g);
	    }

	    push(@set, [$n, \@fns, \%byg, \%fns, [@mr], $peg_to_link]);

	    $n_inconsistent_families++;
	    $n_pegs_in_inconsistent_families += @pegs;
	}
    }

    @set = sort { @{$b->[1]} <=> @{$a->[1]} or $b->[0] <=> $a->[0]  } @set;
#    @set = sort { $b->[0] <=> $a->[0] or @{$b->[1]} <=> @{$a->[1]} } @set;

    my @tbl;
    for my $i (0..$#set)
    {
	my $e = $set[$i];
	my($n, $fns, $byg, $fnsH, $model_roles) = @$e;

	my @fns = sort { $fnsH->{$b} <=> $fnsH->{$a} } keys %$fnsH;
	my %fidx;
	my %roles;
	for my $i (0..$#fns)
	{
	    my $fn = $fns[$i];
	    $roles{$_} = 1 foreach grep { $inconsistent_roles{$_} } SeedUtils::roles_of_function($fn);
	    $fidx{$fns[$i]} = $i;
	}

	my @l;
	my $peg_to_link;
	for my $g (@gorder, @anno)
	{
	    my $v = "";
	    if (my $e = $byg->{$g})
	    {
		my($peg, $fn) = @$e;
		my($n) = $peg =~ /(\d+)$/;

		$peg_to_link = $peg unless defined $peg_to_link;

		my $color = $colors[$fidx{$fn}];
		my($r,$g,$b) = gjocolorlib::html2rgb($color);
		$r = int(255 * $r);
		$g = int(255 * $g);
		$b = int(255 * $b);
		my $cstr = "rgb($r,$g,$b)";

		my $u = $self->mk_link($peg);
		my $l = "<a target='_blank' href='$u'>$n</a>";
		$v = { data => $l, tooltip => $fn, highlight => $cstr };
	    }
	    push(@l, $v);
	}


	#
	# Notion of next and prev is difficult to compute on the PGInconsistentFamily page,
	# which where it really needs to go.
	# my($fam_next, $fam_prev);
	# if ($i > 0)
	# {
	#     $fam_prev = uri_escape($set[$i-1]->[5]);
	# }
	# if ($i < $#set)
	# {
	#     $fam_next = uri_escape($set[$i+1]->[5]);
	# }
	     
	my $show_fam = $application->url . "?page=PGInconsistentFamily&peg=" . uri_escape($peg_to_link);
#	$show_fam .= "&next_peg=$fam_next" if $fam_next;
#	$show_fam .= "&prev_peg=$fam_prev" if $fam_prev;
	push(@l, "<a href='$show_fam' target='_blank'>View family</a>");
	
	my @rlist;
	for my $r (sort keys %roles)
	{
	    my $rurl = $application->url . "?page=PGInconsistentRole&role=" . uri_escape($r);
	    push(@rlist, "<a href='$rurl' target='_blank'>$r</a>");
	}
	push(@l, join(" ", @rlist));
	push(@l, join(" ", (ref($model_roles) ? @$model_roles : ())));

	push(@tbl, \@l);
    }
    my $table = $application->component("FamilyTable");
    my @cols;
    my @all = (@gorder, @anno);
    for my $i (0..$#all)
    {
	my $g = $all[$i];
	my $gs = $fig->genus_species($g);
	push(@cols, { name => ($i + 1), tooltip => "$g<br>$gs" });
    }
    push(@cols, { name => 'Action' });
    push(@cols, { name => 'Inconsistent Roles' });
    push(@cols, { name => 'Model Roles' });

    $table->columns(\@cols);
    $table->data(\@tbl);

    $html .= "$n_families families containing $n_pegs pegs<br>\n";
    $html .= "$n_inconsistent_families inconsistent families containing $n_pegs_in_inconsistent_families pegs<p>\n";

    $html .= $table->output();
    return $html;
}

sub mk_link
{
    my($self, $fid) = @_;
    return $self->application->url . "?page=Annotation&feature=$fid";
}

1;

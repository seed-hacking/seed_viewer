package SeedViewer::WebPage::PGInconsistentFamilies3;

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
use PG;

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

    my $pgname = $cgi->param("pgname");
    $self->{pgname} = $pgname;
    my $pg = PG->new_from_name($pgname);
    if (!$pg)
    {
	return "PG set name $pgname not found";
    }
    my $fam_dir = $pg->{dir};
    $self->{fam_dir} = $fam_dir;

    my @anno = $pg->anno_genomes();
    my %anno = map { $_ => 1 } @anno;

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
    $self->{inconsistent_roles} = \%inconsistent_roles;

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
    $self->{model_roles} = $model_roles;

    my @gorder = $pg->genomes;
    $self->{gorder} = \@gorder;
    $self->application->cgi->param('organism',  $pg->rast_genomes);
    my $fig = $self->application->data_handle('FIG');

    open(F, "<", "$fam_dir/protein.families") or die "cannot open $fam_dir/protein.families: $!";

    my $sr_mode = $cgi->param("sr_mode");
    my $func_tbl;
    
    if ($sr_mode)
    {
	my(@rows, @all_fids);
	local $/ = "\n\n";
	my %all;
	while (<F>)
	{
	    chomp;
	    my @lines = split(/\n/);
	    my @pegs = map { split(/\t/) } @lines;
	    $all{$_}++ foreach @pegs;
	    push @rows, join("\t", @pegs);
	}
	close(F);
	my $dat = join("\n", @rows, '');
	open(F, "<", \$dat);

	$func_tbl = $pg->function_of_bulk([keys %all]);
    }
    else
    {
	my $func_tbl = $pg->load_funcs();
    }
    
    my($n_families, $n_inconsistent_families, $n_pegs, $n_pegs_in_inconsistent_families, $sets)
	= $self->load_families($pg, \*F, $func_tbl, $model_only);
    
    close(F);
    
    my $tbl = $self->populate_table($pg, $sets);
    
    my $table = $application->component("FamilyTable");
    my @cols;
    my @all = (@gorder);
    for my $i (0..$#all)
    {
	my $g = $all[$i];
	my $gs = $pg->genus_species($g);
	push(@cols, { name => ($i + 1), tooltip => "$g<br>$gs" });
    }
    push(@cols, { name => 'Action' });
    push(@cols, { name => 'Inconsistent Roles' });
    push(@cols, { name => 'Model Roles' });
    
    $table->columns(\@cols);
    $table->data($tbl);
    
    $html .= "$n_families families containing $n_pegs pegs<br>\n";
    $html .= "$n_inconsistent_families inconsistent families containing $n_pegs_in_inconsistent_families pegs<p>\n";
	
    $html .= $table->output();

    return $html;
}

sub load_families
{
    my($self, $pg, $fh, $func_tbl, $model_only) = @_;

    my $cgi = $self->application->cgi;

    my $n_families = 0;
    my $n_inconsistent_families = 0;
    my $n_pegs = 0;
    my $n_pegs_in_inconsistent_families = 0;

    my @set;
    while (<$fh>)
    {
	chomp;
	my @pegs = split(/\t/);
	@pegs = grep { $pg->is_real_feature($_); } @pegs;

	print STDERR "PEGS=@pegs\n";
	
	my @fns = map { [$_, $func_tbl->{$_}] } @pegs;

	my @mr = ();
        {
	    my %roles = map { $_ => 1 } map { SeedUtils::roles_of_function($_->[1]) } @fns;
	    @mr = grep { $self->{model_roles}->{$_} } keys %roles;
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
	my $consistent_only = $cgi->param('consistent');
	if (($consistent_only && $n == 1) ||
	    (!$consistent_only && $n > 1))
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

	    push(@set, [$n, \@fns, \%byg, \%fns, [@mr], $pegs[0]]);

	    $n_inconsistent_families++;
	    $n_pegs_in_inconsistent_families += @pegs;
	}
    }

    @set = sort { keys %{$b->[2]} <=> keys %{$a->[2]} or $b->[0] <=> $a->[0]  } @set;
#    @set = sort { @{$b->[1]} <=> @{$a->[1]} or $b->[0] <=> $a->[0]  } @set;
#    @set = sort { $b->[0] <=> $a->[0] or @{$b->[1]} <=> @{$a->[1]} } @set;

#    print STDERR Dumper(\@set);

    return($n_families, $n_inconsistent_families, $n_pegs, $n_pegs_in_inconsistent_families, \@set);
}

sub populate_table
{
    my($self, $pg, $set) = @_;

    my @tbl;
    for my $i (0..$#$set)
    {
	my $e = $set->[$i];
	my($n, $fns, $byg, $fnsH, $model_roles) = @$e;

	my @fns = sort { $fnsH->{$b} <=> $fnsH->{$a} } keys %$fnsH;
	my %fidx;
	my %roles;
	for my $i (0..$#fns)
	{
	    my $fn = $fns[$i];
	    $roles{$_} = 1 foreach grep { $self->{inconsistent_roles}->{$_} } SeedUtils::roles_of_function($fn);
	    $fidx{$fns[$i]} = $i;
	}

	my @l;
	my $peg_to_link;
	for my $g (@{$self->{gorder}})
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

		my $u = $pg->mk_link($self->application, $peg);
		my $l = "<a target='_blank' href='$u'>$n</a>";
		$v = { data => $l, tooltip => $fn, highlight => $cstr };
	    }
	    push(@l, $v);
	}

	     
	my $show_fam = $self->application->url . "?page=PGInconsistentFamily2&peg=" . uri_escape($peg_to_link) . "&pgname=$self->{pgname}";
	push(@l, "<a href='$show_fam' target='_blank'>View family</a>");
	
	my @rlist;
	for my $r (sort keys %roles)
	{
	    my $rurl = $self->application->url . "?page=PGInconsistentRole&role=" . uri_escape($r);
	    push(@rlist, "<a href='$rurl' target='_blank'>$r</a>");
	}
	push(@l, join(" ", @rlist));
	push(@l, join(" ", (ref($model_roles) ? @$model_roles : ())));

	push(@tbl, \@l);
    }
    return \@tbl;
}

sub mk_link
{
    my($self, $fid) = @_;
    return $self->application->url . "?page=Annotation&feature=$fid";
}

1;

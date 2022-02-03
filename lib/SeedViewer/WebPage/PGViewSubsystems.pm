package SeedViewer::WebPage::PGViewSubsystems;

use base qw( WebPage );

use FIG_Config;

use URI::Escape;

use strict;
use warnings;

use File::Slurp 'read_file';
use JSON::XS;
use ANNOserver;
use Tracer;
use HTML;
use FFs;
use FIGRules;
use SeedViewer::SeedViewer;

use Data::Dumper;
use FreezeThaw qw( freeze thaw );

1;

=pod

=head1 NAME

PGViewSubsystems - view a pangenome family.

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
  $self->application->register_component('Table', 'SSTable');

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

    my $base_intensity = 80;
    my $intensity_step = int((255 - $base_intensity) / @gorder);
  
    $cgi->param('organism',  @gorder);
    print STDERR "Set up orgs\n";
    my $fig = $self->application->data_handle('FIG');
    my %anno;
    my @anno;
    if (open(my $fh, "<", "$fam_dir/anno.seed"))
    {
	while (<$fh>)
	{
	    if (/(\d+\.\d+)/)
	    {
		$anno{$1} = 1;
		push(@anno, $1);
	    }
	}
	close($fh);
    }
    $self->{anno} = \%anno;

  my @all_genomes = (@gorder, @anno);
  my %all_genomes;
  $all_genomes{$all_genomes[$_]} = $_ foreach 0..$#all_genomes;

  if (!open(S, "<", "$fam_dir/subsystem.data"))
  {
      return "Cannot open subsystem data file.";
  }

  my $ss_data = decode_json(read_file(\*S));

  my $hdrs = ['Subsystem',
	      'Role',
	      'U',
	      'A',
	      '#',
	      1..($#all_genomes+1)
	      ];

  my @cols = (
	  { name => "Subsystem", sortable => 1, filter => 1},
	  { name => "Role", sortable => 1, filter => 1},
	  { name => "U", sortable => 1, filter => 1, tooltip => "Usable" },
	  { name => "A", sortable => 1, filter => 1, tooltip => "Auxiliary" });
  for my $i (0..$#all_genomes)
  {
      my $g = $all_genomes[$i];
      my $gs = $fig->genus_species($g);
      my $nm = $i + 1;
      $nm = "0$nm" if $nm < 10;
      push @cols, { name => "$nm", tooltip => "$g<br>$gs", width => "2em" };
  }
	      
  my $table = $application->component("SSTable");
  $table->columns(\@cols);

  my @rows;

  #
  # Load the inconsistent role list for use in making links.
  #

  my %inconsistent;
  if (open(my $rfh, "<", "$fam_dir/role.inconsistencies"))
  {
      while (<$rfh>)
      {
	  chomp;
	  my($p1, $f1, $p2, $f2, $an, $ir,$is) = split(/\t/);
	  $inconsistent{$ir,$is}++;
      }
      close($rfh);
  }

  #
  # Load protein family data, for hovers on pegs.
  #
  my %peg_to_fam;
  if (open(my $rfh, "<", "$fam_dir/protein.families"))
  {
      while (<$rfh>)
      {
	  chomp;
	  my @pegs = split(/\t/);
	  $peg_to_fam{$_} = $. foreach @pegs;
      }
      close($rfh);
  }

  $table->data(\@rows);

  for my $ss (sort keys %$ss_data)
  {
      my $h = $ss_data->{$ss};
      my $usable = $h->{usable};
      my $aux = $h->{aux_roles};

      next unless $usable;

      for my $role (sort keys %{$h->{roles}})
      {
	  my $ssh = $ss;
	  $ssh =~ s/_/ /g;

	  my $rlink = $role;
	  if ($inconsistent{$role, $ss})
	  {
	      my $rurl = $self->application->url . "?page=PGInconsistentRole&role=" . uri_escape($role);
	      $rlink = "<a target='_blank' href='$rurl'>$role</a>";
	  }
	  my $row = [$ssh, $rlink, $usable, ($aux->{$role} ? 1 : 0)];

	  my %fams;
	  for my $peg (@{$h->{roles}->{$role}})
	  {
	      my $fam = $peg_to_fam{$peg};
	      $fams{$fam}++ if defined($fam);
	  }
	  for my $peg (@{$h->{roles}->{$role}})
	  {
	      my $g = FIG::genome_of($peg);
	      my $idx = 4 + $all_genomes{$g};
	      my @tt = ();

	      my $int = $base_intensity;
	      my $fam = $peg_to_fam{$peg};
	      if ($fam)
	      {
		  $int += $fams{$fam} * $intensity_step;
		  @tt = (tooltip => $fam);
	      }
	      else
	      {
		  @tt = (tooltip => 'No fam');
	      }
	      my $color = $anno{$g} ? "rgb(0,0,200)" : "rgb(0,$int,0)";

	      if (defined($row->[$idx]) && $row->[$idx]->{highlight} ne 'rgb(0,0,0)')
	      {
		  $color = 'rgb(200,200,0)';
	      }
	      $row->[$idx] = { data => "&nbsp;", highlight => $color, @tt };
	      
	      # my $l = $self->mk_short_peg_link($peg);
	      # if ($row->[$idx] ne '')
	      # {
	      # 	  $row->[$idx] .= "<br>$l";
	      # }
	      # else
	      # {
	      # 	  $row->[$idx] = $l;
	      # }
	  }
	  push(@rows, $row);
      }
  }
  
  $html .= $table->output();

  return $html;
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

sub mk_short_peg_link
{
    my($self, $peg, $newpage) = @_;
    my $u;
    my($n) = $peg  =~ /\.peg\.(\d+)/;
    if ($self->{anno}->{FIG::genome_of($peg)})
    {
	$u = $self->mk_anno_url($peg);
    }
    else
    {
	$u = $self->mk_rast_url($peg);
    }
    return mk_link($n, $u, $newpage);
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

package SeedViewer::WebPage::AtomicRegulon;

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

use Data::Dumper;
use FreezeThaw qw( freeze thaw );

1;

=pod

=head1 NAME

AtomicRegulon - an instance of WebPage which displays information about an atomic regulon.

=head1 DESCRIPTION

Display information about an atomic regulon.

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;
  
  $self->title('Atomic Regulon');
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
  my $fig = $application->data_handle('FIG');

  # check if we have a valid fig
  unless ($fig) {
    $application->add_message('warning', 'Invalid organism id');
    return "";
  }

  my $id = $cgi->param('feature');
  my $reg = $cgi->param('regulon');
  my $reg_genome = $cgi->param("genome");

  if ($reg_genome !~ /^(all|(\d+\.\d+))$/)
  {
      $application->add_message('warning', 'Invalid organism id');
      return "";
  }

  my $org;
  if ($id)
  {
      $org = $fig->genome_of($id);
  }
  else
  {
      $org = $reg_genome;
  }

  # create menu

  if ($org =~ /^\d+\.\d+$/)
  {
      $application->menu->add_category('&raquo;Organism');
      $application->menu->add_entry('&raquo;Organism', 'General Information', '?page=Organism&organism='.$org);
      $application->menu->add_entry('&raquo;Organism', 'Feature Table', '?page=BrowseGenome&tabular=1&organism='.$org);
      $application->menu->add_entry('&raquo;Organism', 'Genome Browser', '?page=BrowseGenome&organism='.$org);
      $application->menu->add_entry('&raquo;Organism', 'Scenarios', '?page=Scenarios&organism='.$org);
      $application->menu->add_entry('&raquo;Organism', 'Subsystems', '?page=SubsystemSelect&organism='.$org);
      $application->menu->add_entry('&raquo;Organism', 'Atomic Regulons', '?page=AtomicRegulon&regulon=all&genome='.$org);
      $application->menu->add_entry('&raquo;Organism', 'Export', '?page=Export&organism='.$org);
      $application->menu->add_category('&raquo;Comparative Tools');
      $application->menu->add_entry('&raquo;Comparative Tools', 'Function based Comparison', '?page=CompareMetabolicReconstruction&organism='.$org);
      $application->menu->add_entry('&raquo;Comparative Tools', 'Sequence based Comparison', '?page=MultiGenomeCompare&organism='.$org);
      $application->menu->add_entry('&raquo;Comparative Tools', 'Kegg Metabolic Analysis', '?page=Kegg&organism='.$org);
      $application->menu->add_entry('&raquo;Comparative Tools', 'BLAST search', '?page=BlastRun&organism='.$org);
      $application->menu->add_entry('&raquo;Comparative Tools', 'Find this gene in an organism', '?page=SearchGeneByFeature&feature='.$id, '_blank');
      $application->menu->add_category('&raquo;Feature');
      $application->menu->add_entry('&raquo;Feature', 'Feature Overview', "?page=Annotation&feature=$id");
      $application->menu->add_entry('&raquo;Feature', 'DNA Sequence', "?page=ShowSeqs&feature=$id&Sequence=DNA Sequence", "_blank");
      $application->menu->add_entry('&raquo;Feature', 'DNA Sequence w/ flanking', "?page=ShowSeqs&feature=$id&Sequence=DNA Sequence with flanking", "_blank");
      if ($id =~ /\.peg\./) {
	  $application->menu->add_entry('&raquo;Feature', 'Protein Sequence', "?page=ShowSeqs&feature=$id&Sequence=Protein Sequence", "_blank");
      }
      $application->menu->add_entry('&raquo;Feature', 'Feature Evidence vs. FIG', '?page=Evidence&feature='. $cgi->param('feature'));
      $application->menu->add_entry('&raquo;Feature', 'Feature Evidence vs. all DB', '?page=Evidence&sims_db=all&feature='.$cgi->param('feature'));
      $application->menu->add_category('&raquo;Feature Tools');

  }

  if ($reg_genome eq 'all')
  {
      return $self->show_all_regulons();
  }
  elsif ($reg eq 'all')
  {
      return $self->show_regulon_index($reg_genome);
  }
  else
  {
      return $self->show_one_regulon($reg_genome, $reg);
  }
}

sub show_all_regulons
{
    my($self) = @_;

    my $dh;
    if (!opendir($dh, $FIG_Config::atomic_regulon_dir))
    {
	return "No regulons found.";
    }

    my $fig = $self->application->data_handle('FIG');
    my $hdrs = ["Genome ID", "Name"];
    my @tbl;
    my $u = $self->application->url;
    my @genomes = grep { -s "$FIG_Config::atomic_regulon_dir/$_/html/index.html" } readdir($dh);
    closedir($dh);
    @genomes = sort { $a->[1] cmp $b->[1] }
    		map  { [ $_, $fig->genus_species($_) ] } @genomes;
    for my $g (@genomes)
    {
	my($genome, $genome_name) = @$g;
	my $l = "$u?page=AtomicRegulon&genome=$genome&regulon=all";
	push(@tbl, [qq(<a href="$l">$genome</a>), $genome_name]);
    }
    return &HTML::make_table($hdrs, \@tbl, "All genomes with atomic regulon data");
}

sub show_regulon_index
{
    my($self, $genome) = @_;

    my $application = $self->application;
    
    my $f = "$FIG_Config::atomic_regulon_dir/$genome/html/index.html";
    my $fh;
    if (!open($fh, "<", $f))
    {
	return "<h2>Genome not found</h2>Atomic regulon data for genome $genome was not found.";
    }

    my $fig = $self->application->data_handle('FIG');
    my $gname = $fig->genus_species($genome);
    my $html = "<h1>Atomic regulons in $gname ($genome)</h1>";
    $html .= "<p>Note that viewing regulons with more than 100 or so pegs may cause your browser to hang for a long time while the tables are rendered.</p>";
    while (<$fh>)
    {
	next if m,</?html>,;
	s!href=[\'\"]?\./(\d+)\.html[\'\"]?
	 ! 'href="' . $application->url . "?page=AtomicRegulon&genome=$genome&regulon=$1" . '"'
	 !ex;
	$html .= $_;
    }
    close($fh);
    return $html;
}

sub show_one_regulon
{
    my($self, $reg_genome, $reg) = @_;
    my $application = $self->application;
    #
    # Load & modify the atomic regulon html data.
    #
    
    my $f = "$FIG_Config::atomic_regulon_dir/$reg_genome/html/$reg.html";
    my $fh;
    if (!open($fh, "<", $f))
    {
	return <<END;
	<h2>Regulon not found</h2>
	    Regulon data for regulon $reg in $reg_genome was not found. <br>
END
    }

    my $html = "";
    while (<$fh>)
    {
	if (/<html>/)
	{
	    my $fig = $self->application->data_handle('FIG');
	    my $gs = $fig->genus_species($reg_genome);
	    $html .= "<H2>Atomic Regulon $reg in $gs ($reg_genome)</H2>\n";
	    if ($reg > 1)
	    {
		my $prev = $reg - 1;
		my $url = $application->url . "?page=AtomicRegulon&genome=$reg_genome&regulon=$prev";
		$html .= "<a href='$url'>Previous regulon ($prev)</a> ";
	    }
	    my $next = $reg + 1;
	    if (-f "$FIG_Config::atomic_regulon_dir/$reg_genome/html/$next.html")
	    {
		my $url = $application->url . "?page=AtomicRegulon&genome=$reg_genome&regulon=$next";
		$html .= "<a href='$url'>Next regulon ($next)</a> ";
	    }
	}
	next if m,</html>,;
	
	s!href=[\'\"]?http.*feature=(fig\|\d+\.\d+\.peg.\d+)[\'\"]?
	    ! 'href="' . mk_link($application, $1) . '"'
	    !ex;

        $html .= $_;
    }
    close($fh);

    $html .= "<p>\n";
    $html .= "<a href='ar_coexp.cgi?genome=$reg_genome&ar=$reg'>Show coexpressed genes not in atomic regulon $reg</a><p>";
    $html .= '<a href="' . $application->url . "?page=AtomicRegulon&regulon=all&genome=$reg_genome" . '">' .
	"Show all regulons in $reg_genome.</a><p>\n";
    $html .= '<a href="' . $application->url . '?page=AtomicRegulon&genome=all">' .
	"Show all regulons.</a>\n";
    
    return $html;
}

sub mk_link
{
    my($app, $fid) = @_;
    return $app->url . "?page=Annotation&feature=$fid";
}

sub compared_region {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;
  Trace("Processing compared region.") if T(3);

  unless (defined($cgi->param('feature'))) {
    $application->add_message('warning', 'Feature page called without an identifier');
    return "";
  }
  my $fig = $application->data_handle('FIG');

  # check if we have a valid fig
  unless ($fig) {
    $application->add_message('warning', 'Invalid organism id');
    return "";
  }

  my $cr = $application->component('ComparedRegions');
  $cr->line_select(1);
  #$cr->show_genome_select(1);
  $cr->fig($fig);

  # check for compared regions preferences of the user
  # if there is a user logged in and the organism has not changed since
  # the last invocation of the annotation page, the parameters for region
  # size and number of regions will be maintained
  my $user = $application->session->user;
  my $master = $application->dbmaster;
  if (ref($master) && ref($user) && ! $application->anonymous_mode) {
    my $curr_id;
    my $curr_org;
    if ($cgi->param('pattern')) {
      $curr_id = $cgi->param('pattern');
    } elsif ($cgi->param('feature')) {
      $curr_id = $cgi->param('feature');
    }
    if ($curr_id) {
      ($curr_org) = $curr_id =~ /(\d+\.\d+)/;
    }
    if ($curr_org) {
      my $last_org = $master->Preferences->get_objects( { user => $user, name => 'ComparedRegionsLastOrg' } );
      my $num_regions = $master->Preferences->get_objects( { user => $user, name => 'ComparedRegionsNumRegions' } );
      my $size_regions = $master->Preferences->get_objects( { user => $user, name => 'ComparedRegionsSizeRegions' } );
      if (scalar(@$last_org) == 0) {
	$last_org = $master->Preferences->create( { user => $user, name => 'ComparedRegionsLastOrg', value => $curr_org } );
      } else {
	$last_org = $last_org->[0];
      }
      my ($rs, $nr);
      unless ($cgi->param('region_size') && $cgi->param('number_of_regions')) {
	$rs = $master->Preferences->get_objects( { user => $user, name => "ComparedRegionsDefaultSizeRegions" } );
	if (scalar(@$rs)) {
	  $rs = $rs->[0]->value;
	} else {
	  $rs = 16000;
	}
	$nr = $master->Preferences->get_objects( { user => $user, name => "ComparedRegionsDefaultNumRegions" } );
	if (scalar(@$nr)) {
	  $nr = $nr->[0]->value;
	} else {
	  $nr = 4;
	}
      }
      if ($last_org->value eq $curr_org) {
	if (scalar(@$num_regions)) {
	  $num_regions = $num_regions->[0];
	  $size_regions = $size_regions->[0];
	  if ($cgi->param('region_size') && $cgi->param('number_of_regions')) {
	    $num_regions->value($cgi->param('number_of_regions'));
	    $size_regions->value($cgi->param('region_size'));
	  }
	} else {
	  $num_regions = $master->Preferences->create( { user => $user, name => 'ComparedRegionsNumRegions', value => $cgi->param('number_of_regions') || $nr } );
	  $size_regions = $master->Preferences->create( { user => $user, name => 'ComparedRegionsSizeRegions', value => $cgi->param('region_size') || $rs } );
	}
	$cgi->param('region_size', $size_regions->value);
	$cgi->param('number_of_regions', $num_regions->value);
      } else {
	if (defined($rs)) {
	  $cgi->param('region_size', $rs);
	}
	if (defined($nr)) {
	  $cgi->param('number_of_regions', $nr);
	}
	if (scalar(@$num_regions)) {
	  $num_regions = $num_regions->[0];
	  $size_regions = $size_regions->[0];	  
	  $num_regions->value($cgi->param('number_of_regions'));
	  $size_regions->value($cgi->param('region_size'));
	}
	
      }
      $last_org->value($curr_org);
    }
  }

  Trace("Compared region object created.") if T(3);
  my $o = $cr->output();

  return $o;
}


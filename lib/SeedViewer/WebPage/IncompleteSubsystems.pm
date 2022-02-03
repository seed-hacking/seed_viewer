package SeedViewer::WebPage::IncompleteSubsystems;

use strict;
use warnings;

use base qw( WebPage );

use Data::Dumper;

1;

sub init {
    my ($self) = @_;
    $self->application->register_component('Table', 't');
    $self->title('Incomplete Subsystems');
}

sub output {	
  my ($self) = @_;
  
  # initialize some objects
  my $application = $self->application();
  my $cgi = $application->cgi;
  my $fig = $application->data_handle('FIG');

  # check if we have an organism
  my $org = $cgi->param('organism');

  unless ($fig && $org) {
    $application->add_message('warning', "Incomplete Subsystems page called without a valid organism");
    return "";
  }

  # get the subsystem data for the current genome
  my $ss_data = $fig->get_genome_subsystem_data($org);
  
  # hash the raw data
  my $org_ss = {};
  foreach my $row (@$ss_data) {
    unless (exists($org_ss->{$row->[0]})) {
      $org_ss->{$row->[0]} = {};
    }
    
    $org_ss->{$row->[0]}->{$row->[1]} = 1;
  }

  # record the data
  my $data = [];

  # go through all subsystems
  foreach my $subsys_name (grep {$fig->usable_subsystem($_) } $fig->all_subsystems) {

    # if we do not have a single role of this subsystem we can skip it
    next unless(exists($org_ss->{$subsys_name}));

    # initialize the subsystem object
    my $sobj = $fig->get_subsystem($subsys_name);

    # skip if the inialization fails
    next unless($sobj);
    
    # skip if the current genome has a functional variant
    my $vcode = $sobj->get_variant_code($sobj->get_genome_index($org));
    next unless (($vcode eq '0') || ($vcode eq '-1') || ($vcode eq '*0') || ($vcode eq '*-1'));

    # get all non-auxiliary roles of the subsystem
    my @roles   = $sobj->get_roles;
    my @non_aux_roles = grep { ! $sobj->is_aux_role($_) } @roles;

    # record the closest match
    my $closest = [];
    my $closest_total = 0;

    # find the closest match
    foreach my $genome ($sobj->get_genomes) {

      # skip genomes with non-functional or non-annotator variant
      my $vcode = $sobj->get_variant_code($sobj->get_genome_index($genome));
      next if (($vcode eq '0') || ($vcode eq '-1') || ($vcode =~ /\*/));

      my $current = [];
      
      # check which roles are present
      my $total = 0;
      foreach my $role (@non_aux_roles) {
	my @pegs = $sobj->get_pegs_from_cell($genome,$role);
	if (@pegs > 0) {
	  $total++;
	  unless (exists($org_ss->{$subsys_name}) && $org_ss->{$subsys_name}->{$role}) {
	    push(@$current, [ $role, \@pegs ]);
	  }
	}
      }
      if (! scalar(@$closest) || (scalar($current) < scalar($closest))) {
	$closest = $current;
	$closest_total = $total;
      }
    }

    # push the closest match into the table
    next if (scalar(@$closest) > 5);
    foreach my $role (@$closest) {
      my $rolename = $role->[0];
      my $pretty_ssname = $subsys_name;
      $pretty_ssname =~ s/_/ /g;
      $pretty_ssname = "<a href='?page=Subsystems&subsystem=$subsys_name&organism=$org&active=' target=_blank>".$pretty_ssname."</a>";
      my $peg = $role->[1]->[0];
      $peg = "<a href='?page=Annotation&feature=$peg' target=_blank>$peg</a>";
      push(@$data, [ $pretty_ssname, $rolename, $peg, scalar(@$closest), $closest_total ]); 
    }
  }

  @$data = sort { $a->[3] <=> $b->[3] || $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } @$data;

  my $t = $application->component('t');
  $t->columns( [ { name => "subsystem", filter => 1, operator => 'combobox' },
		 { name => "missing role", filter => 1 },
		 { name => "feature" },
		 { name => "roles missing", sortable => 1 },
		 { name => "total roles" } ] );
  $t->data($data);

  my $content = "<h2>Incomplete Subsystems for ".$fig->genus_species($org)." (".$org.")</h2>";
  $content .= "<p style='width: 800px'>The table below will show you subsystems for the selected organism, which have not been classified as having a functional variant but in which the organism has at least one functional role present. Those subsystems are potentially incomplete for this organism due to incorrectly or inaccurately assigned gene functions. You can try to complete a functional variant for your organism for these subsystems by searching for the missing roles.</p><p style='width: 800px'>The results are ordered to show you the subsystems with the smallest number of missing roles first. Each row shows one role neccessary to complete a functional variant for the subsystem. The column 'roles missing' will show you the number of roles missing to complete a functional variant. The column 'total roles' will show you the total number of roles of that variant. Subsystems with more than 5 missing roles will not be considered.</p><p style='width: 800px'>In order to check the subsystem, click on the subsystem name in the first column. The subsystem page will open in a new window.</p>";

  $content .= $t->output();

  return $content;

}

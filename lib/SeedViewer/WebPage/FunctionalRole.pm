package SeedViewer::WebPage::FunctionalRole;

use base qw( WebPage );

1;

use strict;
use warnings;

use FIG;
use FIGV;
use UnvSubsys;

=pod

=head1 NAME

FunctionalRole - an instance of WebPage which displays information about a Functional Role

=head1 DESCRIPTION

Display information about a Functional Role

=head1 METHODS

=over 4

=item * B<init> ()

Initialise the page

=cut

sub init {
  my $self = shift;

  $self->title('Functional Role');
  
  # register components
  $self->application->register_component('Table', 'FunctionalRoleTable');
  
}

=item * B<output> ()

Returns the html output of the FunctionalRole page.

=cut

sub output {
  my ($self) = @_;

  my $application = $self->application();
  my $cgi = $application->cgi();
  my $fig = $application->data_handle('FIG');

  my $subsystem = $cgi->param('subsystem_name');
  unless (defined($subsystem)) {
    return "<h2>Functional Roles</h2><p>A functional role is only defined within the context of a subsystem.</p><p>please go to the <a href='?page=SubsystemSelect'>Select a Subsystem</a> page.</p>";
    $application->add_message('warning', 'you need to supply a subsystem');
    return "";
  }
  my $subsystem_pretty = $subsystem;
  $subsystem_pretty =~ s/_/ /g;
  my $role = $cgi->param('role');
  unless (defined($role)) {
    $application->add_message('warning', 'you need to supply a role');
    return "";
  }
  
  # retrieve all cds with this role
  my @pegs = $fig->seqs_with_role($role);

  # make sure there are seqs to display
  unless (scalar(@pegs)) {
    $application->add_message('warning', 'there were no features found with the specified role');
    return "";
  }

  # create a form for the sequence page
  my $sequence_page_form = $self->start_form('sequence_page_form', { page => 'ShowSeqs' }, '_blank');
  foreach my $peg (@pegs) {
    $sequence_page_form .= "<input type='hidden' name='feature' value='$peg'>";
  }
  $sequence_page_form .= $self->button('show sequences');
  $sequence_page_form .= $self->end_form();
  
  # calculate some statistics on the members
  my $orgs;
  foreach my $peg (@pegs) {
    $peg =~ /fig\|(\d+\.\d+)\.peg\.\d+/;
    push(@{$orgs->{$1}}, $peg);
  }
  
  my $domains;
  foreach my $org (keys(%$orgs)) {
    my $dom = $fig->genome_domain($org);
    if (exists($domains->{$dom})) {
      $domains->{$dom}++;
    } else {
      $domains->{$dom} = 1;
    }
  }

  my $html = "";
  $html .= "<h2>Functional Role: <i>$role</i></h1>";
  my $housekeeping = "<table><tr><th>Functional Role</th><td>" . $role . "</td></tr><tr><th>Subsystem</th><td><a href='?page=Subsystems&subsystem=" . $subsystem . "'>" . $subsystem_pretty . "</a></td></tr>";

  $role =~ /EC\s([0-9\-\.a-z]+)/i;
  my $ec_number = $1;
  my $go_number = "";
  my $go_description = "";
  unless ($ec_number) {
    $housekeeping .= "<tr><th>EC Number</th><td>no EC Number recorded</td></tr>";
  } else {
    $housekeeping .= "<tr><th>EC Number</th><td><a href='http://www.genome.jp/dbget-bin/www_bget?ec:$ec_number' target='outbound'>" . $ec_number . "</a></td></tr>";
    
    open (IN,"$FIG_Config::data/Global/ec2go") or warn $!;
    my @ec2go;
    while (<IN>) {
      push(@ec2go, $_);
    }
    close (IN);
    my @line = grep { $_ =~ /$ec_number/ } @ec2go;
    if (scalar(@line)) {
      $line[0] =~ /EC:([0-9\-\.]+)\s+\>\s+GO:\s*(\S.*\S)\s*\;\s+GO:(\d+)$/;
      $go_number = $3;
      $go_description = $2;
      
      if ($go_number) {
	$housekeeping .= "<tr><th>GO Category</th><td>" . $go_description . " (<a href='http://www.godatabase.org/cgi-bin/amigo/go.cgi?action=query&view=query&search_constraint=terms&query=$go_number' target='outbound'>" . $go_number . "</a>)</td></tr>";
      }
    }
  }
  unless ($go_number) {
    $housekeeping .= "<tr><th>GO Category</th><td>no GO Category recorded</td></tr>";
  }

  my $subsystem_object = $fig->get_subsystem($subsystem);
  
  # check if we get a valid subsystem
  unless ($subsystem_object) {
    $application->add_message('warning', "The subsystem $subsystem could not be found.");
    return "";
  }
  my $reactions = $subsystem_object->get_reactions;
  if (exists($reactions->{$role})) {
    if (scalar(@{$reactions->{$role}})) {
      my $reaction_links;
      foreach my $link (@{$reactions->{$role}}) {
	push(@$reaction_links, "<a href='http://www.genome.ad.jp/dbget-bin/www_bget?rn+" . $link . "' target='outbound'>" . $link . "</a>");
      }
      $housekeeping .= "<tr><th>Reactions</th><td>" . join("<br/>", @$reaction_links) . "</td></tr>";
    }
  } else {
    $housekeeping .= "<tr><th>Reactions</th><td>no Reactions recorded</td></tr>";
  }
  $housekeeping .= "</table>";
  
  # get members
  my $table_data = [];
  foreach my $peg (@pegs) {
    my $org = '-';
    if ($peg =~ /fig\|(\d+\.\d+)/) {
      $org = $1;
    }
    else {
      next;
    }
    my $org_name = $fig->org_of($peg) || "-";
    my ($genus, $domain) = $fig->genus_species_domain($org);
    
    push(@$table_data, ["<a href='?page=Annotation&feature=$peg'>$peg</a>", "<span style='display:none;'>$org_name</span><a href='?page=Organism&organism=$org'>$org_name</a>", $domain ]);
  }
  my @sorted_data = sort { $a->[1] cmp $b->[1] } @$table_data;
  
  # calculate statistics
  my $statistics = "<table><tr><th>Number of Occurrences</th><td>" . scalar(@$table_data) . "</td></tr><tr><th>Number of Organisms</th><td>" . scalar(keys(%$orgs)) . "</td></tr>";
  
  my $archaeal = $domains->{'Archaea'} || 0;
  my $bacterial = $domains->{'Bacteria'} || 0;
  my $eukaryal = $domains->{'Eukaryota'} || 0;
  my $viral = $domains->{'Virus'} || 0;
  
  $statistics .= "<tr><th> &raquo Archaea</th><td>" . $archaeal . "</td></tr>";
  $statistics .= "<tr><th> &raquo Bacteria</th><td>" . $bacterial . "</td></tr>";
  $statistics .= "<tr><th> &raquo Eukaryota</th><td>" . $eukaryal . "</td></tr>";
  $statistics .= "<tr><th> &raquo Virus</th><td>" . $viral . "</td></tr>";
  $statistics .= "</table>";

  my $functional_role_table = $application->component('FunctionalRoleTable');
  $functional_role_table->columns( [ 'ID',  { name => 'Organism', filter => 1, sortable => 1 }, { sortable => 1, name => 'Domain', filter => 1, operator => 'combobox' } ] );
  $functional_role_table->show_export_button(1);
  $functional_role_table->items_per_page(15);
  $functional_role_table->show_select_items_per_page(1);
  $functional_role_table->show_top_browse(1);
  $functional_role_table->show_bottom_browse(1);
  $functional_role_table->data(\@sorted_data);
  $functional_role_table->width(800);

  $html .= "<table><tr><td>$housekeeping</td><td>&nbsp;&nbsp;&nbsp;</td><td>$statistics</td></tr></table>";
  $html .= "<h2>Members of this Functional Role</h2>";
  $html .= $sequence_page_form."<br>";
  $html .= $functional_role_table->output();
    
  return $html;
  
}

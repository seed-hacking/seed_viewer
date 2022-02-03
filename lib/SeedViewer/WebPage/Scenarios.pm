package SeedViewer::WebPage::Scenarios;

use base qw( WebPage );

1;

use strict;
use warnings;

use URI::Escape;

use FIG_Config;
use Scenario;
use model;

=pod

=head2 NAME

Organism - an instance of WebPage which displays information about Scenarios

=head2 DESCRIPTION

Display information about Scenarios

=head2 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->application->no_bot(1);
  $self->title("Scenarios");
  $self->application->register_component('TabView', 'ScenarioTabView');
  $self->application->register_component('Table', 'ScenarioTable');
  $self->application->register_component('ListSelect', 'MGSelect');

  return 1;
}

=item * B<output> ()

Returns the html output of the Scenarios page.

=cut

sub output {
  my ($self) = @_;

  # initialize objects
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $fig = $application->data_handle('FIG');

  # check if we have a valid fig
  unless ($fig) {
    $application->add_message('warning', 'Invalid organism id');
    return "";
  }

  # get cgi params
  my $genome = $cgi->param('organism') || '';
  my $genome_name = $fig->genus_species($genome);
  $genome_name =~ s/_/ /g if $genome;
  my @comparison_organisms = $cgi->param('comparison_organisms');

  # set up the menu
  if ($cgi->param('organism')) {
    $application->menu->add_category('&raquo;Organism');
    $application->menu->add_entry('&raquo;Organism', 'General Information', '?page=Organism&organism='.$cgi->param('organism'));
    $application->menu->add_entry('&raquo;Organism', 'Feature Table', '?page=BrowseGenome&tabular=1&organism='.$cgi->param('organism'));
    $application->menu->add_entry('&raquo;Organism', 'Genome Browser', '?page=BrowseGenome&organism='.$cgi->param('organism'));
    $application->menu->add_entry('&raquo;Organism', 'Scenarios', '?page=Scenarios&organism='.$cgi->param('organism'));
    $application->menu->add_entry('&raquo;Organism', 'Subsystems', '?page=SubsystemSelect&organism='.$cgi->param('organism'));
    $application->menu->add_entry('&raquo;Organism', 'Export', '?page=Export&organism='.$cgi->param('organism'));

    $application->menu->add_category('&raquo;Comparative Tools');
    $application->menu->add_entry('&raquo;Comparative Tools', 'Function based Comparison', '?page=CompareMetabolicReconstruction&organism='.$cgi->param('organism'));
    $application->menu->add_entry('&raquo;Comparative Tools', 'Sequence based Comparison', '?page=MultiGenomeCompare&organism='.$cgi->param('organism'));
    $application->menu->add_entry('&raquo;Comparative Tools', 'Kegg Metabolic Analysis', '?page=Kegg&organism='.$cgi->param('organism'));
    $application->menu->add_entry('&raquo;Comparative Tools', 'BLAST search', '?page=BlastRun&organism='.$cgi->param('organism'));
  }

  # load select mg component
  my $MGSelect = $self->application->component('MGSelect');
  $MGSelect->show_reset(1);
  $MGSelect->filter(1);
  $MGSelect->multiple(1);
  $MGSelect->name('comparison_organisms');
  my $genome_info = $fig->genome_info();
  $MGSelect->data( $self->column_metadata($genome, $genome_info) );
  $MGSelect->preselection(\@comparison_organisms);
  my $select_box = $MGSelect->output();

  # get all scenario info
  Scenario->set_fig($fig);
  my @all_scenarios = @{Scenario->get_genome_scenarios("All")};
  my (%all_scenarios);

  foreach my $scenario (@all_scenarios)
  {
      $all_scenarios{$scenario->get_subsystem_name}->{$scenario->get_scenario_name_only} = 1;
  }

  my $hidden = "";
  if ($genome) {
    $hidden = "<input type='hidden' name='organism' value='$genome'>";
  }

  my (%genome_name, %org_scenarios);

  foreach my $org ( $genome, @comparison_organisms )
  {
      next if $org eq '';
      $genome_name{$org} = $fig->genus_species($org);
      $genome_name{$org} =~ s/_/ /g;

      my $org_basedir = $fig->scenario_directory($org);

      # check if the data for this organism is present
      unless (-d $org_basedir) {
	  $application->add_message('info', "There is no scenario data for this organism ($org)");
	  return "";
      }

      my @org_scenarios = @{Scenario->get_genome_scenarios($org)};

      foreach my $scenario (@org_scenarios)
      {
	  $org_scenarios{$org}->{$scenario->get_subsystem_name}->{$scenario->get_scenario_name_only} = 1;
      }
  }

  model::set_fig($fig);
  my $ss_to_superset = model::load_superset_file;
  my $ss_class = {};

  foreach my $ss (keys %$ss_to_superset)
  {
      my $classification = $fig->subsystem_classification($ss);
      my $c1 = $classification->[0] ? $classification->[0] : "(none)";
      my $c2 = $classification->[1] ? $classification->[1] : "(none)";
      $ss_class->{$c1}->{$c2}->{$ss} = 1;
  }

  my $sctable_data;
  my $all_scenario_info = $fig->get_scenario_info(keys %$ss_to_superset);

  # first we determine all the reactions for the organism based on its functional roles
  my %frs_to_reactions_all;
  my %reactions_for_org;

  foreach my $ss (keys %$all_scenario_info)
  {
      map { push @{$frs_to_reactions_all{$_}}, @{$all_scenario_info->{$ss}->{"reactions"}->{$_}} } keys %{$all_scenario_info->{$ss}->{"reactions"}};
  }

  if ($genome eq '') {
      foreach my $role (keys %frs_to_reactions_all)
      {
	  map { $reactions_for_org{$_} = 1 } @{$frs_to_reactions_all{$role}};
      }
  }
  else {
      my $features = $fig->all_features_detailed_fast($genome);

      foreach my $feature (@$features) {
	  my $func = $feature->[6];
	  if ($func) {
	      foreach my $role ($fig->roles_of_function($func)) {
		  map { $reactions_for_org{$_} = 1 } @{$frs_to_reactions_all{$role}};
	      }
	  }
      }
  }

  # now get info about what organism reactions are in what kegg map
  my $base_path = $FIG_Config::kegg || "$FIG_Config::data/KEGG";
  $base_path .= "/pathway/map";
  my %maps_to_reactions;
  open(TAB, "<$base_path/rn_map.tab") or $application->add_message('warning', "Could not open KEGG file 'rn_map.tab': $!");
  while ( defined(my $line = <TAB>) )
  {
      chomp $line;
      my($rn, @maps) = split(/\s+/, $line);
      next unless (exists $reactions_for_org{$rn});
      foreach my $map ( @maps )
      {
	  push @{ $maps_to_reactions{$map} }, $rn;
      }
  }
  close(TAB);

  # construct hyperlinks for kegg maps to highlight reactions
  my %kegg_map_info;
  
  # finally catalog the table of scenario info
  foreach my $superclass (sort keys(%$ss_class)) {
      foreach my $subclass (sort keys(%{$ss_class->{$superclass}})) {
	  foreach my $subsystem (sort keys(%{$ss_class->{$superclass}->{$subclass}})) {
	      my $pretty_subsystem = $subsystem;
	      $pretty_subsystem =~ s/_/ /g;
	      if (exists $all_scenarios{$subsystem})
	      {
		  foreach my $scenario_name (keys %{$all_scenarios{$subsystem}})
		  {
		      my $pretty_scenario_name = $scenario_name;
		      $pretty_scenario_name =~ s/_to_/ to /g;
		      $pretty_scenario_name =~ s/_and_/ and /g;
		      $pretty_scenario_name =~ s/_by_/ by /g;
		      $pretty_scenario_name =~ s/_using_/ using /g;
		      unless ($all_scenario_info->{$subsystem}->{"scenarios"}->{$scenario_name}) {
			next;
		      }
		      my @map_ids = @{$all_scenario_info->{$subsystem}->{"scenarios"}->{$scenario_name}->{map_ids}};
		      my @map_info = ();

		      foreach my $mapid (@map_ids)
		      {
			  if (! exists $kegg_map_info{$mapid}) {
			      my $map_name = $fig->map_name("map".$mapid);
			      if (exists $maps_to_reactions{$mapid}) {
				  $kegg_map_info{$mapid} = "<a href=\"javascript:void(0)\"onclick=\"window.open('http://www.genome.jp/dbget-bin/show_pathway?rn$mapid+".(join "+", @{$maps_to_reactions{$mapid}})."')\">$map_name [".(scalar @{$maps_to_reactions{$mapid}})."]</a>";
			      }
			      else {
				  $kegg_map_info{$mapid} = "<a href=\"javascript:void(0)\"onclick=\"window.open(\'http://www.genome.jp/dbget-bin/show_pathway?rn$mapid\')\">$map_name</a>";
			      }
			  }
			  push @map_info, $kegg_map_info{$mapid};

		      }
		      my $map_ids_string = join(";<br>", @map_info);

		      my @columns = ($superclass, $subclass, "<a href=\"javascript:void(0)\"onclick=\"window.open(\'".$application->url."?page=Subsystems&subsystem=$subsystem&tab=scenarios&organism=$genome\')\">".$pretty_subsystem."</a>", $pretty_scenario_name, $map_ids_string);
		      foreach my $org ($genome, @comparison_organisms)
		      {
			  next if $org eq '';
			  my $paths = exists $org_scenarios{$org}->{$subsystem}->{$scenario_name} ? "yes" : "no";
			  push(@columns, $paths);
		      }

		      push(@$sctable_data, \@columns);
		  }
	      }
	  }
      }
  }

  # get the tabview
  my $sstv = $application->component('ScenarioTabView');
  $sstv->width('95%');
  
  # add a table of the scenario data
  my $sctable = $application->component('ScenarioTable');
  my @column_headers = ({ name => 'Category', filter => 1, operator => 'combobox', sortable => 1 }, { name => 'Subcategory', filter => 1, operator => 'combobox', sortable => 1 }, { name => 'Subsystem', filter => 1, sortable => 1 }, { name => 'Scenario', filter => 1, sortable => 1 }, { name => 'KEGG maps', filter => 1, sortable => 1 });

  foreach my $org ($genome, @comparison_organisms)
  {
      next if $org eq '';
      my $name = $genome_name{$org};
      push @column_headers, { name => $org, tooltip => $name, filter => 1, sortable => 1 };
  }

  $sctable->columns(\@column_headers);
  $sctable->data($sctable_data);
  $sctable->show_top_browse(1);
  $sctable->show_bottom_browse(1);
  $sctable->items_per_page(15);
  $sctable->show_select_items_per_page(1);
  $sctable->show_clear_filter_button(1);
#  $sctable->show_export_button({strip_html=>1});
  $sstv->add_tab('Scenarios in Subsystems', $sctable->output());
  
  my $js = qq~<script>
      function select_other () {
	  var b1 = document.getElementById('org_select_switch');
	  var div1 = document.getElementById('org_select');
	  if (b1.value == 'select organisms') {
	      b1.value = 'hide organism selection';
	      div1.style.display = 'inline';
	  } else {
	      b1.value = 'select organisms';
	      div1.style.display = 'none';
	  }
      }
  </script>~;


  # build html
  my $html = "$js";
  $html .= $genome ? "<h2>Scenarios for $genome_name</h2>" : "<h2>All Scenarios</h2>";
  $html .= "<div style='width: 800px; text-align: justify;'>Scenarios represent components of a metabolic reaction network in which specific compounds are labeled as inputs and outputs. The metabolic network is assembled using biochemical reaction information associated with functional roles in subsystems to find paths through scenarios from inputs to outputs.  Scenarios that are connected by linked inputs and outputs can be composed  to form larger blocks of the metabolic network, spanning processes that convert transported nutrients into biomass components.<p>Select organisms to show whether paths are present for each scenario based on the organisms' genome annotations in subsystems.</div><br><br>";

  $html .= "<input type='button' onclick='select_other();' value='select organisms' id='org_select_switch'><br><br>";
  my $style = " style='display: none;'";

  my $ls_id = $self->application->component('MGSelect')->id;
  my $form = qq(<table border="0"><tr>\n) .
      qq(<th>Select organisms for comparison:</th></tr>\n<tr><td>) .
      $select_box .
      qq(</td></tr></table>\n) .
      $hidden .	       
      "<input type='button' onclick='list_select_select_all($ls_id);form.submit()' value='Show selected organisms' id='org_select'><br><br/>";

  $html .= $self->start_form('select_organism_form');
  $html .= "<div id='org_select'$style>".$form;
  $html .= $self->end_form()."</div>";

  # add the tabview to the html
  $html .= $sstv->output()."<br><br>";

  return $html;
}

sub column_metadata {
    my ($self, $genome, $genome_list) = @_;
    my $column_metadata = [];
    my @sorted_genome_list = sort { (($b->[1] =~ /^Private\: /) cmp ($a->[1] =~ /^Private\: /)) || (lc($a->[1]) cmp lc($b->[1])) } @$genome_list;

    foreach my $line (@sorted_genome_list) {
	my $domain;
	if ($line->[3] eq 'Bacteria')
	{
	    $domain = '[B]';
	}
	elsif ($line->[3] eq 'Archaea')
	{
	    $domain = '[A]';
	}
	else
	{
	    # only compute scenarios for Bacteria and Archaea for now
	    next;
	}

	my($id, $name) = ($line->[0], $line->[1] . " $domain ("  . $line->[0] . ")");
	next if ($id eq $genome);
	push @{$column_metadata}, {value => $id, label => $name};
    }

    return $column_metadata;
}

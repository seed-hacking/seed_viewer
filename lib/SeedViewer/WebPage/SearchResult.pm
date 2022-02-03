package SeedViewer::WebPage::SearchResult;

use strict;
use warnings;

use base qw( WebPage );

use URI::Escape;
use SOAP::Lite;
use FreezeThaw qw( freeze thaw );
use Tracer;

1;

=pod

=head2 NAME

SearchResult - search result page of the SeedViewer

=head2 DESCRIPTION

Displays a search result

=head2 METHODS

=over 4

=item * B<init> ()

Initialise the page

=cut

sub init {
  my $self = shift;

  $self->title('Search Result');
  $self->application->no_bot(1);

  # register components
  $self->application->register_component('Table', 'ResultTable');
  $self->application->register_component('Table', 'OrgResultTable');
  $self->application->register_component('Table', 'SSResultTable');
  $self->application->register_component('Table', 'FRResultTable');
  $self->application->register_component('Table', 'FeatureResultTable');
  $self->application->register_component('Table', 'ProtResultTable');
  $self->application->register_action($self, 'check_search','check_search');

}

=pod

=item * B<output> ()

Returns the html output of the SearchResult page.

=cut

sub output {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi();
  my $fig = $application->data_handle('FIG');
  Confess("Could not connect to database.") if ! defined $fig;
  my $search = $cgi->param('pattern');
  my $user = $application->session->user;
  my $is_annotator = 0;
  if ($user && $user->has_right(undef, 'annotate', 'genome', '*')) {
    $is_annotator = 1;
  }

  my $content = "<h2>no result</h2><p style='width: 800px;'>Your search for <b>$search</b> did not produce any results from our database.</p><br><br><a href='".$application->url."?page=Home'>back to start page</a>";

  # check if a phrase was passed
  unless (defined($search)) {
    $application->add_message('warning', 'no phrase passed to search');
  }
  # there is no unique result, do a local search
  my $result = [];
  my ( $md5 ) = $search =~ /^\s*([0-9A-Fa-f]{32})\s*$/;
  if ( $md5 )
  {
    #            [ fid, func, gensp, gid, domain ]
	my @data = map  { [ $_->[0], $_->[1], $_->[2], "$_->[4].$_->[5]", $_->[3] ] }
               # [ fid, func, gensp, domain, taxid, gver, pegnum ]
               sort { lc $a->[3] cmp lc $b->[3]           # domain
                   || lc $a->[2] cmp lc $b->[2]           # gen_species
                   ||    $a->[4] <=>    $b->[4]           # taxid
                   ||    $a->[5] <=>    $b->[5]           # g_version
                   ||    $a->[6] <=>    $b->[6]           # peg_num
                    }
               map  { [ $_,                               # fid
                        scalar $fig->function_of( $_ ),   # func
                        $fig->genus_species_domain( /\|(\d+\.\d+)\.[^.]+\.\d+$/ ), # genus_species, domain
                        /\|(\d+)\.(\d+)\.[^.]+\.(\d+)$/    # taxid, genver, pegnum
                      ]
                    }
               $fig->is_real_feature_bulk( [ $fig->pegs_with_md5( $md5 ) ] );
    push @$result, { type => 'proteins', result => \@data } if @data;
  }

  $result = $fig->search_database($search, { limit => ($FIG_Config::max_seedviewer_table || 10000) }) unless @$result;

  if (ref($result) eq 'ARRAY') {
    if (scalar(@$result)) {
      $content = "<h2>Search Results for <em>'$search'</em></h2>";
      foreach my $part_result (@$result) {
	my $type = $part_result->{type};
	my $data = $part_result->{result};
	if ($type eq 'organism') {
	  for (my $i=0; $i<scalar(@$data); $i++) {
	    $data->[$i]->[1] = "<a href='".$application->url."?page=Organism&organism=" . $data->[$i]->[0] . "'>" . $data->[$i]->[1] . "</a>";
	  }
	  my $table = $application->component('OrgResultTable');
	  $table->items_per_page(15);
	  $table->show_top_browse(1);
	  $table->columns( ['Genome ID', 'Genome Name', 'Domain'] );
	  $table->data($data);
	  $content .= "<h2>Found ".scalar(@$data)." occurrences in Organisms</h2>".$table->output()."<br>";
	} elsif ($type eq 'subsystem') {
	  my $filtered_data = [];
	  for (my $i=0; $i<scalar(@$data); $i++) {
	    if ($is_annotator || ($fig->is_exchangable_subsystem($data->[$i]->[0]) && $fig->usable_subsystem($data->[$i]->[0]))) {
	      push(@$filtered_data, [ "<a href='".$application->url."?page=Subsystems&subsystem=" . $data->[$i]->[0] . "'>" . $data->[$i]->[0] . "</a>" ] );
	    }
	  }
	  my $table = $application->component('SSResultTable');
	  $table->columns( ['Subsystem'] );
	  $table->data($filtered_data);
	  $table->items_per_page(15);
	  $table->show_top_browse(1);
	  $content .= "<h2>Found ".scalar(@$filtered_data)." occurrences in Subsystems</h2>".$table->output()."<br>";
	} elsif ($type eq 'functional_role') {
	  my $filtered_data = [];
	  for (my $i=0; $i<scalar(@$data); $i++) {
	    if ($is_annotator || ($fig->is_exchangable_subsystem($data->[$i]->[1]) && $fig->usable_subsystem($data->[$i]->[1]))) {
	      push(@$filtered_data, [ "<a href='".$application->url."?page=FunctionalRole&role=" . $data->[$i]->[0] . "&subsystem_name=" . $data->[$i]->[1] . "'>" . $data->[$i]->[0] . "</a>", "<a href='".$application->url."?page=Subsystems&subsystem=" . $data->[$i]->[1] . "'>" . $data->[$i]->[1] . "</a>" ] );
	    }
	  }
	  my $table = $application->component('FRResultTable');
	  $table->columns( ['Functional Role', 'Subsystem'] );
	  $table->data($filtered_data);
	  $table->items_per_page(15);
	  $table->show_top_browse(1);
	  $content .= "<h2>Found ".scalar(@$filtered_data)." occurrences in Functional Roles</h2>".$table->output()."<br>";
	} elsif ($type eq 'feature') {
	  my $result_data = [];
	  foreach my $item (@$data) {
	    my $func = $fig->function_of($item->[0]);
	    push(@$result_data, [ "<a href='?page=Annotation&feature=".$item->[0]."'>".$item->[0]."</a>", $fig->genus_species($item->[1]), $func ]);
	  }
	  my $table = $application->component('FeatureResultTable');
	  $table->columns( [ "ID", "Organism", "Function" ] );
	  $table->items_per_page(15);
	  $table->show_top_browse(1);
	  $table->data($result_data);
	  $content .= "<h2>Found ".scalar(@$result_data)." occurrences in Features</h2>".$table->output()."<br>";
	} elsif ($type eq 'proteins') {

	  @$data = map { [ "<a href='".$application->url."?page=Annotation&feature=" . $_->[0] . "'>" . $_->[0] . "</a>",
			   $_->[1],
			   "<a href='".$application->url."?page=Organism&organism=" . $_->[3] . "'>" . $_->[2] . "</a>",
			   $_->[4]
			] } @$data;
	  my $table = $application->component('ProtResultTable');
	  $table->columns( [ { name => 'Feature ID', sortable => 1, filter => 1 },
	                     { name => 'Function',   sortable => 1, filter => 1 },
	                     { name => 'Organism',   sortable => 1, filter => 1 },
	                     { name => 'Domain',     sortable => 1, filter => 1, operator => 'combobox' }
	                   ] );
	  $table->data($data);
	  $table->show_export_button({strip_html => 1});
	  $table->items_per_page(100);
	  $table->show_top_browse(1);
	  my $js = qq~<script>
function export_fids (id) {
  var data_index;
  for (i=0;i<table_list.length;i++) {
    if (id == table_list[i]) {
      data_index = i;
    }
  }
  var fields = "";
  var curr_id = "";
  var curr_stripped = "";
  for (i=0;i<table_filtered_data[data_index].length;i++) {
    curr_id = table_filtered_data[data_index][i][0];
    curr_stripped = curr_id.toString().replace(HTML_REPLACE, '');
    fields += "<input type='hidden' name='feature' value='" + curr_stripped + "'>";
  }
  document.getElementById('result_features').innerHTML = fields;
  document.forms.sequences_form.submit();
}
</script>~;
	  $content .= $js."<h2>Found ".scalar(@$data)." occurrences in Proteins</h2>".$self->start_form('sequences_form', { page => 'ShowSeqs', Sequence => 'DNA Sequence' })."<div style='display:none;' id='result_features'></div>".$self->end_form."<input type='button' value='show sequences' onclick='export_fids(\"".$table->id."\");'>".$table->output()."<br>";
	}
      }
    }
  } else {
    if ($result->{type}) {
      if ($result->{type} eq 'subsystem') {
	$cgi->param('subsystem', $result->{result});
	$application->redirect("Subsystems");
	$application->do_redirect();
	$cgi->delete('action');
	return 1;
      } elsif ($result->{type} eq 'organism') {
	$cgi->param('organism', $result->{result});
	$application->redirect("Organism");
	$cgi->delete('action');
	$application->do_redirect();
	return 1;
      } elsif ($result->{type} eq 'feature') {
	$cgi->param('feature', $result->{result});
	$application->redirect("Annotation");
	$cgi->delete('action');
	$application->do_redirect();
	return 1;
      }
    }
  }
  
  return $content;
}

sub check_search {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi();
  my $fig = $application->data_handle('FIG');

  $self->data('result', '');

    # check if we have a valid fig
  unless ($fig) {
    $application->add_message('warning', 'Invalid organism id');
    return "";
  }

  my $search = $cgi->param('pattern');

  # check if an id was passed
  unless (defined($search)) {
    $application->add_message('warning', 'no id passed to search');
    $application->redirect($application->session->get_entry( -previous => 1 ));
  }

  # first check if this is a fig id that we have. In that case, we can redirect
  if ($search =~ /^fig\|\d+\.\d+\.\w+\.\d+$/) {
    if ($fig->is_real_feature($search)) {
      $cgi->param('feature', $search);
      $application->redirect("Annotation");
      $cgi->delete('action');
      return 1;
    }
  }

  # check for context information, if we know the last organism
  # or fig id, we can try to construct a fig id
  my $prev = $application->session->get_entry( -previous => 1 );
  my $params = {};
  if ($prev && $prev ne 'NULL') {
    my @t = thaw($prev->{parameters});
    $params = $t[0];
  }
  my $prefix;
  if (defined($params->{feature})) {
    ($prefix) = $params->{feature}->[0] =~ /^(fig\|\d+\.\d+\.)\w+\.\d+$/;
  } elsif (defined($params->{organism})) {
    $prefix = "fig|".$params->{organism}->[0].".";
  } elsif (defined($params->{pattern})) {
    ($prefix) = $params->{pattern}->[0] =~ /^(fig\|\d+\.\d+\.)\w+\.\d+$/;
  }
  if ($prefix) {
    my $search_try = $prefix . $search;
    if ($search_try =~ /^fig\|\d+\.\d+\.\w+\.\d+$/) {
      if ($fig->is_real_feature($search_try)) {
	$cgi->param('feature', $search_try);
	$application->redirect("Annotation");
	$cgi->delete('action');
	return 1;
      }
    } else {
      $search_try = $prefix . "peg." . $search;
      if ($search_try =~ /^fig\|\d+\.\d+\.\w+\.\d+$/) {
	if ($fig->is_real_feature($search_try)) {
	  $cgi->param('feature', $search_try);
	  $application->redirect("Annotation");
	  $cgi->delete('action');
	  return 1;
	}
      }
    }
  }

  # now check the id correspondence for a unique hit
  my @ids = $fig->get_corresponding_ids($search, 1);
  foreach my $id (@ids) {
    if ($id->[1] eq 'SEED') {
      $cgi->param('feature', $id->[0]);
      $application->redirect("Annotation");
      $cgi->delete('action');
      return 1;
    }
  }

  # call to the annotation clearinghouse if it knows something
  my $result = SOAP::Lite->uri('http://www.nmpdr.org/AnnoClearinghouse_SOAP')->proxy('http://clearinghouse.nmpdr.org/aclh-soap.cgi')->find_seed_equivalent( $search )->result;

  if (ref($result) eq 'ARRAY') {
    if (scalar(@$result)) {
      my $orig = shift @$result;
      my $new = shift @$result;
      $application->add_message('info', "<em>$search</em> was found in <em>".$orig->[1]."</em>, which is not in our database. However, <em>".$new->[1]."</em> which is, contains this essentially identical protein (<em>".$new->[0]."</em>).");
      $cgi->param('feature', $new->[0]);
      $application->redirect("Annotation");
    }
  } else {
    $cgi->param('feature', $result);
    $application->redirect("Annotation");
    $cgi->delete('action');
    return 1;
  }

  $cgi->delete('action');

  return 1;
}

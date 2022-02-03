package SeedViewer::WebPage::Analysis;

use base qw( WebPage );

1;

use strict;
use warnings;

use FIG;
use FIGV;

=pod

=head1 NAME

Organism - an instance of WebPage which displays information about an Organism

=head1 DESCRIPTION

Display information about an Organism

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->application->no_bot(1);
  $self->application->register_component('FilterSelect', 'OrganismSelect');
  $self->application->register_component('Table', 'ResultTable');

  return 1;
}

=item * B<output> ()

Returns the html output of the Organism page.

=cut

sub output {
  my ($self) = @_;

  # fetch application, cgi and fig
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $fig = $application->data_handle('FIG');

  $self->title('Analysis');

  my $html = "<h2>Analysis</h2>";
  
  $html .= $self->start_form('upload_table_form',{ page => 'BrowseGenome' });

  $html .= $cgi->filefield(-name=>'upload_file')."<br>";
  # create the select organism component
  my $organism_select_component = $application->component('OrganismSelect');
  my $genome_list = $fig->genome_list();
  my @sorted_genome_list = sort { $a->[1] cmp $b->[1] } @$genome_list;
  my $org_values = [];
  my $org_labels = [];
  foreach my $line (@sorted_genome_list) {
    push(@$org_values, $line->[0]);
    push(@$org_labels, $line->[1]);
  }
  $organism_select_component->values( $org_values );
  $organism_select_component->labels( $org_labels );
  $organism_select_component->name('organism');
  $organism_select_component->width(800);
  $html .= $organism_select_component->output();
  $html .= $self->button();
  $html .= $self->end_form();

  return $html;
}

sub upload_table {
  my ($self) = @_;

  return $self->application->component('test')->upload_table();
}

sub required_rights {
  return [ ['login'] ];
}

# sub venn {
#   my ($self) = @_;

#   my $application = $self->application();
#   my $cgi = $application->cgi();
#   my $fig = new FIG;

#   my $genomes = [ '83333.1', '83334.1', '316407.3' ];

#   my $sim_cutoff = $cgi->param('cutoff') || "1.0e-10";

#   my $features_a = { 'id' => 'function' };
#   my $features_b = { 'id' => 'function' };
#   my $features_c = { 'id' => 'function' };

#   my $sim_ab;
#   my $sim_ac;
#   my $sim_bc;

#   my $data;
#   foreach my $feature_a (keys(%$features_a)) {
#     my $group = "A";
#     my @feature_b = ( '-', '-' );
#     my @feature_c = ( '-', '-' );
#     if (exists($sim_ab->{$feature_a})) {
#       $group .= "B";
#       @feature_b = ( $sim_ab->{$feature_a}, $features_b->{$sim_ab->{$feature_a}} );
#       delete($features_b->{$feature_b[0]});
#     }
#     if (exists($sim_ac->{$feature_a})) {
#       $group .= "C";
#       @feature_c = ( $sim_ac->{$feature_a}, $features_c->{$sim_ac->{$feature_a}} );
#       delete($features_c->{$feature_c[0]});
#     }

#     push(@$data, [ $group, $feature_a, $features_a->{$feature_a}, @feature_b, @feature_c ]);
#   }

#   foreach my $feature_b (keys(%$features_b)) {
#     my $group = "B";
#     my @feature_a = ( '-', '-' );
#     my @feature_c = ( '-', '-' );
#     if (exists($sim_bc->{$feature_b})) {
#       $group .= "C";
#       @feature_c = ( $sim_bc->{$feature_a}, $features_b->{$sim_bc->{$feature_b}} );
#       delete($features_c->{$feature_c[0]});
#     }

#     push(@$data, [ $group, @feature_a, $feature_b, $features_b->{$feature_b}, @feature_c ]);
#   }

#   foreach my $feature_c (keys(%$features_c)) {
#     my $group = "C";
#     my @feature_a = ( '-', '-' );
#     my @feature_b = ( '-', '-' );

#     push(@$data, [ $group, @feature_a, @feature_b, $feature_c, $features_c->{$feature_c} ]);
#   }

#   my $columns = [ { name => 'Group', filter => 1, operator => 'combobox' }, 'ID A', 'Function A', 'ID B', 'Function B', 'ID C', 'Function C' ];
  
#   my $table = $application->component('VennTable');
#   $table->data($data);
#   $table->columns($columns);

#   return $table->output();
# }

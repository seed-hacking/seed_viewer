package SeedViewer::WebPage::ComparisonResult;

use base qw( WebPage );

1;

use strict;
use warnings;

use FIG;
use FIGV;
use FIG_Config;

=pod

=head1 NAME

ComparisonResult

=head1 DESCRIPTION

Display a three way comparison result between Organisms

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->title('Comparison Result');
  $self->application->no_bot(1);
  $self->application->register_component('Table', 'ResultTable');

  return 1;
}

=item * B<output> ()

Returns the html output of the ComparisonResult page.

=cut

sub output {
  my ($self) = @_;

  # fetch application, cgi and fig
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $jobdir = '/vol/48-hour/Jobs.prod.2007-0601/408/';
  my $orgdir = $jobdir . 'rp/666666.257';
  my $fig = new FIGV($orgdir);

  # open comparison file
  my $data = [];
  open(FH, $jobdir."Yp_3way.table") or die ('argl');
  while (<FH>) {
    chomp;
    push(@$data, [split /\t/o]);
  }
  close FH;

  my $html = "<h2>Comparison Result</h2>";
  my $table = $application->component('ResultTable');
  $table->columns( [ { name => 'occurance', filter => 1, operator => 'combobox' }, { name => 'Function', filter => 1 }, $fig->genus_species('187410.1')." (A)", $fig->genus_species('214092.1')." (B)", $fig->genus_species('666666.257')." (C)" ] );
  $table->data($data);
  $table->items_per_page(25);
  $table->show_select_items_per_page(1);
  $table->show_top_browse(1);
  $table->show_bottom_browse(1);
  $table->show_export_button(1);
  $html .= $table->output();

  return $html;
}

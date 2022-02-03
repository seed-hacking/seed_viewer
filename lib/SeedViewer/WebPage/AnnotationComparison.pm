package SeedViewer::WebPage::AnnotationComparison;

use base qw( WebPage );

1;

use strict;
use warnings;

=pod

=head1 NAME

AnnotationComparison - an instance of WebPage which compares the SEED Annotations to a set up uploaded annotations

=head1 DESCRIPTION

Display a comparison between a SEED and a third party annotation

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
  my ($self) = @_;

  $self->application->no_bot(1);
  $self->application->register_component('Table', 'ResultTable');

  return 1;
}

=item * B<output> ()

Returns the html output of the AnnotationComparison page.

=cut

sub output {
  my ($self) = @_;

  # fetch application, cgi and fig
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $fig = $application->data_handle('FIG');

  my $org = $cgi->param('organism');
  my $orgname = $fig->genus_species($org);

  $self->title("Annotation Comparison for $orgname ($org)");

  my $html = "<h2>Annotation Comparison for $orgname ($org)</h2>";
  
  $html .= $self->start_form('upload_table_form', { organism => $org });
  $html .= "data file ".$cgi->filefield(-name=>'upload_file')."<input type='submit' value='upload'>";
  $html .= $self->end_form();

  # check if we have an upload file
  if ($cgi->param('upload_file')) {
    
    # get the features of the genome
    my $features = $fig->all_features_detailed_fast($org);
    my $org_dir = $self->dir_of_genome($org);
    
    # get the uploaded data
    my $file_content = "";
    my $file = $cgi->param('upload_file');
    while (<$file>) {
      $file_content .= $_;
    }
    my @lines = split /[\r\n]+/, $file_content;
    
    # organize the data
    my $data_a = {};
    my $data_b = {};
    foreach my $feature (@$features) {
      my $id = $feature->[0];
      next if $id !~ /\.peg\./;
      $feature->[1] =~ s/,.*//;
      my ($contig, $start, $stop) = $feature->[1] =~ /(.*)_(\d+)_(\d+)/;
      my $func = $feature->[6];
      my @subsystem_info = grep { $fig->usable_subsystem($_->[0], 1) } $fig->subsystems_for_peg_complete($id);
      my $ss_text = @subsystem_info ? (join ";<br>", map { "<a href='?page=Subsystems&subsystem=".$_->[0]."&organism=".$org."'>".$_->[0]." [".$_->[2]."]" } @subsystem_info) : "no";

      my @function_files = `grep -wF "$id" $org_dir/*_functions`;
      my $ff_text = '';

      if (@function_files > 0) {
	  if ($function_files[0] =~ /assigned_functions/) {
	      $ff_text = "SEED";
	  }
	  else {
	      # RAST organism
	      # proposed_user_functions overrides other files
	      shift @function_files if (@function_files > 1);
	      ($ff_text) = $function_files[0] =~ /proposed_(\w*)_functions/;
	      $ff_text = "FIGfam" if ((! defined $ff_text) || $ff_text eq '');
	  }
      }
      else {
	  $ff_text = "???";
      }

      unless (exists($data_a->{$contig})) {
	$data_a->{contig} = {};
      }
      $data_a->{$contig}->{$stop} = [ $id, $start, $func, $ss_text, $ff_text ];
    }
    foreach my $line_string (@lines) {
      my @line = split(/\t/, $line_string);
      my $id = $line[0];
      my $contig = $line[1];
      my $start = $line[2];
      my $stop = $line[3];
      my $func = $line[4];
      unless (exists($data_b->{$contig})) {
	$data_b->{contig} = {};
      }
      $data_b->{$contig}->{$stop} = [ $id, $start, $func ];
    }

    # match the data
    my $data = [];
    foreach my $contig (keys(%$data_a)) {
      foreach my $stop (keys(%{$data_a->{$contig}})) {
	if (exists($data_b->{$contig}) && exists($data_b->{$contig}->{$stop})) {
	  push(@$data, [ 'AB', $contig, $data_a->{$contig}->{$stop}->[1], $data_b->{$contig}->{$stop}->[1], $stop, $data_a->{$contig}->{$stop}->[2], $data_b->{$contig}->{$stop}->[2], { data => "<a href='?page=Annotation&feature=".$data_a->{$contig}->{$stop}->[0]."'>".$data_a->{$contig}->{$stop}->[0]."</a>" }, $data_a->{$contig}->{$stop}->[4], $data_a->{$contig}->{$stop}->[3], $data_b->{$contig}->{$stop}->[0] ]);
	  delete($data_b->{$contig}->{$stop});
	} else {
	  push(@$data, [ 'A', $contig, $data_a->{$contig}->{$stop}->[1], '-', $stop, $data_a->{$contig}->{$stop}->[2], '-',  { data => "<a href='?page=Annotation&feature=".$data_a->{$contig}->{$stop}->[0]."'>".$data_a->{$contig}->{$stop}->[0]."</a>" }, $data_a->{$contig}->{$stop}->[4], $data_a->{$contig}->{$stop}->[3], '-' ]);
	}
      }
    }
    foreach my $contig (keys(%$data_b)) {
      foreach my $stop (keys(%{$data_b->{$contig}})) {
	push(@$data, [ 'B', $contig, '-', $data_b->{$contig}->{$stop}->[1], $stop, '-', $data_b->{$contig}->{$stop}->[2], '-', '-', '-', $data_b->{$contig}->{$stop}->[0] ]);
      }
    }
    
    # sort the data
    @$data = sort { $a->[1] cmp $b->[1] || $a->[4] <=> $b->[4] } @$data;

    # create the result table
    my $result = $application->component('ResultTable');
    $result->data($data);
    $result->columns( [ { name => 'Presence', operator => 'combobox', filter => 1 }, { name => 'Contig', filter => 1, operator => 'combobox' }, { name => 'Start A', filter => 1, 'operators' => [ 'less', 'more', 'equal' ] }, { name => 'Start B', filter => 1, 'operators' => [ 'less', 'more', 'equal' ] }, { name => 'Stop', filter => 1, 'operators' => [ 'less', 'more', 'equal' ] }, { name => 'Annotation A', filter => 1 }, { name => 'Annotation B', filter => 1 }, { name => 'ID A', filter => 1 }, { name => 'Evidence', operator => 'combobox', filter => 1 }, { name => 'Subsystems', filter => 1 }, { name => 'ID B' } ] );
    $result->show_top_browse(1);
    $result->show_bottom_browse(1);
    $result->items_per_page(25);
    $result->show_select_items_per_page(1);
    $result->show_export_button({strip_html=>1});
    $result->show_clear_filter_button(1);
    $html .= $result->output();
  }
    
  return $html;
}

sub dir_of_genome {
    my($self, $id) = @_;

    my $application = $self->application();

    my $dir = "$FIG_Config::organisms/$id";

    if ($FIG_Config::rast_jobs) {
      my $rast = $application->data_handle('RAST');
      my $job = $rast->Job->get_objects( { genome_id => $id } );
      if (scalar(@$job)) {
	$dir = $FIG_Config::rast_jobs . "/" . $job->[0]->id() . "/rp/" . $id . "/";
      }
    }

    return $dir;
}


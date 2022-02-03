package SeedViewer::WebPage::ManageProblemSets;

# ManageProblemSets - a page to manage problem sets

# $Id: ManageProblemSets.pm,v 1.6 2008-09-03 20:48:26 parrello Exp $

use strict;
use warnings;

use base qw( WebPage );

use FIG;
use FIG_Config;
use DBMaster;

1;

=pod

=head1 NAME

ManageProblemSets - a page to manage problem sets

=head1 DESCRIPTION

Allows managing of problem sets

=head1 METHODS

=over 4

=item * B<init> ()

Initialize the page

=cut

sub init {
  my $self = shift;

  # set title
  $self->application->no_bot(1);
  $self->title('Manage Problem Sets');
  $self->application->register_action($self, 'create_problem_set', 'create_problem_set');
  $self->application->register_component('Table', 'ProblemSetTable');
  
}

=pod

=item * B<output> ()

Returns the html output of the ManageProblemSets page.

=cut

sub output {
  my ($self) = @_;
  
  my $content = "";

  my $application = $self->application;
  my $cgi = $application->cgi;
  my $fig = $application->data_handle('FIG');
  
  # check if we have a valid fig
  unless ($fig) {
    $application->add_message('warning', 'Invalid organism id');
    return "";
  }
  
  # connect to databases
  my $master = DBMaster->new(-database => $FIG_Config::teacher_db, -backend => 'SQLite');
  my $user = $application->session->user;
  my $teacher = $master->Teacher->init( { user => $user } );
  
  # check for teacher
  unless (ref($teacher)) {
    $application->add_message('warning', 'You are not a teacher');
    return "";
  }
  
  # form for creating a problem set
  $content .= "<h2>Create a Problem Set</h2>";
  $content .= $self->start_form( 'problem_set_form', { action => 'create_problem_set'} );
  $content .= "<table><tr><th>Name</th><td><input type='text' name='problem_set'>" . $self->button('create') . "</td></tr></table>";
  $content .= $self->end_form();

  $content .= "<h2>Available Problem Sets</h2>";

  # create the data for the problem set table
  my $data = [];

  # get all problem sets and iterate over them
  my $problem_sets = $master->ProblemSet->get_objects();
  foreach my $problem_set (@$problem_sets) {
    my $problems = $master->ProblemSetProblems->get_objects( { problemSet => $problem_set } );
    unless (scalar(@$problems)) {
      push(@$data, [ $problem_set->name(), '-', '- empty set -', '-', '-', '-', '-' ]);
    }
    foreach my $problem (@$problems) {
      my $orf_tool = "";
      if ($problem->problem->orf) {
	$orf_tool = $problem->problem->orf->tool();
      }
      push(@$data, [ $problem_set->name(),
		     $problem->problem->feature->display_id(),
		     $problem->problem->annotation() || "",
		     $problem->problem->teacherAnnotationComment() || "",
		     $orf_tool,
		     $problem->problem->teacherOrfComment() || "",
		     "<a href='?page=Evidence&feature=" . $problem->problem->feature->display_id() . "'>evidence</a>",
		     "<a href='?page=BrowseGenome&feature=" . $problem->problem->feature->display_id() . "'>browse</a>",
		     "<a href='?page=Annotation&feature=" . $problem->problem->feature->display_id() . "'>feature</a>",
		     "<input type='button' class='button' value='delete'>" ]);
    }
  }

  # fill the table
  my $problem_set_table = $application->component('ProblemSetTable');
  $problem_set_table->show_select_items_per_page(1);
  $problem_set_table->items_per_page(25);
  $problem_set_table->show_top_browse(1);
  $problem_set_table->show_bottom_browse(1);
  $problem_set_table->columns( [ { name => 'Name', filter => 1, operator => 'combobox' }, { name => 'Feature' }, { name => 'Annotation' }, { name => 'Comment' }, { name => 'ORF' }, { name => 'Comment' }, { name => 'evidence' }, { name => 'browse' }, { name => 'feature' }, { name => 'delete' } ] );
  $problem_set_table->data($data);

  # print table to content
  $content .= $problem_set_table->output();

  return $content;
}

sub create_problem_set {
  my ($self) = @_;

  # get the objects we need
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $user = $application->session->user();
  my $master = DBMaster->new(-database => $FIG_Config::teacher_db, -backend => 'SQLite');

  # sanity check parameters
  my $problem_set_name = $cgi->param('problem_set');

  unless (defined($problem_set_name)) {
    $application->add_message('warning', 'You must provide a name to create a problem set, aborting.');
    return 0;
  }

  # check if the name provided is unique
  my $existing_problem_set = $master->ProblemSet->init( { name => $problem_set_name } );
  if (ref($existing_problem_set)) {
    $application->add_message('warning', 'A problem set with that name already exists, aborting.');
    return 0;
  }

  # create the problem set
  $master->ProblemSet->create( { name => $problem_set_name } );
  
  # tell the user about success
  $application->add_message('info', "Problem Set $problem_set_name created.");

  return 1;
}

sub required_rights {
  return [ [ 'edit', 'problem_list' ], [ 'login' ] ];
}

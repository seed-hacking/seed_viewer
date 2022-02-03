package SeedViewer::WebPage::Teach;

# Teach - a page for teachers

# $Id: Teach.pm,v 1.9 2008-04-18 16:47:30 paczian Exp $

use strict;
use warnings;

use base qw( WebPage );

use FIG;
use DBMaster;
use FIG_Config;

1;

=pod

=head2 NAME

Teach - a page for teachers

=head2 DESCRIPTION

Allows evaluation of student performance

=head2 METHODS

=over 4

=item * B<init> ()

Initialize the page

=cut

sub init {
  my $self = shift;

  # set title
  $self->title('Teacher Page');
  $self->application->no_bot(1);

  # register components
  $self->application->register_component('Table', 'ResultTable');
  $self->application->register_component('Table', 'SolutionTable');
  $self->application->register_component('Ajax', 'ClassAjax');
  $self->application->register_action($self, 'delete_problem', 'delete');

}

=pod

=item * B<output> ()

Returns the html output of the Teacher page.

=cut

sub output {
  my ($self) = @_;

  my $application = $self->application;
  my $cgi = $application->cgi;
  my $fig = $application->data_handle('FIG');

  # check if we have a valid fig
  unless ($fig) {
    $application->add_message('warning', 'Invalid organism id');
    return "";
  }

  my $master = DBMaster->new(-database => $FIG_Config::teacher_db, -backend => 'SQLite');
  my $user = $application->session->user;
  my $teacher = $master->Teacher->init( { user => $user } ) or return "<h2>You are not a teacher</h2>";
  my $classes = $master->TeacherClasses->get_objects( { teacher => $teacher } );
  @$classes = map { $_->class() } @$classes;

  # initialize content
  my $content = "<h2>Class Selection</h2>";

  # print ajax
  $content .= $application->component('ClassAjax')->output();

  my $class_selection = "<form id='class_form' style='margin:0px;padding:0px;'><select name='class' onchange='execute_ajax(\"get_class_info\", \"class_info\", \"class_form\");'>\n";
  $class_selection .= "<option value=''>- select a class -</option>";
  my $curr_class;
  foreach my $class (@$classes) {
     unless (defined($curr_class)) {
       $curr_class = $class;
     }
    $class_selection .= "<option value='" . $class->name() . "'>" . $class->name() . "</option>\n";
  }
  $class_selection .= "</select></form>";

  unless (defined($curr_class)) {
    return "<h2>You currently have no classes</h2><p>Click <a href='?page=ManageClass'>here</a> to create a class</p>";
  }

  $content .= "<table><tr><th>Class</th><td>$class_selection</td></tr></table>";

  # create the div to put the class data into
  $content .= "<div id='class_info' name='class_info'>";
  $content .= "</div>";

  return $content;

}

# right functions
sub required_rights {
  return [ [ 'edit', 'problem_list' ] ];
}

sub supported_rights {
  return [ [ 'edit', 'problem_list', '*' ] ];
}

# actions
sub delete_problem {
  my ($self) = @_;

  my $application = $self->application();
  my $cgi = $application->cgi();

  my $master = DBMaster->new(-database => $FIG_Config::teacher_db, -backend => 'SQLite');
  my $user = $application->session->user;
  my $teacher = $master->Teacher->init( { user => $user } );
  unless ($teacher) {
    $application->add_message('warning', 'You are not a teacher, delete aborted');
    return 0;
  }

  my $problem_id = $cgi->param('problem');
  unless (defined($problem_id)) {
    $application->add_message('warning', 'No problem passed to delete, aborting');
    return 0;
  }

  my $feature = $master->Feature->init( { display_id => $problem_id });
  unless ($feature) {
    $application->add_message('warning', 'Feature of passed problem not found, aborting');
    return 0;
  }

  my $problem = $master->Problem->init( { feature => $feature } );
  unless (defined($problem)) {
    $application->add_message('warning', 'There is no problem for the passed feature, aborting');
    return 0;
  }

  $master->ProblemSetProblems->get_objects( { problem => $problem } )->[0]->delete();
  $problem->delete();
  $application->add_message('info', "Problem $problem_id deleted");

  return 1;
}

# ajax functions
sub get_class_info {
  my ($self) = @_;

  my $application = $self->application();
  my $cgi = $application->cgi();
  my $master = DBMaster->new(-database => $FIG_Config::teacher_db, -backend => 'SQLite');
  my $user = $application->session->user;
  my $teacher = $master->Teacher->init( { user => $user } ) or return "<h2>You are not a teacher</h2>";
  my $classes = $master->TeacherClasses->get_objects( { teacher => $teacher } );
  @$classes = map { $_->class() } @$classes;

  # check if the user has any classes
  unless (scalar(@$classes)) {
    return "<p>You currently have no classes.</p><p>Click <a href='?page=ManageClass'>here</a> to create one.</p>";
  }

  # check cgi params
  my $class_name = $cgi->param('class') || "";

  # initialize the class
  my $class = $master->Class->init( { name => $class_name } ) || $classes->[0];

  my $content = "";

  # get the problem set for the current class
  my $solution_set = $master->SolutionSet->get_objects( { class => $class } )->[0];
  my $problem_set = $solution_set->problemSet();
  $content .= "<h2>Solution Table</h2>";

  # check if we have a problem set assigned
  if (ref($problem_set)) {
    my $solution_table = $application->component('SolutionTable');
    $solution_table->columns( [ { name => 'Organism', sortable => 1, filter => 1 }, { name => 'Feature', sortable => 1, filter => 1 }, 'ORF', 'Annotation', 'Annotation', 'Browser', 'Delete' ] );
    my @problems = map { $_->problem() } @{$master->ProblemSetProblems->get_objects( { problemSet => $problem_set } )};
    my $data = [];
    foreach my $problem (@problems) {
      my $fid = $problem->feature->display_id();
      my $orf = $problem->orf();
      my $tool = "";
      if (defined($orf)) {
	$tool = $orf->tool();
      }
      $fid =~ /fig\|(\d+\.\d+)\.\w+\.(\d+)/;
      my $org_id = $1;
      my $fid_end = $2;
      push(@$data, [ "<a href='?page=Organism&organism=$org_id'>$org_id</a>",
		     $fid_end,
		     { data => $tool, tooltip => $problem->teacherOrfComment() || "- no comment -" },
		     { data => $problem->annotation() || "", tooltip => $problem->teacherAnnotationComment() || "- no comment -" },
		     "<a href='?page=Evidence&feature=$fid'>anno</a>",
		     "<a href='?page=BrowseGenome&feature=$fid'>browse</a>",
		     "<a href='?page=Teach&action=delete&problem=$fid'>delete</a>" ] );
    }
    $solution_table->data($data);
    $solution_table->items_per_page(25);
    $solution_table->show_select_items_per_page(1);
    $solution_table->show_top_browse(1);
    $solution_table->show_bottom_browse(1);
    $content .= $solution_table->output();
  } else {
    $content .= "<p>You have not yet assigned a problem set to this class.</p>\n";
    $content .= "<p>Click <a href='?page=ManageClass'>here</a> to do so</p>\n";
  }

  $content .= "<h2>Student Result Table</h2>";

  my $result_table = $application->component('ResultTable');
  $result_table->columns( [ { name => 'Student', sortable => 1, filter => 1, operator => 'combobox' }, { name => 'Organism', sortable => 1, filter => 1 }, { name => 'Feature', sortable => 1, filter => 1 },  'ORF', 'Annotation', 'Annotation', 'Browser' ] );
  my @solutions = map { $_->solution() } @{$master->SolutionSetSolutions->get_objects( { solutionSet => $solution_set } )};
  my $data = [];
  foreach my $solution (@solutions) {
    my $fid =  $solution->feature->display_id();
    my $orf = $solution->orf();
    my $tool = "";
    if (defined($orf)) {
      $tool = $orf->tool();
    }
    $fid =~ /fig\|(\d+\.\d+)\.\w+\.(\d+)/;
    my $org_id = $1;
    my $fid_end = $2;
    push(@$data, [ $solution->student->user->firstname() . " " . $solution->student->user->lastname(),
		   "<a href='?page=Organism&organism=$org_id'>$org_id</a>",
		   $fid_end,
		   { data => $tool, tooltip => $solution->studentOrfComment() || "- no comment -" },
		   { data => $solution->annotation() || "", tooltip => $solution->studentAnnotationComment() || "- no comment -" },
		   "<a href='?page=Evidence&feature=$fid'>anno</a>",
		   "<a href='?page=BrowseGenome&feature=$fid'>browse</a>" ] );
  }
  $result_table->show_export_button( { strip_html => 1 } );
  $result_table->data($data);
  $result_table->items_per_page(25);
  $result_table->show_select_items_per_page(1);
  $result_table->show_top_browse(1);
  $result_table->show_bottom_browse(1);

  $content .= $result_table->output();

  return $content;
}

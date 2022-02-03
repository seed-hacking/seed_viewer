package SeedViewer::WebPage::ManageClass;

# ManageClass - a page to manage classes

# $Id: ManageClass.pm,v 1.15 2008-09-03 20:48:26 parrello Exp $

use strict;
use warnings;

use base qw( WebPage );

use FIG;
use FIG_Config;
use DBMaster;
use WebConfig;

1;

=pod

=head1 NAME

ManageClass - a page to manage classes

=head1 DESCRIPTION

Allows managing of classes

=head1 METHODS

=over 4

=item * B<init> ()

Initialize the page

=cut

sub init {
  my $self = shift;

  # set title
  $self->title('Manage Class');
  $self->application->no_bot(1);
  $self->application->register_action($self, 'create_class', 'create_class');
  $self->application->register_action($self, 'delete_student_from_class', 'delete_student');
  $self->application->register_action($self, 'assign_problem_set', 'assign_problem_set');
  $self->application->register_component('Table', 'ClassTable');
  $self->application->register_component('Table', 'AssignmentTable');
  
}

=pod

=item * B<output> ()

Returns the html output of the ManageClass page.

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
  
  # get teacher's classes
  my $classes = $master->TeacherClasses->get_objects( { teacher => $teacher } );
  @$classes = map { $_->class() } @$classes;

  # allow problem assignment
  $content .= "<h2>Assign Problem Set to Class</h2>";
  my $assignment_table = $application->component('AssignmentTable');
  $assignment_table->columns( [ 'Class', 'Problem Set'] );
  my $data = [];
  my $problem_sets = $master->ProblemSet->get_objects();
  foreach my $class (@$classes) {
    my $solution_set = $master->SolutionSet->get_objects( { class => $class } )->[0];
    my $problem_set_select = $self->start_form('pset_form', { class => $class->name(), action => 'assign_problem_set' })."<select name='problem_set'>";
    foreach my $problem_set (@$problem_sets) {
      my $selected = "";
      if (defined($solution_set) && defined($solution_set->problemSet()) && ($problem_set->_id() eq $solution_set->problemSet->_id())) {
	$selected = " selected=selected";
      }
      $problem_set_select .= "<option value='" . $problem_set->name() . "'$selected>" . $problem_set->name() . "</option>\n";
    }
    $problem_set_select .= "</select>" . $self->button('set') . $self->end_form();
    push(@$data, [ $class->name(), $problem_set_select ]);
  }

  $assignment_table->data($data);
  $content .= $assignment_table->output();

  # create classes table
  $content .= "<h2>Class Information</h2>";
  if (scalar(@$classes)) {

    # get component
    my $class_table = $application->component('ClassTable');

    # prepare the columns
    $class_table->show_top_browse(1);
    $class_table->show_bottom_browse(1);
    $class_table->show_select_items_per_page(1);
    $class_table->items_per_page(20);
    $class_table->columns( [ { name => 'Class', filter => 1, operator => 'combobox', sortable => 1 },
			     { name => 'Lastname', filter => 1, sortable => 1 },
			     { name => 'Firstname', filter => 1, sortable => 1 },
			     { name => 'Login', filter => 1, sortable => 1 },
			     { name => 'eMail', filter => 1, sortable => 1 },
			     { name => 'remove' } ] );

    # create table data variable
    my $data = [];

    # iterate through the classes
    foreach my $class (@$classes) {

      # get all students of this class
      my $student_classes = $master->StudentClasses->get_objects( { class => $class } );
      foreach my $student_class (@$student_classes) {
	my $student = $student_class->student->user();
	push(@$data, [ $class->name(), $student->firstname(), $student->lastname(), $student->login(), $student->email(), $self->start_form('delete_student_form', { action => 'delete_student', student => $student->_id(), class => $class->name() }).$self->button("delete").$self->end_form() ]);
      }
    }
    $class_table->data($data);
    
    $content .= $class_table->output();
    
  } else {
    $content .= "<p>You currently have no classes</p>";
  }

  # create class form
  $content .= "<h2>Create a new class</h2>";
  $content .= "<p style='width: 800px;'>To create a class, create a plain text file with one line for every student. Each line should be a list of four items, separated by a tab. The items must be <b>firstname</b> <b>lastname</b> <b>login</b> <b>email</b>. If you are unsure of what a plain text file is, how to create a tab separated line, or any other part of this process, please refer to the manual at <a href='http://cgat-wiki.mcs.anl.gov/index.php/The_teacher_tool'>wiki</a></p>";
  $content .= $self->start_form('create_class_form', { action => 'create_class'});
  $content .= "<table>";
  $content .= "<tr><th>Class Name</th><td><input type='text' name='classname'></td></tr>";
  $content .= "<tr><th>Student File</th><td><input type='file' name='student_file'>" . $self->button('create') . "</td></tr>";
  $content .= "</table>";
  $content .= $self->end_form();
  $content .= "<br><br><br>";
  
  return $content;
}

sub create_class {
  my ($self) = @_;

  # get some objects we need
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $user = $application->session->user();
  my $app_master = $application->dbmaster();
  my $master = DBMaster->new(-database => $FIG_Config::teacher_db, -backend => 'SQLite');

  # sanity check parameters
  my $class_name = $cgi->param('classname');
  my $student_file = $cgi->param('student_file');

  unless (defined($class_name) && defined($student_file)) {
    $application->add_message('warning', "You must enter both a student file and a class name, aborting.");
    return 0;
  }

  # get the teacher
  my $teacher = $master->Teacher->init( { user => $user } );
  unless (ref($teacher)) {
    $application->add_message('warning', "You are not a teacher, aborting.");
    return 0;
  }

  # check the class
  my $class = $master->Class->init( { name => $class_name } );
  if (ref($class)) {
    
    # the class exists, check if the current teacher is a teacher of it
    my $teacher_class = $master->TeacherClasses->get_objects( { class => $class, teacher => $teacher } );
    unless (scalar(@$teacher_class)) {
      $application->add_message('warning', "The class $class_name was already used by another teacher, aborting.");
      return 0;
    }
  } else {
    
    # this is a new class, create it
    $class = $master->Class->create( { name => $class_name } );
    
    # make the current teacher a teacher for this class
    $master->TeacherClasses->create( { teacher => $teacher, class => $class } );
  }

  # check if the class has a solution set, if not, create one
  my $solution_sets = $master->SolutionSet->get_objects( { class => $class } );
  unless (scalar(@$solution_sets)) {
    $master->SolutionSet->create( { class => $class,
				    name => "Class $class_name Solution Set" } );
  }

  # go through the file and create / retrieve students
  my $students;
  my $failed;
  my $i = 0;
  my $file_content = "";
  while (<$student_file>) {
    $file_content .= $_;
  }
  my @lines = split /[\r\n]+/, $file_content;
  foreach my $line (@lines) {

    # increment line counter
    $i++;

    # parse the upload file line by line
    my ($firstname, $lastname, $login, $email, $bogus) = split /\t/, $line;

    # check for invalid items
    if (defined($bogus)) {
      push(@$failed, [ "the line could not be parsed, incorrect number of parameters ($bogus).", $i]);
      next;
    }

    # check if all neccessary parameters are present
    unless ($firstname && $lastname && $login && $email) {
      push(@$failed, [ 'the line could not be parsed', $i]);
      next;
    }

    # check if the email valid
    unless ($email =~ /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i) {
      push(@$failed, [ "of an invalid email address ($email)", $i]);
      next;
    }

    # check if the login is valid
    unless ($login =~ /[\w\d]+/) {
      push(@$failed, [ "of an invalid login ($login), please use only letters and numbers", $i]);
      next;
    }

    # check if the firstname is valid
    unless ($firstname =~ /[\w\.\s\d\']+/) {
      push(@$failed, [ "of an invalid firstname ($firstname), please use only letters, numbers, spaces, apostrophes and periods.", $i]);
      next;
    }

    # check if the lastname is valid
    unless ($lastname =~ /[\w\.\s\d\']+/) {
      push(@$failed, [ "of an invalid lastname ($lastname), please use only letters, numbers, spaces, apostrophes and periods.", $i]);
      next;
    }

    # check if the user is already in the database
    my $student;
    my $user_by_login = $app_master->User->init( { login => $login } );
    if (ref($user_by_login)) {
      if ($email eq $user_by_login->email()) {
	$student = $user_by_login;
      } else {
	push(@$failed, [ 'login and email provided do not match login and email in database', $i ]);
	next;
      }
    } else {
      my $user_by_email = $app_master->User->init( { email => $email } );
      if (ref($user_by_email)) {
	if ($login eq $user_by_email->login()) {
	  $student = $user_by_email;
	} else {
	  push(@$failed, [ 'login and email provided do not match login and email in database', $i ]);
	  next;
	}
      }
    }

    # if the user does not exist, create them
    unless (ref($student)) {
      $student = $app_master->User->create( { firstname => $firstname,
					      lastname => $lastname,
					      login => $login,
					      email => $email } );
    }

    # add and grant login right to the student if they do not yet have it
    unless ($student->has_right($application, 'login')) {
      $student->add_login_right($application);
      $student->grant_login_right($application);
    }
    
    # get cgat student scope
    my $cgat_scope = $app_master->Scope->get_objects( { name => 'cgat_student' } )->[0];
    my $student_has_scope = $app_master->UserHasScope->get_objects( { scope => $cgat_scope,
								      user => $student } );
    unless (scalar(@$student_has_scope)) {
      $app_master->UserHasScope->create( { scope => $cgat_scope,
					   user => $student,
					   granted => 1 } );
    }

    # check if the user is a student, if not, make them one
    my $is_student = $master->Student->init( { user => $student } );
    if (ref($is_student)) {
      $student = $is_student;
    } else {
      $student = $master->Student->create( { user => $student } );
    }

    # check if the student is already member of the class, otherwise make them one
    my $is_member = $master->StudentClasses->get_objects( { student => $student, class => $class } );
    if (scalar(@$is_member)) {
      push(@$failed, [ $student->user->firstname() . " " . $student->user->lastname() . " already was a student of class $class_name", $i ]);
    } else {
      $master->StudentClasses->create( { student => $student, class => $class } );
      push(@$students, $student);
    }
  }

  # print the report on screen and prepare a mail to the teacher
  my $report_mail_body = "You have created or updated the class $class_name\n\nThe following student accounts were created:\n";
  foreach my $student (@$students) {
    $application->add_message('info', "Student " . $student->user->firstname() . " " . $student->user->lastname() . " added to class $class_name.");
    $report_mail_body .= $student->user->firstname() . " " . $student->user->lastname() . " with login " . $student->user->login . " and email " . $student->user->email . "\n";
  }

  $report_mail_body .= "\nThe following lines of your upload file failed to import:\n";
  foreach my $failure (@$failed) {
    $application->add_message('warning', "Student file line " . $failure->[1] . " failed to import, because " . $failure->[0]);
    $report_mail_body .= "line " . $failure->[1] . " failed to import, because " . $failure->[0] . "\n";
  }

  $user->send_email($WebConfig::ADMIN_EMAIL, "CGAT - Class creation / update report", $report_mail_body);
  
  return 1;
}

sub delete_student_from_class {
  my ($self) = @_;

  # initialize objects
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $master = DBMaster->new(-database => $FIG_Config::teacher_db, -backend => 'SQLite');
  my $app_master = $application->dbmaster();

  # check cgi params
  my $student_id = $cgi->param('student');
  my $class_name = $cgi->param('class');

  unless (defined($student_id) && defined($class_name)) {
    $application->add_message('warning', "You must submit both student and class to delete, aborting.");
    return 0;
  }

  # get student and class objects
  my $student_user = $app_master->User->get_objects( { _id => $student_id } )->[0];
  my $student = $master->Student->init( { user => $student_user } );
  my $class = $master->Class->init( { name => $class_name } );

  # check if student is a member of the class
  my $student_classes = $master->StudentClasses->get_objects( { student => $student, class => $class } );
  if (scalar(@$student_classes)) {
    $student_classes->[0]->delete();
    $application->add_message('info', "Student " . $student_user->firstname() . " " . $student_user->lastname() . " removed from class $class_name");
  } else {
    $application->add_message('warning', "Student " . $student_user->firstname() . " " . $student_user->lastname() . " is not a member of class $class_name, aborting.");
    return 0;
  }

  return 1;
}

sub assign_problem_set {
  my ($self) = @_;

  # get the objects we need
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $master = DBMaster->new(-database => $FIG_Config::teacher_db, -backend => 'SQLite');
  my $app_master = $application->dbmaster();

  # sanity check cgi params
  my $class_name = $cgi->param('class');
  my $problem_set_name = $cgi->param('problem_set');

  unless (defined($class_name) && defined($problem_set_name)) {
    $application->add_message('warning', "You must define both a class and a problem set to assign, aborting.");
    return 0;
  }

  # get class, problem set and solution set objects
  my $class = $master->Class->init( { name => $class_name } );
  my $problem_set = $master->ProblemSet->init( { name => $problem_set_name } );
  my $solution_set = $master->SolutionSet->get_objects( { class => $class } )->[0];

  # assign the problem set to the solution set of the class
  $solution_set->problemSet($problem_set);

  # tell the user what we did
  $application->add_message('info', "Problem set $problem_set_name assigned to class $class_name");

  return 1;
}

sub required_rights {
  return [ [ 'edit', 'problem_list' ], [ 'login' ] ];
}

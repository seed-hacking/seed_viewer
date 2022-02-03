package SeedViewer::WebPage::ClassAnnotationResolve;

# ClassAnnotationResolve - a page to resolve annotations done by students

# $Id: ClassAnnotationResolve.pm,v 1.7 2008-09-03 20:48:26 parrello Exp $

use strict;
use warnings;

use base qw( WebPage );

use FIG;
use DBMaster;
use FIG_Config;

1;

=pod

=head1 NAME

ClassAnnotationResolve - a page to resolve annotations done by students

=head1 DESCRIPTION

Allows the resolving of student annotations of a genome and export to Genbank format.

=head1 METHODS

=over 4

=item * B<init> ()

Initialize the page

=cut

sub init {
  my $self = shift;

  # set title
  $self->title('Annotation Resolve');
  $self->application->no_bot(1);

  # register components
  $self->application->register_component('Table', 'ResultTable');
  $self->application->register_component('Ajax', 'ClassAjax');
  $self->application->register_action($self, 'set_master_annotations', 'set_master_annotations');
  
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

  my $class_name = "";
  if (defined($cgi->param('class'))) {
    $class_name = $cgi->param('class');
  }

  my $master = DBMaster->new(-database => $FIG_Config::teacher_db, -backend => 'SQLite');
  my $user = $application->session->user;
  my $teacher = $master->Teacher->init( { user => $user } ) or return "<h2>You are not a teacher</h2>";
  my $classes = $master->TeacherClasses->get_objects( { teacher => $teacher } );
  @$classes = map { $_->class() } @$classes;

  # create the javascript for the buttons
  my $js = &js();

  # initialize content
  my $content = $js . "<h2>Class Selection</h2><img src=\"$FIG_Config::cgi_url/Html/clear.gif\" onload='execute_ajax(\"get_class_info\", \"class_info\", \"class=$class_name\");'>";

  # print ajax
  $content .= $application->component('ClassAjax')->output();

  my $class_selection = "<form id='class_form' style='margin:0px;padding:0px;'><select name='class' onchange='execute_ajax(\"get_class_info\", \"class_info\", \"class_form\");' onload='execute_ajax(\"get_class_info\", \"class_info\", \"class_form\");'>\n";
  $class_selection .= "<option value=''>- select a class -</option>";
  my $curr_class;
  foreach my $class (@$classes) {
    my $selected = "";
    unless (defined($curr_class)) {
      $curr_class = $class;
    }
    if ($class->name() eq $class_name) {
      $selected = " selected=selected";
    }
    $class_selection .= "<option value='" . $class->name() . "'$selected>" . $class->name() . "</option>\n";
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

  unless ($class_name) {
    return "";
  }

  # initialize the class
  my $class = $master->Class->init( { name => $class_name } ) || $classes->[0];

  my $content = "";

  # get the problem set for the current class
  my $solution_set = $master->SolutionSet->get_objects( { class => $class } )->[0];
  my $problem_set = $solution_set->problemSet();

  $content .= "<h2>Student Result Table</h2>";
  
  my $result_table = $application->component('ResultTable');
  $result_table->columns( [ { name => 'Student', sortable => 1, filter => 1, operator => 'combobox' }, { name => 'Organism', sortable => 1, filter => 1 }, { name => 'Feature', sortable => 1, filter => 1 },  'ORF start', { name => 'Student Comment', visible => 0 }, { name => 'Master ORF start', visible => 0 }, 'promote to master', 'Annotation', { name => 'Student Comment', visible => 0 }, { name => 'Master Annotation', visible => 0}, 'promote to master' ] );
  my @solutions = map { $_->solution() } @{$master->SolutionSetSolutions->get_objects( { solutionSet => $solution_set } )};
  $result_table->show_select_items_per_page(1);
  $result_table->items_per_page(25);
  $result_table->show_top_browse(1);
  $result_table->show_bottom_browse(1);
  my $data = [];
  foreach my $solution (@solutions) {
    next unless $solution->annotation();
    my $fid =  $solution->feature->display_id();
    $fid =~ /fig\|(\d+\.\d+)\.\w+\.(\d+)/;
    my $org_id = $1;
    my $fid_end = $2;
    my $master_annotation = "";
    my $master_orf = "";
    my $master_annotation_object = $master->Annotation->init( { display_id => $solution->feature->display_id() } );
    if (ref($master_annotation_object)) {
      $master_annotation = $master_annotation_object->annotation();
      $master_orf = $master_annotation_object->start() || "";
    }
    my $orf = "";
    if ($solution->orf()) {
      $orf = $solution->orf->start();
    }
    my $annotation = "";
    if ($solution->annotation()) {
      $annotation = $solution->annotation();
    }
    my $orf_highlight;
    if ($master_orf) {
      if ($master_orf eq $orf) {
	$orf_highlight = "#00ff00";
      } else {
	$orf_highlight = "#ff0000";
      }
    }
    my $anno_highlight;
    if ($master_annotation) {
      if ($master_annotation eq $annotation) {
	$anno_highlight = "#00ff00";
      } else {
	$anno_highlight = "#ff0000";
      }
    }
    my $orf_comment = $solution->studentOrfComment()  || "- no comment -";
    my $anno_comment = $solution->studentAnnotationComment() || "- no comment -";
    $orf_comment =~ s/\^//g;
    $anno_comment =~ s/\^//g;
    $orf_comment =~ s/\#/No\./g;
    $anno_comment =~ s/\#/No\./g;
    $orf_comment =~ s/\n/ /g;
    $anno_comment =~ s/\n/ /g;
    $orf_comment =~ s/\r/ /g;
    $anno_comment =~ s/\r/ /g;
    $orf_comment =~ s/\t/ /g;
    $anno_comment =~ s/\t/ /g;
    push(@$data, [ $solution->student->user->firstname() . " " . $solution->student->user->lastname(),
		   "<a href='?page=Organism&organism=$org_id'>$org_id</a>",
		   $fid_end,
		   { data => $orf,
		     tooltip => $orf_comment,
		     highlight => $orf_highlight },
		   $orf_comment,
		   $master_orf,
		   "<input type='checkbox' name='orfs' value='" . $solution->_id() . "'>",
		   { data => $annotation,
		     tooltip => $anno_comment,
		     highlight => $anno_highlight },
		   $anno_comment,
		   $master_annotation,
		   "<input type='checkbox' name='annotations' value='" . $solution->_id() . "'>" ] );
  }
  $result_table->show_export_button( { strip_html => 1 } );
  $result_table->data($data);

  # create a submit button
  my $submit_button = $self->button('update master annotations', onclick => 'document.forms.annotation_form.submit();') .
                      $self->button('export master annotations', type => 'button') .
                      "<br/>";

  # create a check / uncheck all buttons
  my $check_all_button = $self->button('check all orfs', type => 'button', onclick => 'check_all_orf();') .
                         $self->button('uncheck all orfs', type => 'button', onclick => 'uncheck_all_orf();') .
                         $self->button('check all annotations', type => 'button', onclick => 'check_all_anno();') .
                         $self->button('uncheck all annotations', type => 'button', onclick => 'uncheck_all_anno();') .
                         "<br/>";

  # create buttons to turn on/off master columns
  my $master_buttons = $self->button('show master ORF starts', type => 'button', id => 'm_orf',
                                     onclick => 'show_master_orf();') .
                       $self->button('show master annotations', id => 'm_anno',
                                     onclick => 'show_master_anno();');

  $content .= $self->start_form('annotation_form', { action => 'set_master_annotations', class => $class_name }).$submit_button.$check_all_button.$master_buttons.$result_table->output().$self->end_form();

  return $content;
}

# actions
sub set_master_annotations {
  my ($self) = @_;

  # get some objects we need
  my $application = $self->application();
  my $cgi = $application->cgi();

  # get the list of annotations from the cgi
  my @annotations = $cgi->param('annotations');
  
  # get the list of orfs from the cgi
  my @orfs = $cgi->param('orfs');

  # get a master
  my $master = DBMaster->new(-database => $FIG_Config::teacher_db, -backend => 'SQLite');

  # iterate over the solutions and make their annotations the master annotations
  foreach my $annotation (@annotations) {
    my $solution_object = $master->Solution->get_objects( { _id => $annotation } );
    if (scalar(@$solution_object)) {
      $solution_object = $solution_object->[0];
    } else {
      next;
    }
    my $annotation_object = $master->Annotation->init( { display_id => $solution_object->feature->display_id() } );
    if (ref($annotation_object)) {
      $annotation_object->annotation($solution_object->annotation());
    } else {
      my $org_id = $solution_object->feature->display_id();
      $org_id =~ s/^fig\|(\d+\.\d+)\..+\.\d+$/$1/;
      $master->Annotation->create( { display_id => $solution_object->feature->display_id(),
				     organism   => $org_id,
				     contig     => $solution_object->feature->contig(),
				     annotation => $solution_object->annotation() } );
    }
  }

  # iterate over the solutions and make their orfs the master orfs
  foreach my $orf (@orfs) {
    my $solution_object = $master->Solution->get_objects( { _id => $orf } );
    if (scalar(@$solution_object)) {
      $solution_object = $solution_object->[0];
    } else {
      next;
    }
    next unless $solution_object->orf();
    my $annotation_object = $master->Annotation->init( { display_id => $solution_object->feature->display_id() } );
    if (ref($annotation_object)) {
      $annotation_object->start($solution_object->orf->start());
      $annotation_object->stop($solution_object->orf->stop());
    } else {
      my $org_id = $solution_object->feature->display_id();
      $org_id =~ s/^fig\|(\d+\.\d+)\..+\.\d+$/$1/;
      $master->Annotation->create( { display_id => $solution_object->feature->display_id(),
				     organism   => $org_id,
				     contig     => $solution_object->feature->contig(),
				     start      => $solution_object->orf->start(),
				     stop       => $solution_object->orf->stop() } );
    }
  }

  return 1;
}

sub js {
  return qq~<script>
function check_all_anno () {
    var all_checkboxes = document.getElementsByName('annotations');
    for (i=0; i<all_checkboxes.length; i++) {
        all_checkboxes[i].checked = true;
    }
}

function uncheck_all_anno () {
    var all_checkboxes = document.getElementsByName('annotations');
    for (i=0; i<all_checkboxes.length; i++) {
        all_checkboxes[i].checked = false;
    }
}

function check_all_orf () {
    var all_checkboxes = document.getElementsByName('orfs');
    for (i=0; i<all_checkboxes.length; i++) {
        all_checkboxes[i].checked = true;
    }
}

function uncheck_all_orf () {
    var all_checkboxes = document.getElementsByName('orfs');
    for (i=0; i<all_checkboxes.length; i++) {
        all_checkboxes[i].checked = false;
    }
}

function show_master_orf () {
    var mbutton = document.getElementById('m_orf');
    if (mbutton.value == 'show master ORF starts') {
        mbutton.value = 'hide master ORF starts';
        show_column(0, 4);
    } else {
        mbutton.value = 'show master ORF starts';
        hide_column(0, 4);
    }
}

function show_master_anno () {
    var mbutton = document.getElementById('m_anno');
    if (mbutton.value == 'show master annotations') {
        mbutton.value = 'hide master annotations';
        show_column(0, 7);
    } else {
        mbutton.value = 'show master annotations';
        hide_column(0, 7);
    }
}

</script>
~;
}

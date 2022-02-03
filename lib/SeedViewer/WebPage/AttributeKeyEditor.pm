#!/usr/bin/perl -w

#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#

package SeedViewer::WebPage::AttributeKeyEditor;

    use strict;
    use Tracer;
    use CustomAttributes;
    use WebComponent::Table;

use base qw(WebPage);

=head1 AttributeKeyEditor Page


=head2 Introduction

This page allows an authorized user to create and change attribute keys. In
addition to updating the attribute description, the user may choose the groups
to which each attribute belongs.
=cut

=head3 init

    $page->init();

Initialize the page. This method sets the display title and must register any
necessary components.

=cut

sub init {
    my ($self) = @_;
    $self->title('Attribute Key');
    $self->application->register_component('Table', 'Table');
    return 1;
}

=head3 output

    $page->output();

Return the html output of this page. The page uses the following CGI parameters.

=over 4

=item key

Attribute key to edit. If it does not exist in the database, it will be created.

=item description

Description of the attribute key. The default is the existing description.

=item groups

List of groups to which the key belongs. The default is the existing list of
groups.

=item task

Action to perform. If C<SHOW>, no action is taken. If C<STORE>, the attribute
key is inserted or updated If C<ERASE>, all the key's values are erased. If
C<DELETE>, the key is deleted from the database.

=back

=cut

sub output {
    my ($self) = @_;
    # Get the application object.
    my $application = $self->application();
    # Get access to the data store.
    my $fig = $application->data_handle('FIG');
    # The HTML lines will go in here.
    my @lines = ();
    # Get access to the form fields.
    my $cgi = $application->cgi();
    # Get access to the attributes.
    my $ca = CustomAttributes->new();
    # Compute the action.
    my $action = $cgi->param('task') || 'SHOW';
    # If the key exists, its data record will be put in here.
    my $keyRecord;
    # We'll put the description and group list in here.
    my ($description, @groups);
    # Check the attribute key.
    my $key = $cgi->param('key');
    # If no key was specified, we skip the key-related stuff.
    if ($key) {
        # Check to see if the key exists.
        $keyRecord = $ca->GetEntity(AttributeKey => $key);
        # Process according to the action. If it's STORE, we want to use
        # the user's values for the description and group list. Otherwise, we
        # use the 
        if ($action ne 'STORE') {
            # Here we're displaying the key. If it's new, we use blank
            # values. Otherwise, we get them from the database.
            if (! defined $keyRecord) {
                $description = '';
                @groups = ();
            } else {
                $description = $keyRecord->PrimaryValue('AttributeKey(description)');
                @groups = $ca->GetFlat(['IsInGroup'], "IsInGroup(from-link) = ?",
                                       [$key], 'IsInGroup(to-link)');
            }
        } else {
            # Here we're doing an edit. The data is taken from the user's input.
            $description = $cgi->param('description') || '';
            @groups = $cgi->param('groups');
        }
        # Now we create the form for updating the attribute data.
        push @lines, $cgi->start_form(-action => $application->url);
        push @lines, $cgi->hidden(-name => 'page', -value => 'AttributeKeyEditor');
        push @lines, $cgi->hidden(-name => 'key',  -value => $key);
        push @lines, $cgi->start_table();
        push @lines, $cgi->Tr($cgi->th({ class => 'aname' }, 'Attribute Key'),
                              $cgi->td($key));
        push @lines, $cgi->Tr($cgi->th({ class => 'aname' }, 'Description'),
                              $cgi->td($cgi->textarea(-name => 'description',
                                                      -rows => 10,
                                                      -columns => 60,
                                                      -default => $description)));
        # Now comes the group checkboxes. We have a checkbox for every possible
        # group, and pre-select the ones currently connected to the key.
        my @allGroups = $ca->GetFlat(['AttributeGroup'], "ORDER BY AttributeGroup(id)", [],
                                                     'AttributeGroup(id)');
        push @lines, $cgi->Tr($cgi->th({ class => 'aname' }, 'Groups'),
                              $cgi->td($cgi->checkbox_group(-name => 'groups',
                                                            -values => \@allGroups,
                                                            -default => \@groups,
                                                            -columns => 6)));
        # At the bottom we have a row of action buttons. The buttons shown depend
        # on whether or not we have a new key or an old one and what we're
        # doing with it.
        my @buttons = 'STORE';
        if (defined $keyRecord && $action ne 'DELETE' || $action eq 'STORE') {
            push @buttons, qw(ERASE DELETE);
        }
        my @buttonHTMLs = map { $self->button($_, name => 'task') } @buttons;
        push @lines, $cgi->Tr($cgi->th({ class => 'aname' }, '&nbsp;'),
                              $cgi->td({ align => 'center'}, join(' ', @buttonHTMLs)));
        push @lines, $cgi->end_table();
        push @lines, $cgi->end_form();
    }
    # Let the user see some sample attribute values. This
    # only works, of course, if we have a key with values to display.
    if ($keyRecord) {
        # Check for some values.
        my @attrData = $ca->QueryAttributes('$key = ? LIMIT 20', [$key]);
        if (! @attrData) {
            push @lines, "Attribute key $key has no values.";
        } else {
            # We have values, so we can create the table. First, compute the
            # number of columns. This is variable, so we need to find the
            # largest column count in the attribute data.
            my $cols = 3;
            for my $row (@attrData) {
                my $myCols = scalar @$row;
                if ($myCols > $cols) {
                    $cols = $myCols;
                }
            }
            my @headers = ({name => 'Objects'}, {name => 'Keys'}, {name => 'Data'});
            while (scalar(@headers) < $cols) {
                push @headers, {name => ' '};
            }
            # Now we have enough columns to cover all the data lines. Put out an HTML header.
            push @lines, $cgi->h3("Sample values for $key.");
            # Create the table component.
            my $mainTable = $application->component('Table');
            $mainTable->columns(\@headers);
            $mainTable->data(\@attrData);
            push @lines, $mainTable->output();
        }
    }
    # Now we've displayed everything the user needs to know about this attribute.
    # The next step is to perform whatever action he's requested: Store, Erase,
    # or Delete. This is only possible if we have a key.
    if (defined $key) {
        if ($action eq 'STORE') {
            $ca->StoreAttributeKey($key, $description, \@groups);
            push @lines, $cgi->p("Attribute $key updated.");
        } elsif ($action eq 'DELETE') {
            my $stats = $ca->DeleteAttributeKey($key);
            push @lines, $cgi->p("Attribute $key deleted from database: " . $stats->Display());
        } elsif ($action eq 'ERASE') {
            $ca->EraseAttribute($key);
            push @lines, $cgi->p("Values for attribute $key erased.");
        }
    }
    # Finally, we create some forms used for navigation and stuff. These work even if
    # no key was specified by the user.
    push @lines, attribute_navigator($ca, $application);
    # Return the page.
    return join("\n", @lines);
}

=head3 required_rights

    $page->required_rights();

This method lists the rights required to use this page. It returns a list of 3-tuples.
The first element of each tuple is a right type (view, change, administer, login), the second
is a data type, and the final element is a data id. The user must have all the
listed rights in order to use the page.

=cut

sub required_rights {
    return [  [qw(edit attribute *)], ];
}

=head3 attribute_navigator

    my $html = AttributeKeyEditor::attribute_navigator($ca);

Generate the attribute navigator panel. The panel is shared by both the
key and group editors, and allows the user to select an existing group or
key, or a new group or key.

=over 4

=item ca

CustomAttributes object used to access the attribute database.

=item application

WebApplication object for this application.

=item RETURN

Returns an HTML table containing forms that allow the user to display an
attribute key or group.

=back

=cut

sub attribute_navigator {
    # Get the parameters.
    my ($ca, $application) = @_;
    # We'll accumulate lines of HTML in here.
    my @lines;
    # Get all the groups and keys.
    my @keys = $ca->GetFlat(['AttributeKey'], "ORDER BY AttributeKey(id)", [],
                            'AttributeKey(id)');
    my @groups = $ca->GetFlat(['AttributeGroup'], "ORDER BY AttributeGroup(id)",
                              [], 'AttributeGroup(id)');
    # We're building four forms that differ just enough to make creating
    # them with a loop impractical.
    push @lines, "<p>&nbsp;</p>";
    push @lines, CGI::start_form(-action => $application->url);
    push @lines, CGI::hidden(-name => 'page', -value => 'AttributeKeyEditor',
                             -override => 1);
    push @lines, CGI::hidden(-name => 'task', -value => 'SHOW',
                             -override => 1);
    push @lines, CGI::start_table();
    push @lines, CGI::Tr(CGI::th({ class => 'aname' }, 'Select a Key'),
                         CGI::td({ class => 'amenu' },
                                 CGI::popup_menu(-name => 'key', -values => \@keys)),
                         CGI::td({ class => 'abutton' }, CGI::submit(-class => 'button', -value => 'SHOW')));
    push @lines, CGI::end_table();
    push @lines, CGI::end_form();
    push @lines, CGI::start_form(-action => $application->url);
    push @lines, CGI::hidden(-name => 'page', -value => 'AttributeKeyEditor',
                             -override => 1);
    push @lines, CGI::hidden(-name => 'task', -value => 'SHOW',
                             -override => 1);
    push @lines, CGI::start_table();
    push @lines, CGI::Tr(CGI::th({ class => 'aname' }, 'Create a Key'),
                         CGI::td({ class => 'amenu' },
                                 CGI::textfield(-name => 'key', -size => 40,
                                                -value => '', -override => 1)),
                         CGI::td({ class => 'abutton' }, CGI::submit(-class => 'button', -value => 'CREATE')));
    push @lines, CGI::end_table();
    push @lines, CGI::end_form();
    push @lines, CGI::start_form(-action => $application->url);
    push @lines, CGI::hidden(-name => 'page', -value => 'AttributeGroupEditor',
                             -override => 1);
    push @lines, CGI::hidden(-name => 'task', -value => 'SHOW',
                             -override => 1);
    push @lines, CGI::start_table();
    push @lines, CGI::Tr(CGI::th({ class => 'aname' }, 'Select a Group'),
                         CGI::td({ class => 'amenu' },
                                 CGI::popup_menu(-name => 'group', -values => \@groups)),
                         CGI::td({ class => 'abutton' }, CGI::submit(-class => 'button', -value => 'SHOW')));
    push @lines, CGI::end_table();
    push @lines, CGI::end_form();
    push @lines, CGI::start_form(-action => $application->url);
    push @lines, CGI::hidden(-name => 'page', -value => 'AttributeGroupEditor',
                             -override => 1);
    push @lines, CGI::hidden(-name => 'task', -value => 'CREATE',
                             -override => 1);
    push @lines, CGI::start_table();
    push @lines, CGI::Tr(CGI::th({ class => 'aname' }, 'Create a Group'),
                         CGI::td({ class => 'amenu' },
                                 CGI::textfield(-name => 'group', -size => 40,
                                                -value => '', -override => 1)),
                         CGI::td({ class => 'abutton' }, CGI::submit(-class => 'button', -value => 'CREATE')));
    push @lines, CGI::end_table();
    push @lines, CGI::end_form();
    # Return the result.
    return join("\n", @lines);
}


1;
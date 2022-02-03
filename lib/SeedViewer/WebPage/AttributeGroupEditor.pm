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

package SeedViewer::WebPage::AttributeGroupEditor;

    use strict;
    use Tracer;
    use CustomAttributes;
    use SeedViewer::WebPage::AttributeKeyEditor;

use base qw(WebPage);

=head1 AttributeGroupEditor Page

=head2 Introduction

This page allows an authorized user to create, delete, and edit attribute key
groups.

=cut

=head3 init

    $page->init();

Initialize the page. This method sets the display title and must register any
necessary components.

=cut

sub init {
    my ($self) = @_;
    $self->title('Attribute Group Editor');
    return 1;
}

=head3 output

    $page->output();

Return the html output of this page. The page uses the following CGI parameters.

=over 4

=item group

Name of the group to edit or create.

=item keys

List of keys that belong to the group.

=item task

Action to take. C<STORE> creates or updates the group; C<DELETE> removes it from
the database. C<SHOW> displays the group without modifying it.

=back

=cut

sub output {
    my ($self) = @_;
    # Get the application object.
    my $application = $self->application();
    # Get access to the data store.
    my $fig = $application->data_handle('FIG');
    # Get access to the form fields.
    my $cgi = $application->cgi();
    my $group = $cgi->param('group');
    # Compute the user name.
    my $user = $application->session->user->login();
    # Get access to the attributes.
    my $ca = CustomAttributes->new(user => $user);
    # Compute the action.
    my $action = $cgi->param('task') || 'SHOW';
    # The HTML lines will go in here.
    my @lines = ();
    # This variable will hold the group record if it exists.
    my $groupRecord;
    # The group's keys will be stored in here.
    my @keys;
    # This next section is only useful if a group has been specified.
    if ($group) {
        # Check to see if the group ezists.
        $groupRecord = $ca->GetEntity(AttributeGroup => $group);
        # The key list we use is determined by the action.
        if ($action ne 'STORE') {
            # Here we're displaying the group. What we do here depends on
            # whether or not the group already exists. If the group
            # doesn't exist, we're already initialized to an empty list
            # of keys.
            if (defined $groupRecord) {
                # It does exist, so get its list of keys.
                @keys = $ca->GetFlat(['IsInGroup'], "IsInGroup(to-link) = ?",
                                     [$group], 'IsInGroup(from-link)');
            }
        } else {
            # Here we're editing, so we use the user's key list.
            @keys = $cgi->param('keys');
        }
        # Now we create the form for editing the group.
        push @lines, $cgi->start_form(-action => $application->url);
        push @lines, $cgi->hidden(-name => 'page', -value => 'AttributeGroupEditor');
        push @lines, $cgi->hidden(-name => 'group', -value => $group);
        push @lines, $cgi->start_table();
        push @lines, $cgi->Tr($cgi->th({ class => 'aname' }, 'Attribute Group'),
                              $cgi->td($group));
        # Now comes the key checkboxes. We have a checkbox for every possible
        # key, and pre-select the ones currently connected to the group.
        my @allKeys = $ca->GetFlat(['AttributeKey'], "ORDER BY AttributeKey(id)", [],
                                                     'AttributeKey(id)');
        push @lines, $cgi->Tr($cgi->th({ class => 'aname' }, 'Keys'),
                              $cgi->td($cgi->checkbox_group(-name => 'keys',
                                                            -values => \@allKeys,
                                                            -default => \@keys,
                                                            -columns => 3)));
        # At the bottom we have a row of action buttons. The buttons shown depend
        # on whether or not we have a new group or an old one and what we're
        # doing with it.
        my @buttons = 'STORE';
        if (defined $groupRecord && $action ne 'DELETE' || $action eq 'STORE') {
            push @buttons, 'DELETE';
        }
        my @buttonHTMLs = map { $self->button($_, name => 'task') } @buttons;
        push @lines, $cgi->Tr($cgi->th({ class => 'aname' }, '&nbsp;'),
                              $cgi->td({ align => 'center'}, join(' ', @buttonHTMLs)));
        push @lines, $cgi->end_table();
        push @lines, $cgi->end_form();
    }
    # Now we've displayed all our stuff. Perform the action.
    if ($action eq 'STORE') {
        # The group has no attributes, so we don't need to update, only insert,
        # and the main task revolves around setting the keys in the group. So that
        # the user knows what happened, we put a verb in the following variable.
        my $thingDone;
        # Check to see if we need to create this group.
        if (! defined $groupRecord) {
            # Here we need to create the group.
            $ca->InsertObject(AttributeGroup => { id => $group });
            $thingDone = "created";
        } else {
            # The group exists, so we must disconnect it before proceeding.
            $ca->Disconnect('IsInGroup', AttributeGroup => $group);
            $thingDone = "stored";
        }
        # Now we reconnect to the list of member keys.
        for my $key (@keys) {
            $ca->InsertObject(IsInGroup => { 'from-link' => $key, 'to-link' => $group });
        }
        my $nKeys = scalar(@keys);
        push @lines, $cgi->p("Group $group $thingDone with $nKeys keys.");
    } elsif ($action eq 'DELETE') {
        # Deletion is fairly simple. ERDB automatically cleans up the key/group
        # relationship records.
        my $stats = $ca->Delete(AttributeGroup => $group);
        push @lines, $cgi->p("Group $group deleted: " . $stats->Display());
    }
    # This next form allows the user to select a different group to display or
    # possibly an attribute key.
    push @lines, SeedViewer::WebPage::AttributeKeyEditor::attribute_navigator($ca, $application);
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

1;

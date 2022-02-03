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

package SeedViewer::WebPage::NmpdrGeneTable;

    use strict;
    use Tracer;
    use Sprout;
    use WebComponent::Table;
    use WebComponent::ColumnDisplayList;
    use SearchHelper;
    use base qw(WebPage);

=head1 NmpdrGeneTable Package

=head2 Introduction

This page displays the results of an NMPDR search in a WebComponent
[[TablePm]] display.

Normally, search results are displayed on a dynamically-produced web page a
chunk at a time. The results themselves are stored in a temporary location on
disk called the I<session file>. When there are hundreds of thousands of results,
this enables us to present them to the user fairly quickly, because the
expensive computations are deferred until they are needed; however, the results
cannot be manipulated to any great extent.

The web component table stores its contents in JavaScript data structures, which
allows the user to perform complex filtering and formatting tasks in real-time,
but it is impractical to use it for large result sets. This page allows a user
to bridge the gap between the two formats. If the result set is under roughly
10,000 features, the user will be given the option to go to this page, which
loads the results into a WebComponent table.

=head2 Column Processing

A key feature of this page is the ability to customize the columns shown. The
[[ColumnDisplayListPm]] web component is used to make this happen. In order to
create this component, we need to have a complete list of the available columns.
This page recognizes three types of columns:

=over 4

=item 1. I<Built-in columns> that are defined by the [[ResultHelperPm]] subclass.

=item 2. I<Extra columns> that are defined by the [[SearchHelperPm]] subclass.

=item 3. I<Criterion columns> that are defined by [[TargetCriterionPm]] objects.

=back

When this page is initially invoked, there will be a known list of columns stored
in the session file. We will then ask the result helper for any other columns that
might be available. Some of those will be built-in columns and some will be
criterion columns. Any columns already in the session file will be pruned from
this list. The columns in the session file will be shown, and the other columns will
comprise the set that can be added to the display.

=head2 Virtual Methods

=head3 init

    $page->init();

Initialize the page. This method sets the display title and must register any
necessary components.

=cut

sub init {
    my ($self) = @_;
    $self->title('Advanced Search Result Table');
    $self->application->register_component('Table', 'Table');
    $self->application->register_component('ColumnDisplayList', 'ColumnDisplayList');
    return 1;
}

=head3 output

    $page->output();

Produce the html output of this page. The page uses the following CGI parameters.

=over 4

=item SessionID

ID of the session file containing the user's search results.

=item PageSize

Number of rows of data to display initially in the table.

=item ResultType

Result helper class for the search.

=item Class

The search class used to build the results.

=back

=cut

sub output {
    my ($self) = @_;
    # Get the application object.
    my $application = $self->application();
    # Declare the return variable.
    my $retVal = "";
    # Get access to the data store.
    my $fig = $application->data_handle('FIG');
    # Get access to the form fields.
    my $cgi = $application->cgi();
    my $sessionID = $cgi->param('SessionID') || undef;
    my $pageSize = $cgi->param('PageSize') || 50;
    my $class = $cgi->param('Class');
    my $resultType = $cgi->param('ResultType');
    # Get the table component.
    my $mainTable = $application->component('Table');
    # Get a search helper. This gives us access to the session file.
    my $shelp = SearchHelper::GetHelper($cgi, SH => $class);
    # Get the result helper.
    my $rhelp = SearchHelper::GetHelper($shelp, RH => $resultType);
    # Get access to the session file.
    my $fileName = $shelp->GetCacheFileName();
    my $ih = Open(undef, "<$fileName");
    # This flag will be set to TRUE if we need the display list select control.
    my $complexColumns = 0;
    # Read the column headers. We use these to define the columns to the
    # table component.
    my @colHdrs = $shelp->ReadColumnHeaders($ih);
    # We'll build a list of the columns currently in the table, and a hash of all
    # the available columns.
    my @tableColumnNames;
    my %columnHash;
    for my $colHdr (@colHdrs) {
        # Get this column's true name.
        my $name = $rhelp->ColumnName($colHdr);
        # Get its ordinal index.
        my $idx = scalar(@tableColumnNames) + 1;
        # Compute its metadata.
        my $columnThing = $rhelp->ColumnMetaData($colHdr, $idx, 1);
        # Store it in the hash.
        $columnHash{$name} = $columnThing;
        # Remember the name.
        push @tableColumnNames, $name;
        # If this column is not permanent, we will need a display list.
        $complexColumns ||= ! $columnThing->{permanent};
    }
    Trace(scalar(@tableColumnNames) . " columns defined.") if T(3);
    # Now check for any columns we've missed.
    my @otherColumns = grep { ! exists $columnHash{$_} } $rhelp->GetColumnNameList();
    # Are there any of these missed columns?
    if (scalar @otherColumns) {
        # Yes. We'll need a display list selector in that case.
        $complexColumns = 1;
        # Add the columns to the hash.
        for my $colName (@otherColumns) {
            $columnHash{$colName} = $rhelp->ColumnMetaData($colName);
        }
    }
    # Now loop through the session file, extracting column values. We'll want to accumulate a
    # list of rows, and a list of row identifiers.
    my (@rows, @ids);
    while (! eof $ih) {
        # Get the current line of columns.
        my @cols = Tracer::GetLine($ih);
        # Extract the object ID, which is the first column of the results.
        my $id = shift @cols;
        push @ids, $id;
        # Get the run-time column values.
        my @row = $rhelp->GetRunTimeValues(@cols);
        # Put the row in the table.
        push @rows, \@row;
    }
    # Create the column list for the table.
    my @columnThings = map { $columnHash{$_}->{header} } @tableColumnNames;
    # Define and fill the table component.
    $mainTable->data(\@rows);
    $mainTable->columns(\@columnThings);
    $mainTable->show_top_browse(1);
    $mainTable->show_bottom_browse(1);
    $mainTable->items_per_page($pageSize);
    $mainTable->show_select_items_per_page(1);
    # Do we need a display list?
    if ($complexColumns) {
        Trace("Enabling display list.") if T(3);
        # Yes. Mark the table as uploadable.
        $mainTable->enable_upload(1);
        # Get the display list component.
        my $mainColumnDisplayList = $application->component('ColumnDisplayList');
        # Give the full column hash to the display list selector.
        $mainColumnDisplayList->metadata(\%columnHash);
        # Connect it to the table.
        $mainColumnDisplayList->linkedComponent($mainTable);
        # Give it a list of the row IDs.
        $mainColumnDisplayList->rowKeyList(\@ids);
        # Tell it that when the user wants to add a column, we call LoadColumn.
        $mainColumnDisplayList->ajaxFunction('LoadColumn');
        # Store the helper classes.
        $mainColumnDisplayList->parmCache("$class $resultType");
        # Output the display list.
        $retVal .= $mainColumnDisplayList->output();
    }
    # Output the table.
    $retVal .= $mainTable->output();
    return $retVal;
}

=head2 Internal Methods

=head3 LoadColumn

    my $newTableHtml = $page->LoadColumn();

Process a request to add a new column to the display table. This method
is called by the ajax framework that connects the [[ColumnDisplayListPm]]
component to the [[TablePm]] component. We will interrogate the
C<colName> parameter of the CGI query object to determine the column
name, and the C<primary_ids> method will return a tilde-delimited string
of row IDs. Finally, the C<parmCache> parameter will contain the search
helper class name followed by a space and the result helper class name. All this
information will be put together to reconstruct the table and compute the
values that should go in the specified column.

=cut

sub LoadColumn {
    # Get the parameters.
    my ($self) = @_;
    # Declare the return variable.
    my $retVal = "";
    # Get the application object.
    my $application = $self->application();
    # Get the linked table.
    my $mainTable = $application->component('Table');
    # Extract its ID.
    my $tableID = $mainTable->id();
    # Get the CGI query object.
    my $cgi = $application->cgi();
    # Extract our parameters.
    my $parmCache = $cgi->param('parmCache');
    my $colName = $cgi->param('colName');
    my @rowIDs = split /~/, $cgi->param('rowKeyList');
    # Get the helpers.
    my ($class, $resultType) = split / /, $parmCache;
    my $shelp = SearchHelper::GetHelper($cgi, SH => $class);
    my $rhelp = $shelp->GetResultHelper($resultType);
    Trace("Loading column $colName using $resultType helper for $class search.") if T(3);
    # Get the metadata for the selected column.
    my $metadata = $rhelp->ColumnMetaData($colName);
    # Get a list of the column values.
    my @values;
    for my $id (@rowIDs) {
        my $value = $rhelp->Compute(valueFromKey => $colName, $id);
        push @values, $value;
    }
    # Set up a clear image to trigger the table change when the load completes.
    $retVal .= CGI::img({ src => "$FIG_Config::cgi_url/Html/clear.gif",
                        onload => "changeHiddenField('$tableID', '$colName')" });
    # Add the table content.
    $retVal .= $mainTable->format_new_column_data($metadata->{header}, \@values);
    # Return the result.
    return $retVal;
}

1;

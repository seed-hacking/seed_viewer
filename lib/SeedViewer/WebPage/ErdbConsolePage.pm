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

package SeedViewer::WebPage::ErdbConsolePage;

    use strict;
    use Tracer;
    use WebComponent::Ajax;
    use WebComponent::TabView;
    use WebComponent::Table;
    use ERDB;
    use ERDBQueryConsole;
    use ERDBExtras;
    use Time::HiRes;
    use TestUtils;
    use CGI::Cookie;
    use LogReader;
    use FIG_Config;
    use YAML;
    use SeedUtils;
    use BasicLocation;

use base qw(WebPage);


=head1 ErdbConsolePage Package

=head2 Introduction

This page allows the user to perform functions useful for developing against
the Sapling database.RDB Query Console found in several places on the %FIG{NMPDR
Website}%.

The top of this page is a family of forms that can be used to query the Sapling
database, generate method code, test a PERL script, configure tracing, test a
server, or generate documentation. Below the form is a tab view component with two
tabs-- B<Documentation>, which contains documentation, B<Tracing>, which contains
trace output, and B<Results>, which contains results from the forms. The tabs
start out empty, but can be filled using Ajax events.

This page is accessible to any user; however, most of its functions are limited or
disabled. To perform an unlimited query, the user must have the C<query,database>
privilege. To use any of the coding tools, the user must have the C<develop,database>
privilege.

The following special constants are stored in the page object.

=over 4

=item formID

DIV ID and name of the main form.

=item resultID

DIV ID for the data portion of the result tab.

=item tracingID

DIV ID for the data portion of the tracing tab.

=item docID

ID and name of the documentation frame.

=item miniID

ID and name of the mini-form used to fill the documentation frame.

=item tabViewID

ID number of the main tab control.

=back

=head2 Global Constants

These constants are used by more than one form. Other constants are
declared in the sections for the individual forms.

=head3 BUTTON_WIDTH

This is the pixel width for the buttons.

=cut

use constant BUTTON_WIDTH => 120;

=head3 DOC_HEIGHT

This is the pixel height for the iframe in the documentation tab.

=cut

use constant DOC_HEIGHT => 900;

=head3 FIELD_WIDTH

This indicates the pixel width of the main form fields.

=cut

use constant FIELD_WIDTH => 600;

=head3 TAB_WIDTH

Number of pixels to use for the width of the main tab.

=cut

use constant TAB_WIDTH => 940;

=head3 TABLE_ROWS

This is the initial number of rows to show in a result table.

=cut

use constant TABLE_ROWS => 50;

=head3 TRACE_LEVELS

This maps trace levels to their descriptive labels for the dropdown
menu.

=cut

use constant TRACE_LEVELS => { 0 => '0 - Errors',  1 => '1 - Warnings',
                               2 => '2 - Notices', 3 => '3 - Information',
                               4 => '4 - Details' };

=head3 DOC_PAGEURL

This is the URL to use for generating documentation pages.

=cut

use constant DOC_PAGEURL => "$FIG_Config::cgi_url/ShowPod.cgi";

=head3 DOC_WIDGET_NAME

This is the title given to the documentation widget when it appears in a form.

=cut

use constant DOC_WIDGET_NAME => 'PERL Package';

=head FIND_WIDGET_NAME

This is the title given to the SEED find widget when it appears in a form.

=cut

use constant FIND_WIDGET_NAME => 'SEED Search';

=head2 Virtual Methods

=head3 init

    $page->init();

Initialize the page. This method sets the display title and must register any
necessary components.

=cut

sub init {
    my ($self) = @_;
    $self->title('Programming Console');
    $self->application->register_component('Ajax', 'Ajax');
    $self->application->register_component('TabView', 'TabView');
    $self->application->register_component('TabView', 'FormTabs');
    $self->application->register_component('Table', 'Table');
    # Compute the segment IDs and stash them in this object. First, we have
    # the main form.
    $self->{formID} = 'sv_ERDB_form';
    # This is the result tab.
    $self->{resultID} = 'sv_ERDB_result';
    # This is the iframe in the documentation tab.
    $self->{docID} = 'sv_ERDB_document';
    # This is the tracing tab.
    $self->{tracingID} = 'sv_ERDB_tracing';
    # This is the special miniform for filling the documentation tab.
    $self->{miniID} = 'sv_ERDB_miniform';
    return 1;
}

=head3 output

    $page->output();

Return the html output of this page. The page performs the action indicated by the
C<actionButton> parameter.

=cut

sub output {
    my ($self) = @_;
    # Get the application object.
    my $application = $self->application();
    Trace("ERDB Console Page entered.") if T(3);
    # Get access to the form fields.
    my $cgi = $application->cgi();
    # Obtain the components.
    my $mainAjax = $application->component('Ajax');
    my $mainTabView = $application->component('TabView');
    my $formTabView = $application->component('FormTabs');
    # Set up the ajax cookies.
    $mainAjax->cookie_call('SetCookies');
    # Set the default tab width.
    my $tabWidth = TAB_WIDTH;
    $mainTabView->width($tabWidth);
    $formTabView->width(725);
    $formTabView->height(340);
    # Get the main tab control's ID number.
    $self->{tabViewID} = $mainTabView->id();
    # Compute the metrics for the documentation tab.
    my $docHeight = DOC_HEIGHT;
    my $docBoxHeight = $docHeight - 40;
    my $docWidth = $tabWidth - 10;
    # Determine the action being taken.
    my $lastAction = $cgi->param('actionButton');
    # Generate the forms.
    my $formHtml = $self->BuildForms($formTabView);
    # Create the secret hidden miniform.
    my $miniForm = join("",
                      CGI::start_form(-id => $self->{miniID}, -name => $self->{miniID},
                                      -target => $self->{docID}, -action => ''),
                      CGI::hidden(-name => 'cover', -value => 'reduced'),
                      CGI::hidden(-name => 'height', -value => $docBoxHeight),
                      CGI::hidden(-name => 'none', -id => "$self->{miniID}_hidden"),
                      CGI::end_form(), "\n");
    # Add the style for the documentation iframe.
    $miniForm .= CGI::style({ type => "text/css"}, join("\n",
                            "iframe#$self->{docID} {",
                            "  height: ${docHeight}px;",
                            "  width:  ${docWidth}px;",
                            "  margin: 0 5px;",
                            "}"));
    # Now we must build the tab control. The results tab contains a DIV that is
    # the target of the ajax functions.
    $mainTabView->add_tab(Results => CGI::div({ id => $self->{resultID} }, "&nbsp;"));
    # The tracing tab contains a DIV that is the target of the ajax function for
    # the tracing form.
    $mainTabView->add_tab(Tracing => CGI::div({ id => $self->{tracingID},
                                                class => 'doc' }, "&nbsp;"));
    # The documentation tab contains an iframe that is used as the target of the
    # minijump form.
    $mainTabView->add_tab(Documentation => CGI::iframe({ id => $self->{docID},
                                           name => $self->{docID}}, "&nbsp;"));
    # Select the documentation tab.
    $mainTabView->default(1);
    # We'll build our HTML in here.
    my @retVal;
    # First comes the form.
    push @retVal, $formHtml;
    # Next a spacer.
    push @retVal, CGI::p('&nbsp;');
    # Here we do the ajax control and the mini-form.
    push @retVal, $mainAjax->output();
    push @retVal, $miniForm;
    # Finally, the main tab control.
    push @retVal, $mainTabView->output();
    # Return the HTML for the entire page.
    return join("\n", @retVal);
}

=head3 require_javascript

    my $files = $page->require_javascript();

Return the URL of the special javascript file required by the
documentation widget.

=cut

sub require_javascript {
    return ["$FIG_Config::cgi_url/Html/ERDB.js"];
}

=head3 require_css

    my $files = $page->require_css();

Return the URL of the special javascript file required by the
documentation widget.

=cut

sub require_css {
    return ["$FIG_Config::cgi_url/Html/css/ERDB.css"];
}

=head2 Utility Methods

=head3 TitleGroup

    my $html = SeedViewer::WebPage::TitleGroup($header, $data);

Create a level 3 header containing the specified text, followed by the
specified HTML.

=over 4

=item header

Text for the header.

=item data

HTML to be displayed under the header.

=item RETURN

Returns the HTML for a level 3 header followed by the specified text.

=back

=cut

sub TitleGroup {
    # Get the parameters.
    my ($header, $data) = @_;
    # Format the header.
    my $headHtml = CGI::h3(CGI::escapeHTML($header));
    # Format it with the data.
    my $retVal = "$headHtml\n$data\n";
    # Return the result.
    return $retVal;
}

=head3 JavaButton

    my $buttonHtml = SeedViewer::WebPage::ErdbConsolePage::JavaButton($buttonName, $clickEvent);

Generate the HTML for a javascript button.

=over 4

=item buttonName

Name to give to the button.

=item clickEvent

OnClick expression to assign to the button. This is usually in the form of a
javascript method invocation.

=item RETURN

Returns the HTML for a javascript button with the specified caption and click event.

=back

=cut

sub JavaButton {
    # Get the parameters.
    my ($buttonName, $clickEvent) = @_;
    # Declare the return variable.
    my $style = "width: " . BUTTON_WIDTH . "px";
    my $retVal = CGI::button(-class => 'button', -style => $style,
                             -value => $buttonName, -onClick => $clickEvent);
    # Return the result.
    return $retVal;
}

=head3 MyRow

    my $tableRow = SeedViewer::WebPage::ErdbConsolePage::MyRow($caption, $name => $rows);

Generate a standard one-field text field table row for the ERDB Console input form.
Each table row contains a caption formatted as a row header cell followed by a data
cell with a giant text box in it. The text box can be a single-row text field or a
multi-row text area.

=over 4

=item caption

Caption to put in the first cell of the row.

=item name

Name to give to the text field.

=item rows

C<1> for a single-line text field; otherwise the number of rows for a multi-line
text area.

=item RETURN

Returns the HTML for the specified row of the input form table.

=back

=cut

sub MyRow {
    # Get the parameters.
    my ($caption, $name, $rows) = @_;
    # Compute the style.
    my $style = "width: " . FIELD_WIDTH . "px";
    # Create the header cell.
    my $header = CGI::th($caption);
    # We'll put the input field in here.
    my $inputField;
    # Process according to the field type.
    if ($rows != 1) {
        $inputField = CGI::textarea(-name => $name, -style => $style, -rows => $rows);
    } else {
        $inputField = CGI::textfield(-name => $name, -style => $style);
    }
    # Format the table row.
    my $retVal = CGI::Tr($header, CGI::td($inputField));
    # Return the result.
    return $retVal;
}

=head3 ParseCGI

    my ($database, $objects, $filterString, $parms, $limit, $fields, $varNames) = SeedViewer::WebPage::ErdbConsolePage::ParseCGI($cgi);

Extract the query parameters from the CGI query object. This method is
used by both the Ajax post-processor (L</RunQuery>), and the main method
(L</output>).

=over 4

=item cgi

CGI query object containing the data from the query form.

=item RETURN

Returns the database name, the object name list, the filter string, a reference
to the list of parameters, the query limit, a reference to the list of
field names, and a reference to a list of parameter variable names.

=back

=cut

sub ParseCGI {
    # Get the parameters.
    my ($cgi) = @_;
    # Extract the parameters.
    my $database = $cgi->param('database');
    my $objects = $cgi->param('objects');
    my $filterString = $cgi->param('filterString') || '';
    my $parmsString = $cgi->param('parms');
    my $limit = $cgi->param('limit');
    my $fieldString = $cgi->param('fields') || '';
    # Insure the parameter string is defined.
    $parmsString = '' if ! defined $parmsString;
    # Insure the limit is defined.
    $limit = ($FIG_Config::query_limit || 1000) if ! defined $limit;
    # Split out the parameters if any were specified.
    my @rawParms = split /\r\n|\r|\n/, $parmsString;
    # Split the raw parameters into real parameters and variable names.
    my (@parms, @varNames);
    for my $rawParm (@rawParms) {
        if ($rawParm =~ /^(\$\w+)\s*=\s(.+)/) {
            # Here the user specified a variable name.
            push @varNames, $1;
            push @parms, $2;
        } else {
            push @varNames, undef;
            push @parms, $rawParm;
        }
    }
    # Split out the field names.
    my $fields = [ ERDBQueryConsole::SplitFields($fieldString) ];
    Trace("CGI Parse complete: database = " . ($database || "(none)") .
          ". objects = " . (defined $objects ? $objects : "<empty>") .
          ".") if T(3);
    # Return the results.
    return ($database, $objects, $filterString, \@parms,
            $limit, $fields, \@varNames);
}

=head3 CheckUser

    my $privileged = SeedViewer::WebPage::ErdbConsolePage::CheckUser($application);

Return TRUE if the current user has the query database privilege, else FALSE.

=over 4

=item application

Application object for this session.

=item RETURN

Returns TRUE if the user has the query privilege for databases,
else FALSE.

=back

=cut

sub CheckUser {
    # Get the parameters.
    my ($application) = @_;
    # Declare the return variable.
    my $retVal;
    # Get the user object.
    my $user = $application->session->user();
    # Is the user logged in?
    if (! defined $user) {
        # No, he's automatically insecure.
        $retVal = 0;
    } else {
        # Yes, check his rights.
        $retVal = $user->has_right($application, 'query', 'database', '*');
    }
    # Return the result.
    return $retVal;
}

=head3 CheckDeveloper

    my $privileged = SeedViewer::WebPage::ErdbConsolePage::CheckDeveloper($application, $user);

Return TRUE if the current user has the developer privilege, else FALSE.

=over 4

=item application

Application object for this session.

=item user (optional)

User object to check. If this parameter is omitted, the current session user
will be checked.

=item RETURN

Returns TRUE if the user has the developer privilege, else FALSE.

=back

=cut

sub CheckDeveloper {
    # Get the parameters.
    my ($application, $user) = @_;
    # Declare the return variable.
    my $retVal;
    # Get the user object if none was passed in.
    if (! defined $user) {
        $user = $application->session->user();
    }
    # Is the user logged in?
    if (! defined $user) {
        # No, he's automatically insecure.
        $retVal = 0;
    } else {
        # Yes, check his rights.
        $retVal = $user->has_right($application, 'develop', 'database', '*');
    }
    # Return the result.
    return $retVal;
}

=head3 BuildForms

    my $formHtml = $page->BuildForms($formTabView);

This method creates all the forms for the query console. Each form is in
its own tab, and all the tabs occupy the specified tab-view control. The
forms do not perform real actions. Instead, they use javascript buttons
to execute an ajax function.

=over 4

=item formTabView

Tab control object for generated the bodies of the forms.

=item action

Action taken by the previous command.

=item RETURN

Returns the HTML for the forms, including the generated tabview control HTML.

=back

=cut

sub BuildForms {
    # Get the parameters.
    my ($self, $formTabView, $action) = @_;
    # Get the application object.
    my $application = $self->application();
    # Declare the return variable.
    my @retVal;
    # Get the user's privilege level.
    my $developer = CheckDeveloper($application);
    # Start the form.
    Trace("Building forms.") if T(3);
    # Create the general-use forms.
    my %formHash = (Query => $self->QueryForm(),
                    Method => $self->MethodForm(),
                    Server => $self->ServerForm());
    # Add the privileged-use forms.
    if ($developer) {
        $formHash{Script} = $self->ScriptForm();
        $formHash{Tracing} = $self->TracingForm();
    }
    for my $tabName (sort keys %formHash) {
        $formTabView->add_tab($tabName => $formHash{$tabName});
    }
    Trace("Selecting default form tab.") if T(3);
    # Select the first tab.
    $formTabView->default(0);
    # Output the form tab control.
    push @retVal, $formTabView->output();
    # Return the result.
    return join("\n", @retVal, "");
}

=head3 StartForm

    my @lines = $page->StartForm($formID);

Return the HTML lines for starting a form. This method creates the start
tags for the form and a table to contain the form controls.

=over 4

=item formID

ID to give to the form.

=item RETURN

Returns a list of HTML lines for starting the form.

=back

=cut

sub StartForm {
    # Get the parameters.
    my ($self, $formID) = @_;
    # Create the start tags.
    my @retVal = (CGI::start_form(-id => $formID), CGI::start_table());
    # Add a hidden field to suppress tracing in the ajax script.
    push @retVal, CGI::hidden(-name => 'ajaxQuiet', -value => 1);
    # Return the result.
    Trace("Form $formID started.") if T(3);
    return @retVal;
}

=head3 EndForm

    my @lines = $page->EndForm();

Return the HTML lines for completing a form. This method creates the end
tags for the form and the table that contains its controls.

=cut

sub EndForm {
    # Get the parameters.
    my ($self) = @_;
    # Create the end tags.
    my @retVal = (CGI::end_table(), CGI::end_form());
    Trace("Form closed.") if T(3);
    # Return the result.
    return @retVal;
};


=head3 ResultButton

    my $html = $page->ResultButton($tabID => $formID, $function => $caption);

Create a result button. The result button is a Javascript button with the
specified caption that uses data from the specified form to call the
named ajax function. The results will be put in the named tab.

=over 4

=item formID

ID of the form containing the data to be used as CGI parameters by the
ajax function called.

=item tabID

C<tracingID> if the output is to be to the tracing tab, and C<resultID> if
the output is to be to the result tab.

=item function

The name of the function in this module to be called when the button is
clicked.

=item caption

The caption to put on the button.

=item setup (optional)

An optional Javascript statement to be executed before the main action.

=item RETURN

Returns the HTML for a button that calls the specified Ajax function with
the specified form.

=back

=cut

sub ResultButton {
    # Get the parameters.
    my ($self, $tabID, $formID, $function, $caption, $setup) = @_;
    # Format the setup string.
    my $setupString = (defined $setup ? "$setup; " : "");
    # Format the ajax call.
    my $call1 = "execute_ajax('$function', '$self->{$tabID}', '$formID')";
    # Format the tab switcher.
    my $tabNum = ($tabID eq 'resultID' ? 0 : 1);
    my $call2 = "tab_view_select('$self->{tabViewID}', '$tabNum')";
    # Form them into a javascript event.
    my $call = "javascript: $setupString$call1; $call2;";
    # Format the button.
    my $retVal = JavaButton($caption, $call);
    # Return the result.
    return $retVal;
}

=head3 MiniJump

    my $javaCall = $page->MiniJump($url, $parm => $expression);

Create a Javascript call to display the specified data in the
documentation tab. The call will be to the C<ErdbMiniFormJump> javascript
method, which will set the mini-form's action to the specified URL,
rename the hidden input field to the specified parameter name, store the
value of the specified expression in it, and then submit the form.

=over 4

=item url

Full URL of the target page to display.

=item parm

Name to give to the primary parameter.

=item expression

Javascript expression for the value to put in. If the value is a string,
it must be quoted. (Thus, C<'Sapling'> would store the string C<Sapling>
in the parameter field, but C<Sapling> would store the value of a Javascript
variable named I<Sapling>.)

=item RETURN

Returns a Javascript expression that will perform the desired action.

=back

=cut

sub MiniJump {
    # Get the parameters.
    my ($self, $url, $parm, $expression) = @_;
    # Format the call.
    my $retVal = "ErdbMiniFormJump('$self->{miniID}', '$url', '$parm', $expression, '$self->{tabViewID}', '2')";
    # Return the result.
    return $retVal;
}

=head3 TraceMenu

    my $htmlMenu = SeedViewer::WebPage::ErdbConsolePage::TraceMenu($name, $default);

Return a popup menu for selecting the trace level.

=over 4

=item name

Name to give to the menu field.

=item default (optional)

The default trace level to use. If this value is undefined, the default is 3.

=item RETURN

Returns a popup menu with the given field name that allows the user to
select a trace level.

=back

=cut

sub TraceMenu {
    # Get the parameters.
    my ($name, $default) = @_;
    # Compute the menu keys.
    my @keys = sort { $a <=> $b } keys %{TRACE_LEVELS()};
    # Handle the default trace level.
    $default = 3 if ! defined $default;
    # Build the popup menu.
    my $retVal = CGI::popup_menu( -name => $name, -default => $default,
                                  -values => \@keys,
                                  -labels => TRACE_LEVELS );
    # Return the result.
    return $retVal;
}

=head3 TracerButton

    my $html = $page->TracerButton($action, $formID);

Create a button that will execute the specified tracing action.

=over 4

=item action

Action to be placed in the I<actionType> field of the form.

=item formID

ID of the form containing the tracing parameters.

=item RETURN

Returns the HTML for a javascript button that will invoke the
specified tracing action using the specified form.

=back

=cut

sub TracerButton {
    # Get the parameters.
    my ($self, $action, $formID) = @_;
    # Format the action update.
    my $setup = "StoreParm('actionType', '$action', '$formID')";
    # Assemble a result button.
    my $retVal = $self->ResultButton(tracingID => $formID,
                                     RunTracing => $action, $setup);
    # Return the result.
    return $retVal;
}

=head3 SetCookies

    my @cookies = SeedViewer::WebPage::ErdbConsolePage::SetCookies($cgi);

This method sets the cookies for the Ajax response. It looks for a CGI
parameter called C<actionType>. If the C<actionType> parameter is C<Activate>
it will configure the current client's tracing and execution environment. If
it is C<Terminate> it will clear the current client's tracing data.

=over 4

=item cgi

CGI query object that may be used to access the parameters.

=item RETURN

Returns a (possibly empty) list of B<CGI::Cookie> objects that associate the
user's IP address with the specified tracing key.

=back

=cut

sub SetCookies {
    # Get the parameters.
    my ($cgi) = @_;
    # Declare the return variable.
    my @retVal;
    # Get the action type.
    my $actionType = $cgi->param('actionType') || '';
    # Verify that this is tracing activation.
    if ($actionType eq 'Activate') {
        # Set the cookies. First is the tracing key. We only set this if we can find it.
        my $key = $cgi->param('traceKey');
        if ($key) {
            push @retVal, CGI::Cookie->new(-name => 'IP', -value => $key, -path => '/');
        }
        # Next is the run-time environment.
        my $environment = $cgi->param('environment') || 0;
        push @retVal, CGI::Cookie->new(-name => 'SPROUT', -value => $environment, -path => '/');
        # Finally, the robot flag.
        my $robotic = $cgi->param('robotic') || 0;
        push @retVal, CGI::Cookie->new(-name => 'Robot', -value => $robotic, -path => '/');
    } elsif ($actionType eq 'Terminate') {
        # Create commands to clear the environment and robot cookies.
        push @retVal, CGI::Cookie->new(-name => 'SPROUT', -value => '', -path => '/', -expires => '-1M'),
                      CGI::Cookie->new(-name => 'Robot', -value => '', -path => '/', -expires => '-1M');
    }
    # Return the result.
    return @retVal;
}

=head3 FormatError

    my $htmlText = FormatError($message);

Format an output message as an error. Error messages are shown as block
quotes, which makes them stand out very violently.

=over 4

=item message

Error message to output.

=back

=cut

sub FormatError {
    # Get the parameters.
    my ($message) = @_;
    # HTML-escape the error message.
    my $escaped = CGI::escapeHTML($message);
    # Format it.
    my $retVal = CGI::blockquote($escaped);
    # Return the result.
    return $retVal;
}

=head3 FindWidget

    my $htmlText = $page->FindWidget($formID);

Create a SEED Viewer jump widget for the specified form. The jump widget
contains a small input text box and uses a Javascript button to open a
SEED Viewer page in a new window.

=over 4

=item formID

ID of the form on which the widget is being placed.

=item RETURN

Returns the HTML text for the input field and the java button.

=back

=cut

sub FindWidget {
    # Get the parameters.
    my ($self, $formID) = @_;
    # First, we create the widget text control ID.
    my $fieldID = "${formID}_seedjump";
    # Now the text control itself.
    my $jumpField = CGI::textfield(-id => $fieldID, -size => 20);
    # Build the jumper button.
    my $jumpButton = JavaButton('Find', "SeedViewerJump('$fieldID')");
    # Put the pieces together.
    my $retVal = join(" ", $jumpField, $jumpButton);
    # Return the result.
    return $retVal;
}


=head3 DocWidget

    my $htmlText = $page->DocWidget($formID);

Create a documentation widget for the specified form. The documentation
widget consists of a text box and a button that puts documentation
computed from the text box value into the documentation tab.

=over 4

=item formID

ID of the form to contain this widget.

=item RETURN

Returns the HTML for the documentation widget.

=back

=cut

sub DocWidget {
    # Get the parameters.
    my ($self, $formID) = @_;
    # First, we create the documentation page textcontrol ID.
    my $docID = "${formID}_docPage";
    # Now the text control itself.
    my $docField = CGI::textfield(-id => $docID, -size => 20);
    # Build the documentation button.
    my $fieldExpression = "document.getElementById('$docID').value";
    my $docButton = JavaButton('Documentation',
                               $self->MiniJump(DOC_PAGEURL, module => $fieldExpression));
    # Put the documentation widget together.
    my $retVal = join(" ", $docField, $docButton);
    # Return the result.
    return $retVal;
}

=head2 The Script Form

The script form is used to trigger the C<RUN SCRIPT> action, which runs a simple
PERL script and displays the results. The C<Documentation> button can be used
to display PERL documentation. This page is extremely dangerous, so only people
with developer privileges can use it.

=over 4

=item module

B<Module>: Name of a PERL module or NMPDR code page to display in the
Documentation tab when the C<Documentation> button is clicked. Specify
C<SourceProjects> to get the root of the project documentation web. (If you know
a module or script's documentation page name (e.g. C<FigPm>, C<SFXlatePm>,
C<AliasCrunchPl>), you can also specify it directly.) You can also enter the
name of a PERL manpage (e.g. C<perlfunc>, C<perlop>), or any name that is legal
for a B<use> statement (C<CGI>, C<constant>, C<FIG>).

=item trace

B<Trace Level>: Level of tracing desired, from 0 (errors only), to 4 (details).
Trace messages are displayed while the script is running, before the results are
shown.

=item modules

B<Trace Modules>: Space-delimited list of trace modules to activate. For most
trace messages, the module name is the same as the package name. Certain modules
are special (e.g. C<SQL> to see SQL statements, C<File> for file operations from
the [[TracerPm]] package, C<Load> for SQL loading operations).

=item type

B<Output Type>: Results to display. Specify C<Normal> to display C<$retVal> as a data
structure or number, C<Text> to display C<$retVal> as a multiple-line text string,
C<MatHash> to display the hash C<%ret> as a hash of lists, C<MatList> to display
the C<@ret> as a list of lists, C<TabHash> to display C<%ret> as a hash of
uniformly-structured hashes, or C<TabList> to display C<@ret> as a list of
uniformly-structured hashes.

=item unsafe

B<Options> I<Unsafe>: Normally, the script is executed in a B<use strict> environment.
If this option is TRUE, B<no strict> will be used instead.

=item fig

B<Options> I<FIG>: If TRUE, then a [[FigPm]] object will be created and put in the
variable C<$fig>.

=item sprout

B<Options> I<Sprout>: If TRUE, then an [[SFXlatePm]] object will be created and put in
the variable C<$sfx>, and a [[SproutPm]] object will be created and put in the
variable C<$sprout>.

=item sapling

B<Options> I<Sapling>: If TRUE, then a [[SaplingPm]] object will be created and put in
the variable C<$sap>.

=item script

B<Test Script>: The actual PERL script. The script will be executed in a B<use
strict> environment (unless the unsafe option is checked), and there will be a
CGI object in the variable C<$cgi>. Depending on the ouput type specified, the
result should be put in C<%ret>, C<@ret>, or C<$retVal>. All three of these
variables will be pre-declared.

=back

=head3 OUTPUT_TYPE

This constant maps an output type parameter to its actual output type.

=cut

use constant OUTPUT_TYPE => { Normal => 'Normal', Text => 'Text',
                              MatList => 'Matrix', MatHash => 'Matrix',
                              TabList => 'Table', TabHash => 'Table' };

=head3 OUTPUT_LABEL

This constant maps an output type parameter to its label for the dropdown
list.

=cut

use constant OUTPUT_LABEL => { Normal =>  'Normal Value or Object ($retVal)',
                               Text =>    'Text String ($retVal)',
                               MatHash => 'Hash of Lists (%ret)',
                               MatList => 'List of Lists (@ret)',
                               TabHash => 'Hash of Isomorphic Hashes (%ret)',
                               TabList => 'List of Isomorphic Hashes (@ret)' };

=head3 ScriptForm

    my $html = $page->ScriptForm();

Return the HTML for the script testing form.

=over 4

=item tabName

Name of the tab containing this form.

=item RETURN

Returns the HTML for a script testing form that can be put in a form tab.

=back

=cut

sub ScriptForm {
    # Get the parameters.
    my ($self) = @_;
    # Declare the return variable.
    my @retVal;
    # Create the form ID.
    my $formID = "$self->{formID}_Script";
    # Start the form and the table.
    push @retVal, $self->StartForm($formID);
    # The first row is the output type and the SEED jumper.
    my @outputTypes = sort { OUTPUT_LABEL->{$a} cmp OUTPUT_LABEL->{$b} } keys %{OUTPUT_LABEL()};
    my $outputMenu = CGI::popup_menu(-name => "type",
                                     -values => \@outputTypes,
                                     -labels => OUTPUT_LABEL,
                                     -default => 'Normal');
    my $seedJumper = $self->FindWidget($formID);
    push @retVal, CGI::Tr(CGI::th("Output Type"), CGI::td($outputMenu),
                          CGI::th(FIND_WIDGET_NAME), CGI::td($seedJumper));
    # Next comes the tracing specification.
    my $traceMenu = TraceMenu('trace');
    push @retVal, CGI::Tr(CGI::th("Trace Level"), CGI::td($traceMenu),
                          CGI::th("Trace Modules"),
                          CGI::td(CGI::textfield(-name => 'modules', -size => 45)));
    # Now the options. This is a set of independent check boxes.
    push @retVal, CGI::Tr(CGI::th("Options"),
                          CGI::td({ colspan => 3 }, join(" "),
                                  CGI::checkbox(-name => 'unsafe', -label => 'Unsafe'),
                                  CGI::checkbox(-name => 'fig',    -label => 'FIG'),
                                  CGI::checkbox(-name => 'sprout', -label => 'Sprout'),
                                  CGI::checkbox(-name => 'sapling',-label => 'Sapling')));
    # The script itself is most of the form. First, we create its style.
    my $style = "height: 170px; width: " . FIELD_WIDTH . "px;";
    push @retVal, CGI::Tr(CGI::th('Test Script'),
                        CGI::td({ colspan => 3 },
                                CGI::textarea(-name => 'script', -style => $style)));
    # At the bottom we have the submit button and the documentation mini-form.
    my $docWidget = $self->DocWidget($formID);
    # Create the submit button.
    my $submitButton = $self->ResultButton(resultID => $formID, 'RunScript', 'RUN SCRIPT');
    # Now we can create the final row.
    push @retVal, CGI::Tr(CGI::td('&nbsp;'), CGI::td($submitButton),
                          CGI::th(DOC_WIDGET_NAME), CGI::td($docWidget));
    # Finish the form.
    push @retVal, $self->EndForm();
    # Return the result.
    return join("\n", @retVal);
}

=head3 RunScript

    my $htmlText = $page->RunScript();

Run a test script. This method is called asynchronously by the Ajax
facility.

=cut

sub RunScript {
    # Get the parameters.
    my ($self) = @_;
    # Get the parameter query object.
    my $application = $self->application;
    my $cgi = $application->cgi;
    # Validate the user.
    Confess("ERDB Console security failure.") unless CheckDeveloper($application);
    # Get the output type.
    my $type = $cgi->param('type') || 'Normal';
    # Get the tracing parameters.
    my $traceLevel = $cgi->param('trace') || 2;
    my $traceModules = $cgi->param('modules') || '';
    # Initialize tracing. We trace directly to the output.
    TSetup("$traceLevel $traceModules", "HTML");
    # We'll put our output in here.
    my @retVal;
    # Now we need to set up the special variables.
    my ($fig, $sprout, $sfx, $sap);
    # This will be set to FALSE if an error occurs creating special objects.
    my $specials = 1;
    # Create the special objects.
    if ($cgi->param('fig')) {
        eval {
            require FIG;
            $fig = FIG->new();
        }; if ($@) {
            Trace("Error creating FIG object: $@") if T(0);
            $specials = 0;
        } else {
            Trace("FIG object created.") if T(2);
        }
    }
    if ($cgi->param('sprout')) {
        eval {
            require SFXlate;
            $sfx = SFXlate->new();
            $sprout = $sfx->sprout();
        }; if ($@) {
            Trace("Error creating Sprout objects: $@") if T(0);
            $specials = 0;
        } else {
            Trace("Sprout objects created.") if T(2);
        }
    }
    if ($cgi->param('sapling')) {
        eval {
            require Sapling;
            $sap = Sapling->new();
        }; if ($@) {
            Trace("Error creating sapling object: $@") if T(0);
            $specials = 0;
        } else {
            Trace("Sapling object created.") if T(2);
        }
    }
    if (! $specials) {
        Trace("Script aborted: error creating special objects.") if T(0);
    } else {
        # Get the unsafe flag.
        my $unsafe = $cgi->param('unsafe');
        # Get the script itself.
        my $script = $cgi->param('script');
        if (! $script) {
            # If there's no script, we have nothing to do.
            Trace("Script is empty.") if T(2);
        } else {
            # Add the unsafeness to the script, if the user desires it.
            if ($unsafe) {
                $script = "no strict;\n$script";
            }
            # Save the confession count.
            my $confessions = Tracer::Confessions();
            # Declare the script's return variables.
            my ($retVal, @ret, %ret);
            # Evaluate the script.
            eval($script);
            # Compute the number of new confessions.
            $confessions -= Tracer::Confessions();
            # If we had an uncaught exception, we need to make note of it.
            if ($@ && $confessions <= 0) {
                Trace("Script Error: $@") if T(0);
                $confessions++;
            }
            # Determine the output variable.
            if ($type =~ /Hash/) {
                $retVal = \%ret;
            } elsif ($type =~ /List/) {
                $retVal = \@ret;
            }
            # Determine the output type.
            my $realType = OUTPUT_TYPE->{$type};
            # Format the output.
            push @retVal, CGI::div({ id => 'Dump' },
                                   TestUtils::Display($retVal, $realType));
        }
    }
    # Return the result.
    return join("\n", @retVal);
}

=head3 ConfigureTable

    SeedViewer::WebPage::ErdbConsole::ConfigureTable($table);

Set the configuration defaults for the specified table component.

=over 4

=item table

Table component to configure.

=back

=cut

sub ConfigureTable {
    # Get the parameters.
    my ($table) = @_;
    # Set the configuration parameters.
    $table->show_top_browse(1);
    $table->show_bottom_browse(1);
    $table->show_select_items_per_page(1);
    $table->items_per_page(TABLE_ROWS);
}


=head2 The Query Form

The query form can trigger the C<RUN QUERY> action, which performs a query
against one of the ERDB databases. The C<Documentation> button will cause
the selected database's documentation to show up in the Documentation tab.
It has the following parameters.

=over 4

=item database

B<Select a Database>: Name of the database to which the query should be applied.

=item limit

B<Special Options> I<Row Limit>: Maximum number of result rows to display. A value
of C<unlimited> (if present) indicates all rows will be returned. To prevent
denial-of-service attacks, only privileged users can specify C<unlimited>.

=item codeStyle

B<Special Options> I<PERL Code Style>: Style of PERL code to be displayed. If this
is C<None>, then no PERL code is displayed. If C<Get> is specified, then the
code will be a B<Get>-loop. If C<GetAll> is specified, then the code will be a
single B<GetAll> or B<GetFlat> statement.

=item objects

B<Object Names>: Object name list that specifies the entities and relationships
used for the query.

=item filterString

B<Filter String>: Filter string for the query (if any), specifying the WHERE
clause and optionally the result order and the result limit. The word C<WHERE>
should not be present. The result order is specified using an C<ORDER BY> clause,
and the result limit by a C<LIMIT> clause. C<ORDER BY> and C<LIMIT> must be
in upper case. Unlike real SQL, ERDB is case sensitive.

=item parms

B<Parameters (one per line)>: Parameter list for the query, delimited by
new-lines. If a filter string is present, there must be one line in the
parameter list for each parameter mark in the filter.

=back

=head3 CODE_STYLES

This is a list of the styles for the PERL code output.

=cut

use constant CODE_STYLES => ['None', 'Get', 'GetAll'];

=head3 DATABASES

This is a simple list of the database names. If a new database is added, its name
should be put in this list.

=cut

use constant DATABASES => [qw(Sapling CDMI CDMItest CDMIdev CustomAttributes)];

=head3 LIMITS

This contains the allowable row limit sizes. Using a dropdown is simpler
than forcing the user to type stuff. note that C<1> and the default limit
will be added manually.

=cut

use constant LIMITS => [10, 100, 500, 1000, 5000];

=head3 UNLIMITED

This constant is used as the value of the limit parameter for an unlimited
query.

=cut

use constant UNLIMITED => 0;

=head3 QueryForm

    my $html = $page->QueryForm();

Return the HTML for a general database query form.

=over 4

=item tabName

Name of the tab containing this form.

=item RETURN

Returns the HTML for displaying the query form. All the form components are
included, but there are no form tags.

=back

=cut

sub QueryForm {
    # Get the parameters.
    my ($self) = @_;
    # Declare the return variable.
    my @retVal;
    # Create the form ID.
    my $formID = "$self->{formID}_Query";
    # Create the database name ID.
    my $dbID = $formID . "_database";
    # Start the form and the table.
    push @retVal, $self->StartForm($formID);
    # Create a javascript button for switching the documentation.
    my $fieldExpression = "document.getElementById('$dbID').value";
    my $showButton = JavaButton('Documentation',
                                $self->MiniJump("$FIG_Config::cgi_url/ErdbDocWidget.cgi",
                                                database => $fieldExpression));
    # Create a dropdown for selecting the database.
    my $selector = CGI::popup_menu(-name => 'database', -values => DATABASES(),
                                   -id => $dbID, -default => 'Sapling');
    # Put them together to make the first row.
    push @retVal, CGI::Tr(CGI::th('Select a Database'),
                          CGI::td("$selector $showButton"));
    # We need to build the row limit list. Get the standard limits.
    my $limits = LIMITS;
    # Build a simple hash mapping them to text.
    my %limitHash;
    for my $limit (@$limits) {
        $limitHash{$limit} = "$limit results";
    }
    # Add the number 1.
    $limitHash{1} = "1 result";
    # Add the default limit.
    my $dlimit = $ERDBExtras::query_limit;
    $limitHash{$dlimit} = "$dlimit results";
    # Get the complete list sorted by numeric value.
    my @limitList = sort { $a <=> $b } keys %limitHash;
    # This last step only happens if the user is privileged.
    if (CheckUser($self->application())) {
        # Add an unlimited option. We do this after the sort to force it to
        # the end of the list. Note the use of the parenthese to prevent the
        # constant UNLIMITED from quoting inside the curly braces.
        my $unlimit = UNLIMITED;
        $limitHash{UNLIMITED()} = "unlimited";
        push @limitList, UNLIMITED;
    }
    # Now we can create the options themselves.
    my $options = join(" &nbsp; ", "Row Limit",
                       CGI::popup_menu(-name => 'limit',
                                      -values => \@limitList,
                                      -labels => \%limitHash,
                                      -default => $dlimit),
                       "PERL Code Style",
                       CGI::popup_menu(-name => 'codeStyle',
                                       -values => CODE_STYLES),
                       "Trace Level", TraceMenu('traceLevel', 0));
    # Add them to the form.
    push @retVal, CGI::Tr(CGI::th("Special Options"),
                          CGI::td($options));
    # Now we have the real meat of the query form. It consists of a bunch of
    # input fields that are almost the same.
    push @retVal, MyRow("Object Names", objects => 1),
                  MyRow("Filter String", filterString => 1),
                  MyRow("Parameters<br />(one per line)", parms => 6),
                  MyRow("Fields", fields => 1);
    # Put in the SUBMIT button.
    push @retVal, CGI::Tr(CGI::td({ align => 'center', colSpan => 2 },
                                  $self->ResultButton(resultID => $formID,
                                                      RunQuery => 'RUN QUERY')));
    # Close the table and the form.
    push @retVal, $self->EndForm();
    # Return the result.
    return join("\n", @retVal);
}

=head3 RunQuery

    my $htmlText = $page->RunQuery();

Create the result table for a query. This method is called asynchronously
by the Ajax facility.

=cut

sub RunQuery {
    # Get the parameters.
    my ($self) = @_;
    # We'll format our HTML in here.
    my @retVal;
    # Get the application object and the CGI query object.
    my $application = $self->application();
    my $cgi = $application->cgi();
    # Set up to queue trace messages.
    my $traceLevel = $cgi->param('traceLevel') || 0;
    TSetup("$traceLevel SQL ErdbConsolePage ERDBQueryConsole", "QUEUE");
    Trace("Running query for ERDB Console Page.") if T(3);
    # Protect from errors.
    eval {
        # Get the parameters.
        my ($database, $objects, $filterString, $parms, $limit,
            $fields, $varNames) = ParseCGI($cgi);
        # Get the table component.
        my $mainTable = $application->component('Table');
        # Insure we have everything.
        if (! defined $database) {
            Confess("No database specified in query.");
        } elsif (! defined $objects) {
            Confess("No object name list specified in query.");
        } else {
            # Connect to the database. Note that the CDMI
            # databases are special.
            my $erdb;
            if ($database eq 'CDMIdev') {
                require Bio::KBase::CDMI::CDMI;
                $erdb = Bio::KBase::CDMI::CDMI->new(develop => 1);
            } elsif ($database eq 'CDMItest') {
                require Bio::KBase::CDMI::CDMI;
                $erdb = Bio::KBase::CDMI::CDMI->new(dbName => 'kbase_sapling_v2', 
                        userData => 'kbase_sapselect/kbase4me2',
                        dbhost => 'fir.mcs.anl.gov');
            } elsif ($database eq 'CDMI') {
                require Bio::KBase::CDMI::CDMI;
                $erdb = Bio::KBase::CDMI::CDMI->new();
            } else {
                $erdb = ERDB::GetDatabase($database);
            }
            # Compute the privilege level.
            my $privileged = CheckUser($application);
            # Turn on test mode.
            $erdb->SetTestEnvironment();
            # Now submit the query.
            my $console = ERDBQueryConsole->new($erdb, secure => $privileged);
            my $okFlag = $console->Submit($objects, $filterString, $parms, $fields, $limit);
            if (! $okFlag) {
                # Here we have an error.
                push @retVal, CGI::h3("Query Failed"), $console->Summary();
            } else {
                # It's time to start processing results. First, we format the
                # column data. The first column is always the record number.
                my @colData = { name => '#' };
                # Compute the rest of the columns from the header data.
                for my $col ($console->Headers()) {
                    push @colData, { name => $col->[0] };
                }
                $mainTable->columns(\@colData);
                # Now create the table cell array by looping through the data.
                # Note we stick a record number in the first position.
                my @rows;
                while (my @cells = $console->GetRow()) {
                    push @rows, [scalar(@rows) + 1, @cells];
                }
                # Set the table parameters.
                ConfigureTable($mainTable);
                # Emit the table.
                $mainTable->data(\@rows);
                push @retVal, TitleGroup('Query Results', $mainTable->output());
                # Emit the query summary.
                push @retVal, $console->Summary();
            }
            # Does the user want code?
            my $codeStyle = $cgi->param('codeStyle') || 'None';
            if ($codeStyle ne 'None') {
                # Yes. Get the name for the database variable.
                my $dbVarName = $cgi->param('dbVarName') || $erdb->PreferredName();
                # Format the code.
                my $codeString = $console->GetCode($dbVarName, $codeStyle, @$varNames);
                # Add it to the results.
                push @retVal, TitleGroup('PERL Code for Query', CGI::pre($codeString));
            }
        }
    };
    # For fatal errors, we need to note the fact.
    if ($@) {
        push @retVal, CGI::blockquote({ class => 'error' },
                                      "Fatal Error in query request: $@");
    }
    # Add the trace messages at the end.
    push @retVal, QTrace("html");
    # Return the result.
    return join("\n", @retVal);
}

=head2 The Method Form

The method form is a pure Javascript form that generates a POD header
and code skeleton for a PERL method. It contains the following
fields.

=over 4

=item Signature

B<Signature>: A PERL statement that serves as a prototype for computing
the invocation style, parameters, and return value of the new method.

=item Description

B<Description>: The method documentation. It will be used as the
text content of the method's POD header.

=item DocOnly

I<POD Only>: If checked, only the POD header is generated,
without the code skeleton.

=item Result

B<Method Source>: The documentation and skeleton will be produced in
this field.

=back

=head3 MethodForm

    my $htmlText = $page->MethodForm();

Generate the method generation form. This form is not submitted; instead,
it generates a result in one of the text fields. The result is
pre-selected for easy copying and pasting.

=cut

sub MethodForm {
    # Get the parameters.
    my ($self) = @_;
    # Declare the return variable.
    my @retVal;
    # Create the form ID.
    my $formID = "$self->{formID}_Method";
    # Start the form and the table.
    push @retVal, $self->StartForm($formID);
    # The first row contains the signature field. This is the standard
    # width.
    my $style = "width: " . FIELD_WIDTH . "px";
    push @retVal, CGI::Tr(CGI::th('Signature'),
                          CGI::td({ colspan => 2 },
                                  CGI::textfield(-name => 'Signature',
                                                 -style => $style)));
    # Next is the description field, the submit button, and the
    # documentation-only checkbox. This is a little narrower and taller.
    $style = "width: " . (FIELD_WIDTH - BUTTON_WIDTH - 5) . "px; height: 100px;";
    my $submitButton = JavaButton('GENERATE', "GenerateModule('$formID')");
    my $docOnlyCheckBox = CGI::checkbox(-name => 'DocOnly',
                                        -label => 'POD Only',
                                        -tabindex => 0);
    push @retVal, CGI::Tr(CGI::th('Description'),
                          CGI::td(CGI::textarea(-name => 'Description',
                                                -style => $style,
                                                -class => 'common')),
                          CGI::td(join("<br />\n", $submitButton,
                                       $docOnlyCheckBox)));
    # Then we have the result box and the clear button.
    my $clearButton = JavaButton('CLEAR FORM', "ResetForm('$formID')");
    push @retVal, CGI::Tr(CGI::th('Method Source'),
                          CGI::td(CGI::textarea(-name => 'Result',
                                                -style => $style,
                                                -class => 'common')),
                          CGI::td($clearButton));
    # Put a documentation widget into the last row.
    push @retVal, CGI::Tr(CGI::th(DOC_WIDGET_NAME),
                          CGI::td({ colspan => 2 },
                                  $self->DocWidget($formID)));
    # Close the table and the form.
    push @retVal, $self->EndForm();
    # Return the result.
    return join("\n", @retVal);
}

=head2 The Tracing Form

This form controls the tracing facility and performs special functions for
debugging.

=over 4

=item actionType

Command to execute. C<Activate> will activate tracing and clear the temporary
file (if any), C<Terminate> will turn tracing off, C<Show Log> will display the
trace messages or the error log, and C<Show File> will display a tab-delimited
file.

=item build

If TRUE, then the source code will be rebuilt. This parameter is used for the
C<Activate> action only.

=item destination

Tracing destination: C<FILE> to write to a temporary file, C<APPEND> to
append to a temporary file, or C<WARN> to write to the error log. This parameter
is used for the C<Activate> action only.

=item environment

The environment in which CGI scripts should run. This is stored in the C<SPROUT>
cookie and is interrogated by the SEED Viewer to determine where it should get
the data and what display styles it should use.

=item fromStart

If TRUE, then the trace file or error log will be displayed from the beginning
of the file; otherwise, the chose file will be displayed from the end. This
parameter is used for the C<Show Log> action only.

=item hours

The number of hours to leave tracing active. This parameter is used for the
C<Activate> action only.

=item innerTracing

If specified, then this script will trace at level 3 to a file named
C<EmergencyDiagnostics.log> in the FIG temporary directory.

=item level

The trace level. The higher the trace level, the more messages will appear. This
parameter is used for the C<Activate> action only.

=item logType

The log to display. C<Trace> will display the trace log, C<Error> will display
the error log, and C<Command> will display the command-line trace log. This
parameter is used for the C<Show Log> action only.

=item packages[]

An array of tracing modules to turn on. Most tracing is configured using the
lowest-level name of the package containing the trace message, but there are
some special names defined as well. This parameter is used for the C<Activate>
action only.

=item robotic

TRUE if this user should be considered a robot. This causes the C<test_bot> flag
to be set for WebApplications.

=item section

The number of bytes to display in the trace file or error log. This
parameter is used for the C<Show> action only.

=item traceKey

Tracing key for the current user.

=back

=head3 LOG_FINDER

This is a list of directories in which to look for the error log. The first location
is the B<FIG_Config> variable C<error_log>. Subsequent locations are based on the various
configurations found on the Argonne MCS machines.

=cut

use constant LOG_FINDER => [$FIG_Config::error_log,
                            qw(/var/log/httpd/error_log /var/log/apache2/error.log)];

=head3 SPECIAL_MODULES

This is a hash that maps the name of each special module to its description.

=cut

use constant SPECIAL_MODULES => {
            SQL             => 'SQL statements',
            Load            => 'SQL table loads',
            nsims           => 'Sim Server requests',
            CGI             => 'CGI parameters',
            ERDB            => 'ERDB package',
            ErdbConsolePage => 'ERDB debugger',
            IMG             => 'HTML image tags',
            Sprout          => 'Sprout package',
            nbbh            => 'BBH Server requests',
            FIG             => 'FIG package',
            File            => 'Tracer file activity',
            WebApplication  => 'WebApplication package',
            Raw             => 'Show raw HTML',
            Feed            => 'RSS feed debugging',
            SearchHelper    => 'NMPDR search manager',
            ResultHelper    => 'NMPDR search results',
            SearchSkeleton  => 'NMPDR search facility',
            SFXlate         => 'SFXlate package',
            Table           => 'Table Web Component',
            SeedUtils       => 'SEED Utilities',
};

=head3 ENVIRONMENTS

This is a map of environment names to environment types. The selected
environment determines how the FIG-like object that accesses the data is
constructed.

=cut

use constant ENVIRONMENTS => { 0 => 'Default', FIG => 'FIG',
                               Sprout => 'Sprout', SproutRewind => 'Old Sprout' };

=head3 DURATIONS

This maps durations (expressed in hours) to duration labels.

=cut

use constant DURATIONS => { 1 => '1 hour',  2 => '2 hours',
                            4 => '4 hours', 8 => '8 hours',
                           24 => '1 day'    };

=head3 LOG_TYPES

This is the list of log types.

=cut

use constant LOG_TYPES => [qw(Trace Error Command)];

=head3 PAGE_SIZES

This maps byte counts to page sizes.

=cut

use constant PAGE_SIZES => {    51200 => '50K',
                               102400 => '100K',
                               512000 => '500K',
                              1048576 => '1M',
                              5242880 => '5M',
                             10485760 => '10M',
                             52428800 => '50M',
                            524288000 => '500M',
                        };

=head3 DEFAULT_PAGE_SIZE

This is the default page size.

=cut

use constant DEFAULT_PAGE_SIZE => 512000;

=head3 TEXT_WIDTH

This is the width for the tracing table's text column.

=cut

use constant TEXT_WIDTH => 700;

=head3 TracingForm

    my $html = $page->TracingForm();

Return the HTML for a tracing dashboard.

=cut

sub TracingForm {
    # Get the parameters.
    my ($self) = @_;
    # The form will be built in here.
    my @retVal;
    # Create the form ID.
    my $formID = "$self->{formID}_Tracing";
    # Get the user object and compute the tracing key.
    my $application = $self->application;
    my $user = $application->session->user;
    my $tracingKey = (defined $user ? $user->login . "Web" : 'Nobody');
    # Start the form and the table.
    push @retVal, $self->StartForm($formID);
    # Put in a hidden field for the action type and one containing the base
    # URL for web testing.
    push @retVal, CGI::hidden(-name => 'actionType');
    push @retVal, CGI::hidden(-id => "${formID}_baseURL", -value => $FIG_Config::cgi_url);
    # The top section is for configuring tracing of web services. The first row
    # is the trace level and the file mode.
    my $fileMode = CGI::popup_menu(-name => 'destination', -default => 'APPEND',
                                   -values => [qw(FILE APPEND WARN)],
                                   -labels => {FILE => 'Temporary File (overwrite)',
                                               APPEND => 'Temporary File (append)',
                                               WARN => 'Error Log'});
    push @retVal, CGI::Tr(CGI::th('Trace Level'),
                          CGI::td(TraceMenu('level')),
                          CGI::th('Destination'),
                          CGI::td($fileMode),
                          CGI::td(CGI::checkbox(-name => 'innerTracing',
                                                -label => 'Diagnose')));
    # Next comes the tracing modules. We have a bunch of checkboxes for special
    # and common modules, plus a text box to specify additional module names.
    # The whole shebang is formatted as a table. First we get the keys.
    my @keys = sort keys %{SPECIAL_MODULES()};
    # The table will be build in rows of four keys. Each key occupies two
    # cells.
    my @rows;
    my $row = [];
    for my $key (@keys) {
        # Put the next key in the current row.
        push @$row, CGI::td(qq(<input type="checkbox" value="$key" name="packages"));
        push @$row, CGI::td(SPECIAL_MODULES->{$key});
        # If the row is full, push it onto the main list and reset it.
        if (scalar(@$row) == 8) {
            push @rows, $row;
            $row = [];
        }
    }
    # Keep the residual fragment.
    if (scalar(@$row) > 0) {
        push @rows, $row;
    }
    # Add a final row for user-specified modules.
    my $textField = CGI::textfield(-style => 'width: 99%',
                                   -name => 'packages');
    push @rows, [CGI::td({ colSpan => 2 }, "Other Modules"),
                 CGI::td({ colSpan => 6 }, $textField)];
    # Create the table.
    my $moduleTable = CGI::table({ class => 'fancy' }, map { CGI::Tr(@$_) } @rows);
    # Put it into the form.
    push @retVal, CGI::Tr(CGI::th('Modules'), CGI::td({ colSpan => 4 }, $moduleTable));
    # The next line contains specifications for the trace duration and
    # the running environment (SEED or Sprout).
    my @durations = sort { $a <=> $b } keys %{DURATIONS()};
    my $durationMenu = CGI::popup_menu(-values => \@durations,
                                       -labels => DURATIONS,
                                       -default => 4,
                                       -name => 'hours');
    my $environmentMenu = CGI::popup_menu(-values => [sort keys %{ENVIRONMENTS()}],
                                          -labels => ENVIRONMENTS,
                                          -name => 'environment',
                                          -default => 0);
    push @retVal, CGI::Tr(CGI::th('Duration'),
                          CGI::td($durationMenu),
                          CGI::th('Environment'),
                          CGI::td($environmentMenu),
                          CGI::td(CGI::checkbox(-name => 'robotic',
                                                -label => 'Robotic')));
    # Now the action buttons and the tracing key.
    my $actionButtons = join(" ", $self->TracerButton('Activate', $formID),
                                  $self->TracerButton('Terminate', $formID));
    push @retVal, CGI::Tr(CGI::th('Trace Key'),
                          CGI::td(CGI::textfield(-name => 'traceKey',
                                                 -value => $tracingKey)),
                          CGI::th('Action'),
                          CGI::td($actionButtons),
                          CGI::td(CGI::checkbox(-name => 'build',
                                                -label => 'Build on Activate')));
    # Now we have a secondary section of the form used for displaying the
    # various logs. The first row allows the user to execute a URL in a new window.
    my $urlField = CGI::textfield(-id => "${formID}_pathURL",
                                  -style => 'width: 100%');
    my $testButton = JavaButton('Run Test', "RunTest('$formID')");
    push @retVal, CGI::Tr(CGI::th('Path URL'),
                          CGI::td({ colSpan => 3 }, $urlField),
                          CGI::td($testButton));
    # The next row chooses the particular log and the page size.
    my $logMenu = CGI::popup_menu(-name => 'logType',
                                  -values => LOG_TYPES,
                                  -default => LOG_TYPES->[0]);
    my @pageKeys = sort { $a <=> $b } keys %{PAGE_SIZES()};
    my $pageSizeMenu = CGI::popup_menu(-name => 'section',
                                       -values => \@pageKeys,
                                       -labels => PAGE_SIZES,
                                       -default => DEFAULT_PAGE_SIZE);
    my $dirCheckBox = CGI::checkbox(-name => 'fromStart', -label => 'from start');
    push @retVal, CGI::Tr(CGI::th('Display'),
                          CGI::td($logMenu),
                          CGI::th('Size'),
                          CGI::td(join(" ", $pageSizeMenu, $dirCheckBox)),
                          CGI::td($self->TracerButton('Show Log', $formID)));
    # The final row displays a tab-delimited file.
    push @retVal, CGI::Tr(CGI::th('TBL File'),
                          CGI::td({ colSpan => 3 }, CGI::textfield(-name => 'tblFile',
                                                                   -style => 'width: 100%')),
                          CGI::td($self->TracerButton('Show File', $formID)));
    # Close the table and the form.
    push @retVal, $self->EndForm();
    # Return the result.
    return join("\n", @retVal);
}

=head3 RunTracing

    my $htmlText = $page->RunTracing();

Perform a tracing action. This includes activating tracing, turning
tracing off, and displaying a trace log.

=cut

sub RunTracing {
    # Get the parameters.
    my ($self) = @_;
    # Get the application object and the CGI query object.
    my $application = $self->application();
    my $cgi = $application->cgi();
    # Validate the user.
    Confess("ERDB Console security failure.") unless CheckDeveloper($application);
    # The html text will be built in here.
    my @retVal;
    # Configure our internal tracing, if necessary.
    if ($cgi->param('innerTracing')) {
        TSetup("3 LogReader Tracer ErdbConsolePage Table CGI", ">$FIG_Config::temp/EmergencyDiagnostics.log");
        Tracer::TraceParms($cgi);
    } else {
        TSetup("0", "NONE");
    }
    # Get the tracing key.
    my $traceKey = $cgi->param('key') || 'Nobody';
    # Process according to the action type.
    my $action = $cgi->param("actionType") || 'Show Log';
    if ($action eq 'Activate') {
        push @retVal, $self->ActivateTracing($cgi);
    } elsif ($action eq 'Terminate') {
        push @retVal, $self->TerminateTracing($cgi);
    } elsif ($action eq 'Show File') {
        push @retVal, $self->ShowTabFile($cgi);
    } else {
        push @retVal, $self->ShowLog($cgi);
    }
    # Return the result.
    return join("\n", @retVal);
}

=head3 ActivateTracing

    my @htmlLines = $page->ActivateTracing($cgi);

Activate tracing for this user, and optionally rebuild the source. This
function sets up the emergency tracing file for the specified tracing
key. As a side effect, it deletes any existing trace log.

=over 4

=item cgi

CGI query object containing the parameters to this request.

=item RETURN

Returns lines of HTML that indicate what happened.

=back

=cut

sub ActivateTracing {
    # Get the parameters.
    my ($self, $cgi) = @_;
    # Declare the return variable.
    my @retVal;
    # Get the tracing key.
    my $key = $cgi->param('traceKey');
    if (! defined $key) {
        push @retVal, FormatError("No tracing key specified.");
    } else {
        # Get the package list. Note that part of our package list may come in as
        # a comma- or space-delimited string, so we split the individual parameters up.
        my @packages = map { split(/\s*[\s,]\s*/, $_) } $cgi->param('packages');
        # Get the other parameters. Note we have defaults for everything.
        my $level = $cgi->param('level') || 0;
        my $destination = $cgi->param('destination') || 'FILE';
        my $hours = $cgi->param('hours') || 4;
        my $environment = $cgi->param('environment');
        my $robotic = $cgi->param('robotic') || 0;
        # Make the environment variable more displayable.
        if (! $environment) {
            require FIGRules;
            $environment = (FIGRules::nmpdr_mode($cgi) ? '(Sprout)' : '(FIG)');
        }
        # Indicate the robotic status.
        $environment = ($robotic ? "robotic" : "normal") . " $environment";
        # If there's already a trace file, delete it.
        my $traceFileName = Tracer::EmergencyFileTarget($key);
        if (-f $traceFileName) {
            unlink $traceFileName;
            push @retVal, CGI::p("$traceFileName deleted.");
        }
        # Does the user want to build? If so, the output goes in here.
        my @buildLines;
        if ($cgi->param('build')) {
            # Rebuild the NMPDR.
            push @retVal, CGI::p("Rebuilding NMPDR.");
            chdir "$FIG_Config::fig_disk/dist/releases/current";
            @buildLines = `WinBuild/Maker.pl --online`;
        } else {
            push @retVal, CGI::p("No rebuild requested.");
        }
        # Turn on emergency tracing.
        Emergency($key, $hours, $destination, $level, @packages);
        # List the modules activated.
        if (! @packages) {
            push @retVal, CGI::p("No trace modules activated.");
        } else {
            push @retVal, CGI::p("Modules activated: " . join(", ", @packages) . ".");
        }
        # Format the status lines.
        my @dataLines =  ("Destination is " . Tracer::EmergencyTracingDest($key, $destination) . ".",
                         "Duration is $hours hours (or end of session).",
                         "Trace level is $level.",
                         "Operating environment is $environment.");
        # Display them all.
        for my $line (@dataLines) {
            push @retVal, CGI::p($line);
        }
        # Show the build. It's already been formatted as HTML.
        push @retVal, @buildLines;

    }
    # Return the result.
    return @retVal;
}

=head3 TerminateTracing

    my @htmlLines = $page->TerminateTracing($cgi);

Terminate web tracing. This function deletes the emergency tracing files
so that no tracing will occur.

=over 4

=item cgi

CGI query object containing the parameters.

=item RETURN

Returns a list of HTML lines indicating what happened.

=back

=cut

sub TerminateTracing {
    # Get the parameters.
    my ($self, $cgi) = @_;
    # Declare the return variable.
    my @retVal;
    # Get the tracing key.
    my $key = $cgi->param('traceKey');
    if (! defined $key) {
        push @retVal, FormatError("No tracing key specified.");
    } else {
        # Get the emergency file name.
        my $efileName = Tracer::EmergencyFileName($key);
        # Delete the tracing key file.
        if (-f $efileName) {
            unlink $efileName;
            push @retVal, CGI::p("Tracing key file deleted.");
        } else {
            push @retVal, CGI::p("Tracing was already turned off.");
        }
    }
    # Return the result.
    return @retVal;
}

=head3 ShowTabFile

    my @htmlLines = $page->ShowTabFile($cgi);

Display the specified tab-delimited file. Each line of the file will be
shown as a table row, and each field as a cell.

=over 4

=item cgi

CGI query object containing the parameters.

=item RETURN

Returns a list of html lines containing the desired output.

=back

=cut

sub ShowTabFile {
    # Get the parameters.
    my ($self, $cgi) = @_;
    # Declare the return variable.
    my @retVal;
    # Get the file name.
    my $tblFile = $cgi->param('tblFile');
    if (! $tblFile) {
        push @retVal, FormatError("No file name specified.");
    } elsif (! -f $tblFile) {
        push @retVal, FormatError("File \"$tblFile\" not found.");
    } elsif (-z $tblFile) {
        push @retVal, FormatError("File \"$tblFile\" is empty.");
    } else {
        # Get the table component.
        my $application = $self->application();
        my $mainTable = $application->component('Table');
        # Configure it in the normal way.
        ConfigureTable($mainTable);
        # Open the input file.
        my $ih = Open(undef, "<$tblFile");
        # Get the size parameter.
        my $section = $cgi->param('section') || 0;
        # Get the first line of the file and use it to set up the columns.
        my @flds = Tracer::GetLine($ih);
        $mainTable->columns(['#', 1 .. scalar(@flds)]);
        # Initialize the line and size counters.
        my $line = 1;
        my $size = 0;
        # This will be set to FALSE when we run out of lines.
        my $done = 0;
        # Loop through the lines, Constructing rows.
        my @rows;
        while (! $done) {
            # Output this row of the file.
            push @rows, [$line, map { CGI::escapeHTML($_) } @flds];
            # Update the progress counters.
            $line++;
            for my $fld (@flds) {
                $size += length($fld);
            }
            if (! eof $ih && $size < $section) {
                @flds = Tracer::GetLine($ih);
            } else {
                $done = 1;
            }
        }
        # Put the rows in the table.
        $mainTable->data(\@rows);
        # Output the table.
        push @retVal, $mainTable->output();
    }
    # Return the result.
    return @retVal;
}


=head3 ShowLog

    my @htmlLines = $page->ShowLog($cgi);

Display the specified log file. The log is formatted as a WebComponent
table.

=over 4

=item cgi

CGI query object containing the parameters.

=item RETURN

Returns a list of html lines containing the desired output.

=back

=cut

sub ShowLog {
    # Get the parameters.
    my ($self, $cgi) = @_;
    # Declare the return variable.
    my @retVal;
    # Get the number of bytes to display and the start point.
    my $section = $cgi->param('section') || 0;
    my $fromStart = $cgi->param('fromStart');
    # Get the tracing key.
    my $key = $cgi->param('traceKey') || '';
    # Get the file type.
    my $type = $cgi->param('logType') || 'Trace';
    # Find the log file and compute its column count. The column count is currently
    # the same for both, but this might not always be the case.
    my $fileName;
    if ($type eq 'Trace') {
        # Get the trace file name.
        $fileName = FindTraceLog($key, \@retVal);
    } elsif ($type eq 'Command') {
        # Compute the command-line key.
        my $key2 = ($key =~ /(.+)Web/ ? $1 : $key);
        # Get the command-line trace file name.
        $fileName = FindTraceLog($key2, \@retVal);
    } elsif ($type eq 'Error') {
        # Get the error log name.
        $fileName = FindErrorLog(\@retVal);
    } else {
        push @retVal, FormatError("Unknown log file type \"$type\".");
    }
    # Only proceed if we found a file.
    if ($fileName) {
        # Get the table component.
        my $application = $self->application();
        my $mainTable = $application->component('Table');
        # Display the file found.
        push @retVal, $self->ShowLogFile($mainTable, $fileName, $section, $fromStart);
    }

    # Return the result.
    return @retVal;
}

=head3 FindTraceLog

    my $fileName = FindTraceLog($key, \@lines);

Find the trace log for the specified key.

=over 4

=item key

Tracing key that identifies the file to display.

=item lines

Reference to a list. Error and status information will be inserted into the list
in HTML form.

=item RETURN

Returns the trace file name, or an undefined value if the trace file is empty or nonexistent.

=back

=cut

sub FindTraceLog {
    # Get the parameters.
    my ($key, $lines) = @_;
    # Declare the return variable.
    my $retVal;
    # Insure we have a valid key.
    if (! $key) {
        push @$lines, FormatError('No tracing key specified.');
    } else {
        # Get the trace file name.
        my $traceFileName = Tracer::EmergencyFileTarget($key);
        push @$lines, CGI::p("Trace file name is $traceFileName.");
        # See if tracing is turned on.
        if (! -f $traceFileName) {
            push @$lines, CGI::p("No trace file found for $key.");
        } elsif (! -s $traceFileName) {
            push @$lines, CGI::p("The trace file for $key is empty.");
        } else {
            # Here we have a file to read.
            $retVal = $traceFileName;
            push @$lines, CGI::p("Tracing output found in $traceFileName.");
        }
    }
    # Return the result.
    return $retVal;
}


=head3 FindErrorLog

    my $fileName = SeedViewer::WebPage::ErdbConsolePage::FindErrorLog(\@lines);

Return the name of the error log file.

=over 4

=item lines

Reference to a list. Error and status information will be pushed onto the list
in HTML format.

=item RETURN

Returns the fully-qualified error log name or C<undef> if the error log could
not be found.

=back

=cut

sub FindErrorLog {
    my ($lines) = @_;
    # Declare the return variable.
    my $retVal;
    # Loop through the possible log file names until we find one.
    for my $log (@{LOG_FINDER()}) { last if $retVal;
        # We do a defined check here in case the FIG_Config variable is not set.
        if (defined $log && -f $log) {
            $retVal = $log;
        }
    }
    # Check for unusual conditions.
    if (! defined $retVal) {
        push @$lines, FormatError("Error log file not found. Locate the log and put its name in \$FIG_Config::error_log.");
    } elsif (! -s $retVal) {
        push @$lines, FormatStatus("Error log file \"$retVal\" is empty.");
        # Denote we haven't found an error log.
        undef $retVal;
    }
    # Return the result.
    return $retVal;
}

=head3 ShowLogFile

    my $html = $page->ShowLogFile($mainTable, $fileName, $section, $fromStart);

Store the specified portion of the specified log file in a table
component and return the result.

=over 4

=item mainTable

Table component into which the data should be placed.

=item fileName

Name of the file containing the data.

=item section

Size of the file section to display.

=item fromStart

TRUE to display the file from the beginning, FALSE to display it from the end.

=item RETURN

Returns the HTML for the filled table.

=back

=cut

sub ShowLogFile {
    # Get the parameters.
    my ($self, $mainTable, $fileName, $section, $fromStart) = @_;
    # Create a log reader for the file.
    my $logrdr = LogReader->new($fileName, columnCount => 5);
    # Get the file size.
    my $fileSize = $logrdr->FileSize();
    # Compute the starting offset of the section to display.
    my $start = ($fromStart ? 0 : $fileSize - $section);
    # Insure the start point is valid.
    $start = Constrain($start, 0, $fileSize);
    # Apply the section size to compute the end point.
    my $end = Constrain($start + $section, 0, $fileSize);
    # Start with a status message.
    my $len = $end - $start;
    my $lenK = ($len < 5000 ? $len : int(($len + 512)/1024) . "K");
    $lenK .= " characters (". int(Tracer::Percent($len, $fileSize)) . "%)";
    my $retVal = CGI::p("Acquired approximately $lenK starting at position $start.");
    # Put some space above the table.
    $retVal .= "<br /><br />\n";
    # Position the log reader.
    $logrdr->SetRegion($start, $end);
    # We will be marking the time column in the table as a header whenever it is different from
    # the previous value. We prime the loop with the fragment indicator, so that if we start
    # with a fragment, we don't flag it.
    my $lastTime = LogReader::FragmentString();
    # Similarly, we throw away redundant referrers. We prime the loop with an
    # empty referrer string.
    my $lastReferrer = "";
    # Define the table columns.
    $mainTable->columns([qw(Time Level Name Loc Message)]);
    # Configure the table.
    ConfigureTable($mainTable);
    # We'll put the table rows in here.
    my @rows;
    # We want to linkify FIG IDs in the main section. To do this, we form a URL
    # that finds the correct annotation page if we add a FIG ID to it.
    my $linkURL = $self->application->url . "?page=Annotation;feature=";
    # Create the style string for a message cell.
    my $cellStyle = "width: " . TEXT_WIDTH . "px";
    # Loop through the file, reading records.
    my $record;
    while (defined ($record = $logrdr->GetRecord())) {
        # We'll put the output table row in here.
        my $line = [];
        # Pop off the timestamp.
        my $time = shift @{$record};
        # This is the cell coloring, white for normal, cyan for a new time stamp.
        my $color = '#fff';
        # See if it's changed. Note that these are formatted times, so we do a string compare.
        # They are not numbers!
        if ($time ne $lastTime) {
            # It's a new time stamp.
            $color = '#cff';
        }
        # Push in the time column.
        push @$line, { data => $time, highlight => $color };
        # Save the time stamp for the next time row.
        $lastTime = $time;
        # Pop off the last column. This is the free-form string, and it requires special handling.
        my $string = pop @{$record};
        # Append the middle columns.
        for my $data (@$record) {
            push @$line, { data => $data, highlight => $color };
        }
        # HTML-escape the final string.
        my $escaped = CGI::escapeHTML($string);
        # Delete leading whitespace.
        $escaped =~ s/^\s+//;
        # Delete the leading tab thingy (if any).
        $escaped =~ s/^\\t//;
        # Check for a referrer indication.
        if ($escaped =~ /(.+),\s+referr?er:\s+(.+)/) {
            # We've got one. Split it from the main message.
            $escaped = $1;
            my $referrer = $2;
            # If it's new, tack it back on with a new-line so it separates from
            # the main message when displayed.
            if ($referrer ne $lastReferrer) {
                $escaped .= "\n  Via $referrer";
                # Save it for the next check.
                $lastReferrer = $referrer;
            }
        } else {
            # No referrer, so clear the remembered indicator.
            $lastReferrer = "";
        }
        # The final string may contain multiple lines. The first line is treated as normal text,
        # but subsequent lines are preformatted.
        my ($cell, $others) = split /\s*\n/, $escaped, 2;
        # Linkify any FIG IDs in the main cell text.
        $cell =~ s/(fig\|\d+\.\d+\.[a-z]+\.\d+)/<a href="$linkURL$1" target="_blank">$1<\/a>/g;
        if ($others) {
            # Here there are other lines, so we preformat them. Note that we first strip off any final
            # new-line.
            chomp $others;
            $cell .= CGI::pre({ style => "width: 100%; background-color: #ffc; overflow: auto" }, $others);
        }
        # Output the cell.
        push @$line, { data => CGI::div({ style => $cellStyle }, $cell),
                       highlight => $color };
        # Output the row.
        push @rows, $line;
    }
    # Fill the table.
    $mainTable->data(\@rows);
    # Now we need to determine where to start displaying the table. Unless
    # we are displaying from the start, we want the last line of the section
    # to be visible.
    if (! $fromStart) {
        my $hiddenRows = scalar(@rows) - TABLE_ROWS();
        Trace("$hiddenRows will be hidden.") if T(3);
        if ($hiddenRows > 0) {
            $mainTable->offset($hiddenRows);
        }
    }
    # Add the table to the status message.
    $retVal .= $mainTable->output();
    # Return the whole thing.
    return $retVal;
}


=head2 The Server Form

The server form is used to test the various server applications. The user
specifies the server name, the input value, and the function. The output from the
server is displayed in the result tab.

=over 4

=item serverName

File name of the server script to be tested (e.g. C<sap_server.cgi>).

=item args

YAML text that can be parsed to produce the arguments.

=item function

Function to run on the server.

=back

=head3 ServerForm

    my $htmlText = $page->ServerForm();

Return the HTML for the server testing form.

=cut

sub ServerForm {
    # Get the parameters.
    my ($self) = @_;
    # The form will be built in here.
    my @retVal;
    # Create the form ID.
    my $formID = "$self->{formID}_Server";
    # Start the form and the table.
    push @retVal, $self->StartForm($formID);
    # The first line is the server name and function.
    push @retVal, CGI::Tr(CGI::th('Server Script'),
                          CGI::td(CGI::textfield(-name => 'serverName',
                                                 -size => 30)),
                          CGI::th('Function'),
                          CGI::td(CGI::textfield(-name => 'function',
                                                 -size => 30)));
    # Now we have a large text box for the YAML arguments.
    my $textStyle = "width: " . FIELD_WIDTH . "px; height: 190px";
    push @retVal, CGI::Tr(CGI::th('Parameters'),
                          CGI::td({ colspan => 3 },
                                  CGI::textarea(-name => 'args',
                                                -style => $textStyle)));
    # Below this is a submit button in a row by itself.
    push @retVal, CGI::Tr(CGI::td('&nbsp;'),
                          CGI::td({ colspan => 3, style => 'text-align: center' },
                                  $self->ResultButton(resultID => $formID,
                                                      RunServer => 'SUBMIT')));
    # At the very bottom we have a documentation widget and an encoding dropdown.
    push @retVal, CGI::Tr(CGI::th(DOC_WIDGET_NAME),
                          CGI::td($self->DocWidget($formID)),
                          CGI::th('Encoding'),
                          CGI::td(CGI::popup_menu(-name => 'encoding',
                                                  -values => ['yaml', 'json'])));
    # Close the form.
    push @retVal, $self->EndForm();
    # Return the result.
    return join("\n", @retVal);
}

=head3 RunServer

    my $html = $page->RunServer();

Submit a request to a server. The server is not invoked using a true CGI
protocol, but is instead run from the command line using a file
containing the CGI parameters.

=cut

sub RunServer {
    # Get the parameters.
    my ($self) = @_;
    # The lines of result text will be put in here.
    my $retVal;
    # Get the CGI query object.
    my $application = $self->application;
    my $cgi = $application->cgi;
    # Get the current user.
    my $user = $application->session->user;
    # Insure the user is privileged.
    Confess("ERDB console security failure.") unless CheckDeveloper($application, $user);
    # Compute the tracing key.
    my $key = EmergencyKey($cgi);
    # If no key has been set by the tracing facility, we default to the user ID.
    $key = $user->login if ! $key;
    # Get the name of the server script.
    my $scriptName = $cgi->param('serverName');
    if (! $scriptName) {
        Confess("No script name specified.");
    } else {
        # Compute the name of the script file.
        my $scriptFile = "$FIG_Config::fig/CGI/$scriptName";
        # Insure it exists.
        if (! -f $scriptFile) {
            Confess("Server script not found at $scriptFile.");
        } else {
            # Delete the server name parameter.
            $cgi->delete('serverName');
            # Insure the argument parameter will parse correctly.
            my $args = $cgi->param('args');
            if ($cgi->param('encoding') eq 'yaml') {
                if (! defined $args || $args eq '') {
                    $args = "---\n";
                } elsif ($args !~ /\n$/s) {
                    $args .= "\n";
                }
            }
            $cgi->param(args => $args);
            # Write the CGI parameters to a file. The file will be read by the
            # server script.
            my $oh = Open(undef, ">$FIG_Config::temp/$key.parms");
            $cgi->save($oh);
            close $oh;
            # Invoke the server script and save its output.
            my $outputFile = "$FIG_Config::temp/$key.log";
            system("$scriptFile $key >$outputFile");
            $retVal = Tracer::GetFile($outputFile);
        }
    }
    # Return the result as preformatted text.
    return CGI::pre($retVal);
}

=head3 required_rights

    $page->required_rights();

This method lists the rights required to use this page. It returns a list of 3-tuples.
The first element of each tuple is a right type (view, change, administer, login), the second
is a data type, and the final element is a data id. The user must have all the
listed rights in order to use the page.

=cut

sub required_rights {
    return [  [qw(query database *)], ];
}


1;
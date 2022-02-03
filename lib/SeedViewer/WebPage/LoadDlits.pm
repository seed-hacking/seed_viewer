package SeedViewer::WebPage::LoadDlits;

use base qw( WebPage );

1;

use strict;
use warnings;

use FIG;

=pod

=head1 NAME

LoadDlits - an instance of WebPage which uploads and installs a file of dlits

=head1 DESCRIPTION

upload and install a file of dlits - tab separated file
peg pubmed_id curartor

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instantiated.

=cut

sub init {
  my ($self) = @_;

  $self->application->no_bot(1);

  return 1;
}

=item * B<output> ()

Returns the html output of the LoadDlits page.

=cut

sub output {
  my ($self) = @_;

  # fetch application, cgi and fig
  my $application = $self->application();
  my $cgi = $application->cgi();
  my $fig = $application->data_handle('FIG');

  my $base_url = "seedviewer.cgi?page=EditPubMedIdsDSLits&feature=";


  $self->title('LoadDlits');

  my $html = "<h2>LoadDlits</h2>";
  
#  check if we have an upload file
if ($cgi->param('upload_file')) {
      # get the uploaded data
      my $file_content = "";
      my $file = $cgi->param('upload_file');
      $html .= "Attempting to add Dlits ...<br>";
      while (<$file>) {
	    chomp;
	    my ($peg, $pubmed, $curator) = split("\t", $_);
	    my $rc = 0;
	    my $peg_link = $peg;
	    if ($fig->is_real_feature($peg)) {
	#	    print STDERR $_;
		    $rc = $fig->add_dlit(-status => 'D',
					    -peg => $peg,
					    -pubmed => $pubmed,
					    -curator => $curator,
					    -override => 1);    
		    if ($rc) {
			    $peg_link = "<a href='$base_url$peg'>$peg </a>";
		    }

	    }
	    $html .= $rc ? "Success:" : "Failure:";
	    $html .= " $peg_link, $pubmed, $curator<br>";
      }
      #my @lines = split /[\r\n]+/, $file_content;
}
  $html .= $self->start_form('upload_dlit_form');
  $html .= "Upload a  3 column tab separated file of peg id, pubmed id, curator name<br><br>";

  $html .= $cgi->filefield(-name=>'upload_file')."<br>";
  $html .= $self->button();
  $html .= $self->end_form();


  return $html;
}

sub required_rights {
  return [ ['login'] ];
}


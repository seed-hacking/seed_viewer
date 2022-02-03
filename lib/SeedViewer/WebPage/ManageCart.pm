package SeedViewer::WebPage::ManageCart;
use strict;
use warnings;
use FIG;
use FIG_Config;
use PersistentSets;
use Data::Dumper;
use base qw(SimpleWebPage);


sub page_title
{
    return "Manage Cart";
}

sub page_content
{
    my($self, $fig, $cgi, $uname, $my_url) = @_;
    my $dbh = $fig->seed_global_dbh();

  my $content = "";
  my @ids;
  my $foo = $cgi->Vars;
  #$content .= Dumper $foo;
  #$content .= $cgi->param('function');
  #$content .= $cgi->param('feature');
  if (! $uname) {
	die "Not signed in";
	#$content .= "Not signed in";
  } elsif (defined($cgi->param('function'))) {
	#$content .= $cgi->param('function');
	#$content .= $cgi->param('feature');
	if ($cgi->param('function') eq 'add') {
		my $fid = $cgi->param('feature');
		push (@ids, $fid);
		my $relational_db_response;
	
		if (! PersistentSets::type_of_set("Cart", $uname)) {
			if (!PersistentSets::create_set("fid", "Cart", $uname, "FID Cart Set")) {
				die ("Cannot create set Cart $uname\n");
			}
		}
		if (! PersistentSets::put_to_set("Cart", $uname, \@ids)) {
			die ("Cannot add entry to Cart $uname\n");
		}
			 
    		$content .= "$fid Added to Cart";
	} elsif ($cgi->param('function') eq 'view') {
		$content .= build_cart_view($uname, $cgi, $dbh, $self);	
	}
   } elsif (defined($cgi->param('Delete'))) {
		@ids = $cgi->param('selector');
		my $ret = PersistentSets::delete_from_set("Cart", $uname, \@ids);
		$content .= build_cart_view($uname, $cgi, $dbh, $self);	

   } else {
		$content .= $self->start_form();
		$content .= "<b>Enter PEG:</b>" . '&nbsp;' x 5;
		$content .= $cgi->textfield(-name    => "feature",
					    -size    => '30');
		$content .= '&nbsp;' x 5 . $self->button('Select') . "<br />";
		$content .= $self->end_form;
	}
  return $content;

}


sub build_cart_view {
	my ($user, $cgi, $dbh, $self) = @_;
	

	my $content .= $self->start_form();
	$content .= $cgi->submit('Delete', 'Delete Selected');
	my $ids = PersistentSets::get_set("Cart", $user);
        #$content .= "<b>Enter PEG:</b>" . '&nbsp;' x 5;
        #$content .= $cgi->textfield(-name    => "feature",
        #                            -size    => '30');
        #$content .= '&nbsp;' x 5 . $self->button('Select') . "<br />";
	$content .=  "<table>\n";
        my %l;
	for my $id (@$ids) {
			$l{"$id"} = "SELECT";
			#$content .=  "<table border=2>\n";
			$content .=  "<tr>";
			$content .=  "<td>"; 
			$content .=   $cgi->checkbox_group(-name=>'selector',
				-values=>["$id"],
				#-values=>["@$ids"],
				-labels=>\%l);
			$content .=  "<td>" . "$id";
			#$content .=  "<td>" . `$id"`;
	}
	$content .=  "</table>\n";
	$content .= $self->end_form;
	return $content;
}
1;

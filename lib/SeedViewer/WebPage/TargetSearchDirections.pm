package SeedViewer::WebPage::TargetSearchDirections;

#use strict;
#use warnings;
use URI::Escape;
use base qw( WebPage );

use FIG;
use DBMaster;
use FigKernelPackages::Observation qw(get_objects);
my $fig =  new FIG;


1;

sub init {
  my $self = shift;

  # set title
  $self->title('Target Search Directions');

  # register components

}

sub output {
  my ($self) = @_;
  my $cgi = $self->application->cgi;
  my $state;

  foreach my $key ($cgi->param) {
      $state->{$key} = $cgi->param($key);
  }

  my $content = "";

  my $fig = new FIG;
  my $application = $self->application;
  $content .= "<h3>Description</h3>";
  $content .= "<p>This tool performs multi-parameter searches on the SEED/SPROUT/NMPDR database.</p>";
  $content .= "<h3>Tips</h3>";
  $content .= "<p>1. Faster, more successful searches will likely include at least one parameter that will reduce the search space such as 'EC Number or Function','Subsystem', 'Organism Name', 'Taxon ID', 'Lineage', 'PFAM ID', 'PFAM Name', or any of the ID parameters with AND assigned as the logical operator.</p>";
  $content .= "<p>2. The order of the parameters selected does not matter. The query is rearranged automatically for optimized performance.</p>";
  $content .= "<p>3. All proteins returned by the search must match all parameters assigned the logical AND operator, at least one of the parameters assigned a logical OR operator, and none of the parameters assigned the logical NOT operator.</p>";
  $content .= "<p>4. If a single parameter is assigned OR as the logical operator, it is the equivalent of an AND.</p>";
  $content .= "<p>5. Including multiple OR operators can significantly increase search time.</p>";
  $content .= "<p>6. The NOT logical operator should be used in conjunction with parameters assigned AND/OR logical operators.</p>";
  $content .= "<p>7. If more than 10,000 hits are found, the search will need to be resubmitted with a refined set of parameters.</p>";
  $content .= "<p>8. The following cellular locations apply only to gram negative bacteria: Periplasmic, OuterMembrane.</p>";
  $content .= "<p>9. The following cellular locations apply only to gram positive bacteria: CellWall, CytoplasmicMembrane.</p>";
  $content .= "<p>10. Prefix and/or append your 'EC Number or Function' parameter with a * as a wildcard. Otherwise, only exact matches will be returned.</p>";
  return $content;
}

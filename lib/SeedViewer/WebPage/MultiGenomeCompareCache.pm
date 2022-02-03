package SeedViewer::WebPage::MultiGenomeCompareCache;

use base qw( WebPage );

use FIG_Config;

use strict;
use warnings;

1;

sub init {
 my ($self) = @_;

  $self->title('Multi-Genome Comparison Data Cache');

}

sub output {
  my ($self) = @_;
  
  my $application = $self->application;
  my $cgi = $application->cgi;

  my $content = "<h2>Multi-Genome Comparison Cache</h2>";

  my $cache_dir = $self->cache_dir;
  opendir(my $dh, $cache_dir) || die "can't opendir $cache_dir: $!";
  my @subdirs = grep { /^\d+\.\d+$/ && -d "$cache_dir/$_" } readdir($dh);
  closedir $dh;
  @subdirs = sort @subdirs;

  if ($cgi->param('delgenome')) {
    my $gen = $cgi->param('delgenome');
    `rm $cache_dir/$gen/Requests/*`;
    `rmdir $cache_dir/$gen/Requests`;
    `rm $cache_dir/$gen/*`;
    `rmdir $cache_dir/$gen`;
    foreach my $subdir (@subdirs) {
      `rm $cache_dir/$subdir/Requests/$gen`;
      `rm $cache_dir/$subdir/$gen`;
    }
    $application->add_message('info', "computations for genome $gen removed from cache");
  }

  opendir(my $dh, $cache_dir) || die "can't opendir $cache_dir: $!";
  @subdirs = grep { /^\d+\.\d+$/ && -d "$cache_dir/$_" } readdir($dh);
  closedir $dh;
  @subdirs = sort @subdirs;

  $content .= "cached genomes:<br>";
  foreach my $subdir (@subdirs) {
    $content .= $self->start_form()."<input type='hidden' name='delgenome' value='$subdir'>$subdir&nbsp;&nbsp;<input type='submit' value='delete from cache'><br>".$self->end_form();
  }

 return $content;
}

sub cache_dir {
  return $FIG_Config::GenomeComparisonCache ? $FIG_Config::GenomeComparisonCache : $FIG_Config::temp."/GenomeComparisonCache";
}

sub required_rights {
  return [ [ 'edit', 'genome', '*' ] ];
}

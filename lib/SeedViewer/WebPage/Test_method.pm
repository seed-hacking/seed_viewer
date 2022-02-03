package SeedViewer::WebPage::Test_method;

use strict;
use warnings;

use base qw( WebPage );

use Data::Dumper;
use FIG;
use HTML;
#use GenomeDrawer;
use Observation qw(get_objects);

1;

sub output {	
    my ($self) = @_;
    my $content;
    my $cgi = $self->application->cgi;
    my $state;
    my $fig = $self->application->data_handle('FIG');

    foreach my $key ($cgi->param) {
	$state->{$key} = $cgi->param($key);
    }

    if(defined($cgi->param('given_peg'))){
	my $fid = $cgi->param('given_peg');

	my $array=Observation->get_objects($fid);

        my $window_size = $fig->translation_length($fid);
	my $gd = $self->application->component('GD1');
	$gd->width(800);
	$gd->legend_width(100);
	$gd->window_size($window_size+1);
	$gd->line_height(20);

	foreach my $thing (@$array){
	    if($thing->class !~/(IDENTICAL|PCH)/){
		my ($gd) = $thing->display($gd);
	    }
	}  
	
	$gd->show_legend(1);
	$gd->display_titles(1);
	$content .= $gd->output;

	#pass in 'diverse' for functional coupling and 'close' for compare genomes view 
	my $context_array=Observation->get_objects($fid,"close");
	my $gd_context = $self->application->component('Context');
	$gd_context->width(800);
	$gd_context->legend_width(100);
	$gd_context->window_size(16000);
	$gd_context->line_height(20);
	
	foreach my $thing (@$context_array){
	    my ($gd_context) = $thing->display($gd_context);
	}  
	
	$gd_context->show_legend(1);
	$gd_context->display_titles(1);
	$content .= $gd_context->output;


	##################


	my $table_component = $self->application->component('IdenticalTable');
	$table_component->columns ([ { 'name' => 'Database', 'filter' => 1 },
				     { 'name' => 'ID' },
				     { 'name' => 'Organism' },
				     { 'name' => 'Assignment' }
				     ]);
	
	$table_component->show_top_browse(1);
	$table_component->show_bottom_browse(1);
	$table_component->items_per_page(50);
	$table_component->show_select_items_per_page(1);

	foreach my $thing (@$array){
	    if($thing->class eq "IDENTICAL"){
		my $table_data = $thing->display_table();
		if($table_data !~ /This PEG does not have/)
		{
		    $table_component->data($table_data);
		    $content .= $table_component->output();
		}
		else
		{
		    $content .= $table_data;
		}
		$content .= "<br>";
	    }
	}


	# start the printing for the functional coupling
	my $fctable_component = $self->application->component('FCTable');

	$fctable_component->columns ([ { 'name' => 'Score', 'filter' => 1},
				     { 'name' => 'ID' },
				     { 'name' => 'Function' }
				     ]);

	$fctable_component->show_top_browse(1);
	$fctable_component->show_bottom_browse(1);
	$fctable_component->items_per_page(50);
	$fctable_component->show_select_items_per_page(1);

	foreach my $thing (@$array){
	    if($thing->class eq "PCH"){
		my $table_data2 = $thing->display_table();
		if($table_data2 !~ /This PEG does not have/)
		{
		    $fctable_component->data($table_data2);
		    $content .= $fctable_component->output();
		}
		else
		{
		    $content .= $table_data2;
		}
		$content .= "<br>";
	    }
	}


	#########################

        # start the printing for the similarities
        my $simtable_component = $self->application->component('SimTable');

        $simtable_component->columns ([ { 'name' => 'Database', 'filter' => 1},
					{ 'name' => 'Similar Sequence' },
					{ 'name' => 'E-value', 'filter' => 1 },
					{ 'name' => 'Percent Identity' },
					{ 'name' => 'Region in Sim Seq' },
					{ 'name' => 'Region in peg' },
					{ 'name' => 'In Subsystem' },
					{ 'name' => 'Evidence Code' },
					{ 'name' => 'Organism', 'filter' => 1 },
					{ 'name' => 'Function', 'filter' => 1 },
					{ 'name' => 'Aliases' }
				       ]);

        $simtable_component->show_top_browse(1);
        $simtable_component->show_bottom_browse(1);
        $simtable_component->items_per_page(50);
        $simtable_component->show_select_items_per_page(1);

        my $table_data3 = Observation::Sims->display_table($array);
        if ($table_data3 !~ /This PEG does not have/)
        {
            $simtable_component->data($table_data3);
            $content .= $simtable_component->output();
        }
        else
        {
            $content .= $table_data3;
        }
	$content .= "<br>";
        #########################

  }

  else{
      my $id = "first";
      $content .= "<h4>Enter PEG</h4>";
      $content .= $self->start_form($id,$state);
      $content .= $cgi->textarea(-name=>"given_peg", -rows=>1, -columns=>20);
      $content .= "<input type='submit' value='Select'><br />";
      $content .= $self->end_form;
  }
  
  return $content;

}

sub init {
    my ($self) = @_;
    $self->application->register_component('FilterSelect', 'OrganismSelect');
    $self->application->register_component('FilterSelect', 'RegulatorSelect');
    $self->application->register_component('FilterSelect', 'SubsystemSelect');
    $self->application->register_component('GenomeDrawer', 'GD1');
    $self->application->register_component('GenomeDrawer', 'Context');
    $self->application->register_component('Table', 'DomainTable');
    $self->application->register_component('Table', 'IdenticalTable');
    $self->application->register_component('Table', 'FCTable');
    $self->application->register_component('Table', 'SimTable');
}


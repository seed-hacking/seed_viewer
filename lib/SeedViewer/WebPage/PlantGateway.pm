package SeedViewer::WebPage::PlantGateway;

use base qw( WebPage );

1;

use strict;
use warnings;
use Tracer;
use URI::Escape;
use WebConfig;
use WebComponent::WebGD;
use WebColors;
use WebLayout;
use Data::Dumper;
=pod

=head1 NAME

Plant-specific gateway for the public SEED

=head1 DESCRIPTION

Plant-specific gateway for the public SEED

=head1 METHODS

=over 4

=item * B<init> ()

Called when the web page is instanciated.

=cut

sub init {
    my ($self) = @_;
    $self->title('PubSEED Plants Gateway');
    $self->application->register_component('TabView', 'main');
	$self->application->register_component('Table', 'sstbl');
    $self->application->register_component('Table', 'gntbl');
    return 1;
}

=item * B<output> ()

=cut

sub output {
    my ($self) = @_;
    my $cgi = $self->application()->cgi();
    #Tweaking the layout
#		my $layout = WebLayout->new(TMPL_PATH . '/SeedViewer.tmpl');
#		$layout->add_css("$FIG_Config::cgi_url/Html/seedviewer.css");
#		$layout->add_css("$FIG_Config::cgi_url/Html/commonviewer.css");
#		$layout->add_css("$FIG_Config::cgi_url/Html/web_app_default.css");
#		$self->application()->{layout}= $layout;
#		my $menu = WebMenu->new();
#		$menu->add_category('&raquo;SEED Resources', '?page=PlantGateway');
#		$menu->add_entry('&raquo;SEED Resources', 'What is the SEED', 'http://www.theseed.org/wiki/index.php/Home_of_the_SEED');
#		$menu->add_entry('&raquo;SEED Resources', 'Model SEED Home', '?page=ModelView');
#		$menu->add_entry('&raquo;SEED Resources', 'SeedViewer Home', '?page=Home');
#		$menu->add_entry('&raquo;SEED Resources', 'RAST Home', 'http://rast.nmpdr.org/rast.cgi');
#		$menu->add_category('&raquo;Account management', 'http://www.theseed.org', 'Account management', undef, 98);
#		$menu->add_entry('&raquo;Account management', 'Create new account', '?page=Register');
#		$menu->add_entry('&raquo;Account management', 'I forgot my Password', '?page=RequestNewPassword');
#		$self->application()->{menu}= $menu;
    #Adding the PubSEED search box
    my $html = 
'<script>function initialize_all () {
}</script><div style="text-align: center">
<h2>Welcome to the Plant Gateway for the PubSEED.</h2>
<p>Type a search string:</p>
<form name="search" method="POST">
<input type="hidden" name="act" value="do_search">
<input type="hidden" name="page" value="Find">
<input type="text" size="100" name="pattern" value="">
<br>
<input type="submit" name="submit" value="Search">
</form>
</div><br>';
	my $tabs = $self->application()->component('main');
    $tabs->add_tab( '<b>Plant Subsystems</b>',$self->subsystemTableTab());
    $tabs->add_tab( '<b>Plant Genomes</b>',$self->genomeTableTab());
    $tabs->width('100%');
	$html .= $tabs->output();
    return $html;
}

sub subsystemTableTab {
	my ($self) = @_;
	my $cgi = $self->application()->cgi();
	my $sstbl = $self->application()->component('sstbl');
	my $ColumnArray = [
    	{ name => 'Primary Class', filter => 1, sortable => 1, operand => $cgi->param( 'filterPrimaryClass' ) || "" },
    	{ name => 'Secondary Class', filter => 1, sortable => 1, operand => $cgi->param( 'filterSecondaryClass' ) || "" },
    	{ name => 'Subsystem', filter => 1, sortable => 1, operand => $cgi->param( 'filterSubsystem' ) || ""},
    	{ name => 'Subsystem Diagram', filter => 0, sortable => 0, operand => $cgi->param( 'filterSubsystemDiagram' ) || ""},
    	{ name => 'Subsystem Table Data', filter => 0, sortable => 0, operand => $cgi->param( 'filterSubsystemTableData' ) || ""},
    ];
    my $data = [];
    my $ssData = [
    	{id => 1,name => "Riboflavin, FMN and FAD biosynthesis in plants",classOne => "Cofactors, Vitamins, Prosthetic Groups, Pigments",classTwo => "Riboflavin, FMN, FAD"},
    	{id => 2,name => "Thiamin biosynthesis in plants",classOne => "Cofactors, Vitamins, Prosthetic Groups, Pigments",classTwo => "Thiamin"},
    	{id => 3,name => "Pyridoxine (vitamin B6) biosynthesis in plants",classOne => "Cofactors, Vitamins, Prosthetic Groups, Pigments",classTwo => "Pyridoxine"},
    	{id => 4,name => "Niacin, NAD and NADP biosynthesis in plants",classOne => "Cofactors, Vitamins, Prosthetic Groups, Pigments",classTwo => "NAD and NADP"},
    	{id => 5,name => "Folate biosynthesis in plants",classOne => "Cofactors, Vitamins, Prosthetic Groups, Pigments",classTwo => "Folate and pterines"},
    	{id => 6,name => "Biotin biosynthesis in plants",classOne => "Cofactors, Vitamins, Prosthetic Groups, Pigments",classTwo => "Biotin"},
    	{id => 7,name => "Pantothenate and CoA biosynthesis in plants",classOne => "Cofactors, Vitamins, Prosthetic Groups, Pigments",classTwo => "Coenzyme A"},
    ];
    my $diagramLinks = {
		1 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Riboflavin%2C_FMN_and_FAD_biosynthesis_in_plants",
		2 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Thiamin_biosynthesis_in_plants",
		3 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Pyridoxine_(vitamin_B6)_biosynthesis_in_plants",
		4 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Niacin%2C_NAD_and_NADP_biosynthesis_in_plants",
		5 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Folate_biosynthesis_in_plants",
		6 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Biotin_biosynthesis_in_plants",
		7 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Pantothenate_and_CoA_biosynthesis_in_plants",
	};
	my $ssLinks = {
		1 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowSubsystem&subsystem=Riboflavin%2C_FMN_and_FAD_biosynthesis_in_plants",
		2 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowSubsystem&subsystem=Thiamin_biosynthesis_in_plants",
		3 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowSubsystem&subsystem=Pyridoxine_(vitamin_B6)_biosynthesis_in_plants",
		4 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowSubsystem&subsystem=Niacin%2C_NAD_and_NADP_biosynthesis_in_plants",
		5 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowSubsystem&subsystem=Folate_biosynthesis_in_plants",
		6 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowSubsystem&subsystem=Biotin_biosynthesis_in_plants",
		7 => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowSubsystem&subsystem=Pantothenate_and_CoA_biosynthesis_in_plants",
	};
	for (my $i=0; $i < @{$ssData}; $i++) {
		my $row = [
			$ssData->[$i]->{classOne},
			$ssData->[$i]->{classTwo},
			'<a href="'.$ssLinks->{$ssData->[$i]->{id}}.'">'.$ssData->[$i]->{name}.'</a>',
			'<a href="'.$diagramLinks->{$ssData->[$i]->{id}}.'">SEED Diagram</a>',
			'<a href="http://bioseed.mcs.anl.gov/~chenry/plantSS/Table S'.$ssData->[$i]->{id}.'.xls">Excel table</a><br><a href="http://bioseed.mcs.anl.gov/~chenry/plantSS/Table S'.$ssData->[$i]->{id}.'.html">HTML table</a>'
		];
		push(@{$data},$row);
	}
    $sstbl->width("100%");
    $sstbl->columns($ColumnArray);
    $sstbl->items_per_page(10);
    $sstbl->show_select_items_per_page(0);
    $sstbl->show_top_browse(0);
    $sstbl->show_bottom_browse(0);
    $sstbl->data($data);
    return '<p>Compartmentation information in the pathway diagrams is systematically curated only for Arabidopsis. For other plants, compartmentation shown in pathway diagrams and tables is merely a projection. In some cases projection generates multiple candidate proteins for a functional role in a given compartment.</p><br><p>Only curated B Vitamin subsystems are shown, but this list will expand to include all of primary metabolism over time.</p><br>'.$sstbl->output();
}

sub genomeTableTab {
	my ($self) = @_;
   	my $cgi = $self->application()->cgi();
    my $gntbl = $self->application()->component('gntbl');
    my $ColumnArray = [
    	{ name => 'Genome ID', filter => 1, sortable => 1, operand => $cgi->param( 'filterName' ) || "" },
    	{ name => 'Plant name', filter => 1, sortable => 1, operand => $cgi->param( 'filterName' ) || ""}
    ];
    my $data = [
    	['<a href="http://pubseed.theseed.org/seedviewer.cgi?page=Organism&organism=3702.1">3702.1</a>',"Arabidopsis thaliana"],
    	['<a href="http://pubseed.theseed.org/seedviewer.cgi?page=Organism&organism=381124.5">381124.5</a>',"Zea mays"],    	
    ];
    $gntbl->width("100%");
    $gntbl->columns($ColumnArray);
    $gntbl->items_per_page(10);
    $gntbl->show_select_items_per_page(0);
    $gntbl->show_top_browse(0);
    $gntbl->show_bottom_browse(0);
    $gntbl->data($data);
    return "<p>There are many plant genomes in the PubSEED, including many different versions for each plant species. Here we show only the most well curated and annotated plant genomes and species.</p><br>".$gntbl->output();
}

use strict;
use warnings;

use DBMaster;
use WebApplication;
use WebMenu;
use WebLayout;

eval {
    &main;
};

if ($@)
{
    my $cgi = new CGI();

    print $cgi->header();
    print $cgi->start_html();
    
    # print out the error
    print '<pre>'.$@.'</pre>';

    print $cgi->end_html();

}

sub main {

    # initialize cgi
    my $cgi = new CGI();

    # initialize db-master
    #my $dbmaster = DBMaster->new(-database=>'WebAppBackend');
    my $dbmaster = DBMaster->new(-database=>'WebAppBackend',-host=>'bioseed.mcs.anl.gov',-user=>'rast');	

    # initialize layout
    my $layout = WebLayout->new('./Html/SeedViewer.tmpl');
    $layout->add_css('./Html/seedviewer.css');

    # build menu
    my $menu = WebMenu->new();
    $menu->add_category('&raquo;Navigate', '?page=Home');
    $menu->add_entry('&raquo;Navigate', 'Search', '?page=Home');
    $menu->add_entry('&raquo;Navigate', 'Functional Roles', '?page=FunctionalRole');
    $menu->add_entry('&raquo;Navigate', 'Subsystems', '?page=Subsystem');
    $menu->add_entry('&raquo;Navigate', 'Organisms', '?page=OrganismSelect');
    $menu->add_entry('&raquo;Navigate', 'Annotations', '?page=Annotation');
    $menu->add_category('&raquo;Help', 'http://biofiler.mcs.anl.gov', 'help', undef, 98);
    $menu->add_entry('&raquo;Help', 'What is the SEED', 'http://www.theseed.org');
    $menu->add_entry('&raquo;Help', 'HowTo use the SEED Viewer', 'http://www.theseed.org');
    $menu->add_entry('&raquo;Help', 'Submitting Data to SEED', 'http://www.theseed.org');
    $menu->add_entry('&raquo;Help', 'Contact', 'http://www.theseed.org');
    $menu->add_entry('&raquo;Help', 'Register', '?page=Register');
    $menu->add_category('&raquo;Logout', '?page=Home&action=perform_logout', undef, ['login'], 99);
    $menu->add_category('&raquo;Tips', '?page=TargetSearchDirections');	

    # initialize application
    my $WebApp = WebApplication->new( { id => 'SeedViewer',
					dbmaster => $dbmaster,
					menu     => $menu,
					layout   => $layout,
					default  => 'TargetSearch',
				      } );

    #my $search_master = DBMaster->new(-database => 'SeedDB');
    #my $search_component = $WebApp->register_component('Search', 'MenuSearch');
    #$search_component->db($search_master);
    #$search_component->add_category('Functional Role', 'FunctionalRole');
    #$search_component->add_category('Subsystem');
    #$search_component->add_category('Organism');
    #$search_component->add_category('Annotation', undef, 'Function');

    # run application
    $WebApp->run();

}

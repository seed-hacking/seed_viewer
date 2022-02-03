use strict;
use warnings;
no warnings 'once';

use WebApplication;
use WebMenu;
use WebLayout;
use WebConfig;

use FIG_Config;

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


    my $layout = WebLayout->new(TMPL_PATH.'SeedViewer-MG.tmpl');
    $layout->add_css("$FIG_Config::cgi_url/Html/default.css");
    $layout->add_css("$FIG_Config::cgi_url/Html/seedviewer.css");
    $layout->add_css("$FIG_Config::cgi_url/Html/commonviewer.css");

    # build menu
    my $menu = WebMenu->new();
    $menu->add_category('&raquo;Navigate', '?');
    $menu->add_entry('&raquo;Navigate', 'MG-RAST Home', '?');
    $menu->add_entry('&raquo;Navigate', '<img src="'.$FIG_Config::cgi_url.'/Html/nmpdr_icon_small.png">&nbsp;RAST', 'http://rast.nmpdr.org/'); 
    $menu->add_entry('&raquo;Navigate', '<img src="'.$FIG_Config::cgi_url.'/Html/nmpdr_icon_small.png">&nbsp;NMPDR', 'http://www.nmpdr.org/'); 
    
    # help
    $menu->add_category('&raquo;Help', 'http://www.theseed.org', 'help', undef, 98);
    $menu->add_entry('&raquo;Help', 'What is the SEED', 'http://www.theseed.org/wiki/Home_of_the_SEED');
    $menu->add_entry('&raquo;Help', 'HowTo use the SEED Viewer', 'http://www.theseed.org/wiki/SEED_Viewer_Tutorial');
    $menu->add_entry('&raquo;Help', 'Submitting Data to MG-RAST', 'http://www.theseed.org/wiki/MG_RAST_Tutorial');
    $menu->add_entry('&raquo;Help', 'Contact', 'http://www.theseed.org/wiki/Contact');
    $menu->add_entry('&raquo;Help', 'Register', '?page=Register');
    $menu->add_entry('&raquo;Help', 'I forgot my Password', '?page=RequestNewPassword');
    

    # initialize application
    my $WebApp = WebApplication->new( { id => 'SeedViewer',
					menu     => $menu,
					layout   => $layout,
					default  => 'MetagenomeSelect',
				      } );
    $WebApp->page_title_prefix('MG-RAST - ');
    $WebApp->show_login_user_info(1);

    # run application
    $WebApp->run();

}

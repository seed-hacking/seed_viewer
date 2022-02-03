package SeedViewer::MyAppRights;

1;

use strict;
use warnings;

sub rights {
	return [ [ 'view','user','*' ], [ 'add','user','*' ], [ 'delete','user','*' ], [ 'edit','user','*' ], [ 'view','scope','*' ], [ 'add','scope','*' ], [ 'delete','scope','*' ], [ 'edit','scope','*' ], [ 'login','*','*' ], [ 'view','registration_mail','*' ], [ 'view','group_request_mail','*' ], [ 'annotate_starts','genome','*' ], [ 'view','genome','*' ], [ 'edit','problem_list','*' ], [ 'view','genome','*' ], [ 'edit','problem_list','*' ], ];
}

package SeedAPI;

use POSIX;
use Dancer2;
use FIG;
use GenomeLists;
use strict;
use Data::Dumper;

set 'serializer' => 'JSON';

get '/genome_sets' => sub {
    my @lists = GenomeLists->getListsForUser();
    return \@lists;
};

get '/genome_set/:set' => sub {
    my $set = route_parameters->get('set');
    my $list = GenomeLists::load($set);
    if (!$list)
    {
	die "Set does not exist";
    }
    return $list->{genomes};
};

get '/subsystems' => sub {
    my $fig = new FIG;
    my @ss = $fig->all_subsystems;
    return \@ss;
};

get '/subsystem/:id' => sub {
    my $id = route_parameters->get('id');
    my $fig = FIG->new;
    my $ss = $fig->get_subsystem($id);

    my @wl = $fig->get_attributes("Subsystem:$id", "SUBSYSTEM_WEBLINKS");
    my $wlpairs = [ map { [$_->[2], $_->[3]] } @wl];
    my $dat = {
	name => $ss->get_name(),
	author => $ss->get_curator(),
	version => $ss->get_version(),
	last_modified => strftime("%Y-%m-%dT%H:%M:%S", localtime $ss->{last_updated}),
	literature => $ss->get_literature(),
	weblinks => $wlpairs,
	description => $ss->get_description(),
	notes => $ss->get_notes(),
	variants => $ss->get_variants(),
	classification => $ss->get_classification(),
    };
    return $dat;
};


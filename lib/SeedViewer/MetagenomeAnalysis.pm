package SeedViewer::MetagenomeAnalysis;

# $Id: MetagenomeAnalysis.pm,v 1.22 2008-08-25 22:16:45 arodri7 Exp $

use strict;
use warnings;

use FIG_Config;
use DBI;
use Data::Dumper;

1;

use constant QUERY_DEFAULTS => 
  { 1 => { evalue => '1e-05', align_len => 50 }, # RDP
    2 => { evalue => '0.01' }, # SEED
    3 => { evalue => '1e-05', align_len => 50 }, # Greengenes
    4 => { evalue => '1e-05', align_len => 50 }, # LSU
    5 => { evalue => '1e-05', align_len => 50 }, # SSU
    6 => { evalue => '0.01' }, # Subsystem
  };
    
sub new {
  my ($class, $job) = @_;
  
  # check job
  unless (ref $job and $job->isa('RAST::Job') and $job->metagenome) {
    return undef;
  }

  # connect to database
  my $dbh;
  eval {

    my $dbms     = $FIG_Config::mgrast_dbms;
    my $host     = $FIG_Config::mgrast_dbhost;
    my $database = $FIG_Config::mgrast_db;
    my $user     = $FIG_Config::mgrast_dbuser;
    my $password = '';

    if ($dbms eq 'Pg')
    {
	$dbh = DBI->connect("DBI:Pg:dbname=$database;host=$host", $user, $password, 
			{ RaiseError => 1, AutoCommit => 0, PrintError => 0 }) ||
			    die "database connect error.";
    }
    elsif ($dbms eq 'mysql' or $dbms eq '') # Default to mysql
    {
	$dbh = DBI->connect("DBI:mysql:database=$database;host=$host", $user, $password, 
			{ RaiseError => 1, AutoCommit => 0, PrintError => 0 }) ||
			    die "database connect error.";
    }
    else
    {
	die "MetagenomeAnalysis: unknown dbms '$dbms'";
    }

  };
  if ($@) {
    warn "Unable to connect to metagenomics database: $@\n";
    return undef;
  }

  # create object
  my $self = { job => $job,
	       dbh => $dbh,
	       key2taxa => undef,
	       query => {},
		   dbid_cache => {},
	     };
  bless $self, $class;

  # load key2taxa mapping
  $self->get_key2taxa_mapping();
  
  return $self;

}

sub job {
  return $_[0]->{job};
}


sub dbh {
  return $_[0]->{dbh};
}


sub dbtable {
  unless (defined $_[0]->{dbtable}) {
    $_[0]->{dbtable} = 'tax_sim_'.$_[0]->job->id; 
  }
  return $_[0]->{dbtable};
}

sub dbtable_best_psc {
  unless (defined $_[0]->{dbtable}) {
    $_[0]->{dbtable} = 'tax_sim_best_by_psc_'.$_[0]->job->id; 
  }
  return $_[0]->{dbtable};
}

sub dbtable_best_iden {
  unless (defined $_[0]->{dbtable}) {
    $_[0]->{dbtable} = 'tax_sim_best_by_iden_'.$_[0]->job->id; 
  }
  return $_[0]->{dbtable};
}

sub get_key2taxa_mapping {

  unless (defined($_[0]->{key2taxa})) {
    my $sth  = $_[0]->dbh->prepare("select dbkey, str from tax_item");
    $sth->execute;
    $_[0]->{key2taxa} = $sth->fetchall_hashref('dbkey');
  }

  return $_[0]->{key2taxa};

}


sub key2taxa {    
  if(defined $_[1]) {
    my $t = $_[0]->{key2taxa}->{$_[1]}->{str};
    $t =~ s/\t+$//;
    return $t;
  }
  return '';
}


sub split_taxstr {
  my @r = split(':', $_[1]);
  return \@r;
}

sub join_taxstr {
    # do I really want an ending colon?
  return join(':', @{$_[1]}).':';
}


sub evalue2log {
  return 10 * (log($_[1]) / log(10));
}

sub log2evalue {
  return 10**($_[1]/10);
}


#
# Determine the correct dbid for this job. Use sims.database_list
# to find the version that the analysis was run with.
#
sub get_dataset_id {
    my($self, $dataset) = @_;

    my $id = $self->{dbid_cache}->{$dataset};
    return $id if defined($id);

    my($dbname, $type) = split(/:/, $dataset);

    my $dbs = $self->job->metaxml->get_metadata('sims.database_list');

    my @this = grep { $_->{name} eq $dbname } @$dbs;
    if (@this)
    {
	my $vers = $this[0]->{version};

	#
	# Now we can find the dbid ni the database.
	#
	my $res = $self->dbh->selectcol_arrayref(qq(SELECT dbid
						    FROM seq_db
						    WHERE name = ? AND version = ?
						    	AND tax_db_name = ?), undef,
						 $dbname, $vers, $type);
	if (@$res)
	{
	    #print STDERR "Found @$res for $dbname $type $vers\n";
	    $id = $res->[0];
	    $self->{dbid_cache}->{$dataset} = $id;
	    return $id;
	}
	#print STDERR "Did not find anything for dataset='$dataset' '$dbname' '$type' '$vers'\n";
    }
    #print STDERR "did not find a vers for dataset='$dataset' $dbname $type\n" . Dumper($dbs);
}

#******************************************************************************
#* MANAGING QUERY CRITERIA
#******************************************************************************

=pod

=over 4

=item * B<query_evalue> (I<evalue>)

Set/get the expectation value which is currently used to query the database. 
Parameter I<evalue> has to be a float or in '1e-5'-like format or undef.

=cut 

sub query_evalue {
  if(scalar(@_)>1) {
    $_[0]->{query}->{evalue} = $_[1];
  }
  return $_[0]->{query}->{evalue};
}


=pod

=item * B<query_bitscore> (I<score>)

Set/get the bitscore which is currently used to query the database. 
Parameter I<score> has to be a float or undef.

=cut 

sub query_bitscore {
  if(scalar(@_)>1) {
    $_[0]->{query}->{bitscore} = $_[1];
  }
  return $_[0]->{query}->{bitscore};
}


=pod

=item * B<query_align_len> (I<length>)

Set/get the minimum alignment which is currently used to query the database. 
Parameter I<length> has to be a positive integer or undef.

=cut 

sub query_align_len {
  if(scalar(@_)>1) {
    if($_[1] and $_[1]<0) {
      die "Alignment length has to be positive: ".$_[1];
    }
    $_[0]->{query}->{align_len} = $_[1];
  }
  return $_[0]->{query}->{align_len};
}


=pod

=item * B<query_identity> (I<percent>)

Set/get the minimum percent identity which is currently used to query the database. 
Parameter I<percent> has to be a number in 0..100 or undef.

=cut 

sub query_identity {
  if(scalar(@_)>1) {
    if($_[1] and ($_[1]<0 or $_[1]>100)) {
      die "Identity has to be between 0 and 100: ".$_[1];
    }
    $_[0]->{query}->{identity} = $_[1];
  }
  return $_[0]->{query}->{identity};
}


=pod

=item * B<query_load_from_cgi> (I<cgi>, [I<dataset>])

Sets all query parameter to the values provided in the CGI query object I<cgi>.
This method recognises 'evalue', 'pvalue' (bitscore), 'alignment_length' and
'percent_identity' as query criteria. Any missing param will be set to undef.
If the optional parameter I<dataset> is set to one of the accepted datasets
(db types), the method will additionally load the defaults for this type into
the CGI object.


=cut 

sub query_load_from_cgi {
  my ($self, $cgi, $dataset) = @_;
  
  unless(ref $cgi and $cgi->isa("CGI")) {
    die "Query load from cgi requires a valid CGI object.";
  }

  # load the defaults if necessary
  if($dataset and $self->get_dataset_id($dataset)) {

    my $d = $self->get_dataset_id($dataset);
    
    my @v = qw( evalue bitscore align_len identity );
    foreach my $v (@v) {
      if(!defined($cgi->param($v)) and QUERY_DEFAULTS->{$d}->{$v}) {
	$cgi->param($v, QUERY_DEFAULTS->{$d}->{$v});
      }
    }
  }
    
  # set the query params
  my $evalue = $cgi->param('evalue') || '';
  $self->query_evalue($evalue);

  my $bitscore = $cgi->param('bitscore') || '';
  $self->query_bitscore($bitscore);
  
  my $align_len = $cgi->param('align_len') || '';
  $self->query_align_len($align_len);
  
  my $identity = $cgi->param('identity') || '';
  $self->query_identity($identity);

  return $self;

}  
  

=pod

=item * B<get_where_clause> ()

Returns for the current query parameters the where clause as applicable to the 
tax_sim_XYZ table SQL queries. The method will take care of all conversions to
eg the logscore evalues.

=cut 

sub get_where_clause {
  my ($self) = @_;
  
  my @params;
  
  if($self->{query}->{evalue}) {
    push @params, "logpsc<=".$self->evalue2log($self->{query}->{evalue});
  }

  if($self->{query}->{bitscore}) {
    push @params, "bsc>=".$self->{query}->{bitscore};
  }
  
  if($self->{query}->{align_len}) {
    push @params, "ali_ln>=".$self->{query}->{align_len};
  }

  if($self->{query}->{identity}) {
    push @params, "iden>=".$self->{query}->{identity};
  }

  return join(' and ', @params);

}
  


#******************************************************************************
#* OTHER
#******************************************************************************


=pod

=item * B<get_sequence> (I<sequence_id>)

Retrieve the sequence I<sequence_id> from the metagenome job directory.

=cut 

sub get_sequence {
  my ($self, $id) = @_;
  
  my $sequence_file = $self->job->org_dir.'/contigs';

  my $sequence = '';
  open(FASTA, "<$sequence_file") or die "Unable to read metagenome sequences: $!";
  while(<FASTA>) {
    next unless /^\>$id/;

    while(<FASTA>) {
      last if /^>/;
      chomp;
      $sequence .= $_;
    }
  }
  
  return $sequence;

}

=pod

=item * B<get_sequences_fasta> (I<sequence_ids>)

Retrieve the sequences for a given list of I<sequence_ids> from the metagenome job directory in fasta format.

=cut 

sub get_sequences_fasta {
  my ($self, $ids) = @_;
  
  # get the path to the sequence file
  my $sequence_file = $self->job->org_dir.'/contigs';

  # hash the ids
  my %idh = map { $_ => 1 } @$ids;

  # store the result
  my $sequence = '';

  # iterate over the sequence file
  open(FASTA, "<$sequence_file") or die "Unable to read metagenome sequences: $!";
  while(<FASTA>) {

    # look only at id lines
    next unless /^\>/;

    # get the id
    my ($id) = /^\>(.+)/; 
    chomp($id);

    # find the id in the requested id hash
    next unless exists ($idh{$id});

    # id was found, delete it from the hash
    delete $idh{$id};
    
    # print the header line
    $sequence .= $_;

    # print all the following lines to the result
    while(<FASTA>) {
      last if /^>/;
      $sequence .= $_;
    }

    last unless (scalar(keys(%idh)));
  }
  
  return $sequence;

}

=pod

=item * B<get_hits_count> (I<dataset_name>)

Given a dataset name (db_id), this method returns
the total number of sequences that contain a hit. 

=cut 

sub get_hits_count {
  my ($self, $dataset) = @_;
 
  my $table = $self->dbtable_best_psc; 
  my $dbid  = $self->get_dataset_id($dataset);
  my $where = $self->get_where_clause();
  $where = ($where) ? "and $where" : '';

  my $sth = $self->dbh->prepare("select count(distinct id1) from  $table where dbid=$dbid $where");
  $sth->execute;
  my ($result) = $sth->fetchrow_array;

  return $result;

}


=pod

=item * B<get_group_counts> (I<dataset_name>, [I<group>, I<filter1>, I<filter2>])

Given a dataset name (db_id), this method returns the total counts for all 
taxonomy groups of a certain depth which are hit. If no group name I<group> 
was given, the method returns counts for tax_group_1.
Optionally, I<group> may be 'tax_group_2' or 'tax_group_3' and in that case
any optional provided filters I<filter1> and I<filter2> will be applied to 
the column 'tax_group_1' and 'tax_group_2' respectively.

=cut

sub get_group_counts {
  my ($self, $dataset, $group, $filter1, $filter2) = @_;

  my $table = $self->dbtable_best_psc; 
  my $dbid  = $self->get_dataset_id($dataset);
  my $where = $self->get_where_clause();
  $where = ($where) ? "and $where" : '';  
  $group = 'tax_group_1' unless($group);
  
  my @filters;
  push @filters, "tax_group_1='$filter1'" if($filter1);
  push @filters, "tax_group_2='$filter2'" if($filter2);
  my $filter = (scalar(@filters)) ? 'and '.join(' and ', @filters) : '';

  print STDERR "select $group as tax, count(*) as num from $table where dbid=$dbid $where $filter group by tax";
  my $sth = $self->dbh->prepare("select $group as tax, count(*) as num from $table where dbid=$dbid $where $filter group by tax");
  $sth->execute;
  my $result = $sth->fetchall_arrayref();

  #print STDERR "get_group_counts: ds=$dataset group=$group filter1=$filter1 filter2=$filter2\n";
  #print STDERR Dumper($result);
  return $result;

}


=pod

=item * B<get_taxa_counts> (I<dataset_name>)

Given a dataset name (db_id), this method returns the total counts for all 
taxonomy strings which are hit. 

=cut

sub get_taxa_counts {
  my ($self, $dataset) = @_;

  my $table = $self->dbtable_best_psc; 
  my $dbid  = $self->get_dataset_id($dataset);
  my $where = $self->get_where_clause();
  $where = ($where) ? "and $where" : '';  
  
  my $sth = $self->dbh->prepare("select tax_str as tax, count(*) from $table where dbid=$dbid $where group by tax");

  $sth->execute;
  my $result = $sth->fetchall_arrayref();

  return $result;

}

sub get_tax2genomeid {
  my ($self, $taxstring) = @_;

  my ($genomeid) = $self->dbh->selectrow_array(qq(SELECT seq_num
                                                FROM rdp_to_tax
                                                WHERE tax_str= ?), undef, $taxstring);

  return $genomeid;
}


=pod

=item * B<get_subsystem_counts> (I<dataset_name>)

Given a dataset name (db_id), this method returns the total counts for all 
subsystems which are hit. 

=cut

sub get_subsystem_counts {
  my ($self, $dataset) = @_;

  my $table = $self->dbtable_best_psc; 
  my $dbid  = $self->get_dataset_id($dataset);
  my $where = $self->get_where_clause();
  $where = ($where) ? "and $where" : '';  
 
  my $sth = $self->dbh->prepare("select tax_group_1, tax_group_2, tax_group_3, tax_str, count(*) as num from $table where dbid=$dbid $where group by tax_group_1, tax_group_2, tax_group_3, tax_str");

  $sth->execute;
  my $result = $sth->fetchall_arrayref();

  return $result;

}


=pod

=item * B<get_sequence_subset> (I<dataset_name>, I<filter>)

Given a dataset name (db_id), this method returns all sequence ids,
the alignment length, the match id and the taxonomy string for all 
sequences which match the criteria and have their tax_str start with
the filter string I<filter>.

=cut

sub get_sequence_subset {
  my ($self, $dataset, $filter) = @_;

  my $table = $self->dbtable_best_psc; 
  my $dbid  = $self->get_dataset_id($dataset);
  my $where = $self->get_where_clause();
  $where = ($where) ? "and $where" : '';  
  
  $filter =~ s/'/''/g;

  my $sth = $self->dbh->prepare("select id1, ali_ln, id2, tax_str, logpsc, bsc, iden, b1, e1, b2, e2 from $table where dbid=$dbid $where and tax_str like '$filter%'");
  $sth->execute;
  my $result = $sth->fetchall_arrayref();

  return $result;

}

=pod

=item * B<get_sequence_subset_genome> (I<genome>)

Given a dataset name (db_id), this method returns all sequence ids,
the alignment length, the match id and the taxonomy string for all 
sequences which match the criteria and have their tax_str start with
the filter string I<filter>.

=cut

sub get_sequence_subset_genome {
  my ($self, $genome) = @_;

  my $table = $self->dbtable_best_psc; 
  my $dbid  = $self->get_dataset_id("SEED:seed_genome_tax");
  my $where = $self->get_where_clause();
  $where = ($where) ? "and $where" : '';  
  
  my ($tax_id) = $self->dbh->selectrow_array(qq(SELECT tax_str
						FROM rdp_to_tax
						WHERE seq_num= ?), undef, $genome);
  
  if($tax_id =~ /(\S+)\s/){
    $tax_id = $1;
  }

  my $sth = $self->dbh->prepare(qq(SELECT id1, ali_ln, id2, tax_str, logpsc, bsc, iden, b1, e1, b2, e2
				   FROM $table
				   WHERE dbid=? $where and tax_str=?));


  $sth->execute($dbid, $tax_id);
  my $result = $sth->fetchall_arrayref();

  return $result;

}

=pod

=item * B<get_recruitment_plot_data> (I<genome>)

Given a genome id (83333.1), this method returns all sequence ids,
the alignment length, the match id and the taxonomy string for all 
sequences which match the criteria and have their tax_str start equal
the genome tax string I<filter>.

=cut

sub get_recruitment_plot_data {
  my ($self, $genome) = @_;

  my $table = $self->dbtable_best_psc; 
  my $dbid  = $self->get_dataset_id("SEED:seed_genome_tax");
  my $where = $self->get_where_clause();
  $where = ($where) ? "and $where" : '';  

  my ($tax_id) = $self->dbh->selectrow_array(qq(SELECT tax_str
						FROM rdp_to_tax
						WHERE seq_num= ?), undef, $genome);
  
  if($tax_id =~ /(\S+)\s/){
    $tax_id = $1;
  }

  my $sth = $self->dbh->prepare(qq(SELECT id1, id2, b2, e2, logpsc
				   FROM $table
				   WHERE dbid=? $where and tax_str=?));


  $sth->execute($dbid, $tax_id);
  my $result = $sth->fetchall_arrayref();

  return $result;

}




=pod

=item * B<get_hits_for_sequence> (I<seq_id>, I<dataset>, I<limit>)

Given a sequence id I<seq_id> (id1) and a dataset name (db_id), this method returns
the first I<limit> rows of hit data for this sequence. If no I<limit> is provided, it
will default to 10.
It returns (match id, taxonomy string, log evalue, bitscore, alignment length, 
percent identity, start1, end1) per hit.

=cut

sub get_hits_for_sequence {
  my ($self, $id, $dataset, $limit) = @_;

  my $table = $self->dbtable; 
  my $dbid  = $self->get_dataset_id($dataset);
  $limit = 10 unless ($limit);

  my $sth = $self->dbh->prepare(qq(SELECT id2, tax_str, logpsc, bsc, ali_ln,
				   	iden, b1, e1
				   FROM $table
				   WHERE id1=? AND dbid=? AND rank_psc < ?));
  $sth->execute($id, $dbid, $limit);

  my $result = $sth->fetchall_arrayref();

  return $result;

}

=item * B<get_best_hit_for_sequence> (I<seq_id>, I<dataset>)

Given a sequence id I<seq_id> (id1) and a dataset name (db_id), this method returns
the first row of hit data for this sequence.
It returns (match id, taxonomy string, log evalue, bitscore, alignment length, 
percent identity, start1, end1) per hit.

=cut

sub get_best_hit_for_sequence {
  my ($self, $id, $dataset) = @_;

  my $table = $self->dbtable; 
  my $dbid  = $self->get_dataset_id($dataset);

  my $sth = $self->dbh->prepare(qq(SELECT id2, tax_str, logpsc, bsc, ali_ln,
				   	iden, b1, e1, b2, e2
				   FROM $table
				   WHERE id1=? AND dbid=?));
  $sth->execute($id, $dbid);

  my $result = $sth->fetchall_arrayref();

  return $result;

}


=pod 

=item * B<get_align_len_range> (I<dataset_name>)

Given a dataset name (db_id), this method returns
the minimum and maximum alignment length.

=cut 

sub get_align_len_range {
  my ($self, $dataset) = @_;

  my $table = $self->dbtable; 
  my $dbid  = $self->get_dataset_id($dataset);

  my $sth = $self->dbh->prepare("select min(ali_ln), max(ali_ln) from $table where dbid=$dbid");
  $sth->execute;
  my ($min, $max) = $sth->fetchrow_array;

  return ($min, $max);

}

=pod 

=item * B<get_genome_id> (I<tax_str>)

=cut 

sub get_genome_id {
  my ($self, $tax_str) = @_;
  $tax_str =~ s/'/''/g;
  my $retval =  $self->dbh->selectrow_array("select seq_num from rdp_to_tax where tax_str='". $tax_str . "'");
  if (ref($retval) eq 'ARRAY') {
    return $retval->[0];
  } else {
    return $retval;
  }
}

=pod

=item * B<get_mg_comparison_table_metadata>

returns the metadata (column names, headers) for the metagenome tables used in comparing metagenomes

=cut
sub get_mg_comparison_table_metadata{
    my ($self) = @_;
    my $column_metadata = {};
    my $desc = $self->data('dataset_desc');
    my $metagenome = $self->application->cgi->param('metagenome') || '';
    my $next_col;

    if (dataset_is_phylo($desc)){
	$column_metadata->{Domain} = {'value'=>'Domain',
				      'header' => { name => 'Domain', filter => 1, operator => 'combobox',
						    visible => 0, show_control => 1 },
				        'order' => 1,
				        'visible' => 1,
				        'group' => 'permanent'
					};
	$column_metadata->{level1} = {'value'=>'Taxa Level 1',
				      'header' => { name => '', filter => 1, operator => 'combobox',
						    sortable => 1, width => 150 },
				        'order' => 2,
				        'visible' => 1,
				        'group' => 'permanent'
					};
	$column_metadata->{level2} = {'value'=>'Taxa Level 2',
				      'header' => { name => '', filter => 1, operator => 'combobox',
						    width => 150 },
				        'order' => 3,
				        'visible' => 1,
				        'group' => 'permanent'
					};
	$column_metadata->{level3} = {'value'=>'Taxa Level 3',
				      'header' => { name => '', filter => 1, operator => 'combobox',
						    width => 150 },
				        'order' => 4,
				        'visible' => 1,
				        'group' => 'permanent'
					};
	$column_metadata->{organism} = {'value'=>'Organism',
					'header' => { name => 'Organism Name', filter => 1 },
					    'order' => 5,
					    'visible' => 1,
					'group' => 'permanent'};
	$next_col = 6;
    }
    elsif (dataset_is_metabolic($desc)){
	$column_metadata->{hierarchy1} = {'value'=>'Subsystem Hierarchy 1',
					  'header' => { name => 'Subsystem Hierarchy 1', filter => 1,
							operator => 'combobox', width => 150, sortable => 1 },
					        'order' => 1,
					        'visible' => 1,
					        'group' => 'permanent'
						};
	$column_metadata->{hierarchy2} = {'value'=>'Subsystem Hierarchy 1',
					  'header' => { name => 'Subsystem Hierarchy 2', filter => 1,
							width => 150  },
					        'order' => 2,
					        'visible' => 1,
					        'group' => 'permanent'
						};
	$column_metadata->{hierarchy3} = {'value'=>'Subsystem Hierarchy 1',
					  'header' => { name => 'Subsystem Name', filter => 1,
							sortable => 1,  width => 150  },
					        'order' => 3,
					        'visible' => 1,
					        'group' => 'permanent'
						};
	$next_col = 4;
    }
  
    # add your metagenome to permanent and add the other possible metagenomes to the select listbox
    # check for available metagenomes
    my $rast = $self->application->data_handle('RAST');  
    my $available = {};
    if (ref($rast)) {
	my $public_metagenomes = &get_public_metagenomes($self->app->dbmaster, $rast);
	foreach my $pmg (@$public_metagenomes) {
	    $column_metadata->{$pmg->[0]} = {'value' => 'Public - ' . $pmg->[1],
					     'header' => { name => $pmg->[0],
							         filter => 1,
							         operators => ['equal', 'unequal', 'less', 'more'],
							         sortable => 1,
							         width => 150,
							         tooltip => $pmg->[1] . '(' . $pmg->[0] . ')'
								 },
								 };
	    if ($pmg->[0] eq $metagenome){
		$column_metadata->{$pmg->[0]}->{order} = $next_col;
		$column_metadata->{$pmg->[0]}->{visible} = 1;
		$column_metadata->{$pmg->[0]}->{group} = 'permanent';
	    }
	    else{
		$column_metadata->{$pmg->[0]}->{visible} = 0;
		$column_metadata->{$pmg->[0]}->{group} = 'metagenomes';
	    }
	}

	if ($self->application->session->user) {
      
	    my $mgs = $rast->Job->get_jobs_for_user($self->application->session->user, 'view', 1);
      
      # build hash from all accessible metagenomes
	    foreach my $mg_job (@$mgs) {
		$column_metadata->{$mg_job->genome_id} = {'value' => 'Private - ' . $mg_job->genome_name,
							  'header' => { name => $mg_job->genome_id,
									filter => 1,
									operators => ['equal', 'unequal', 'less', 'more'],
									sortable => 1,
									width => 150,
									tooltip => $mg_job->genome_name . '(' . $mg_job->genome_id . ')'
									},
									};
		if ( ($mg_job->metagenome) && ($mg_job->genome_id eq $metagenome) ) {
		    $column_metadata->{$mg_job->genome_id}->{order} = $next_col;
		    $column_metadata->{$mg_job->genome_id}->{visible} = 1;
		    $column_metadata->{$mg_job->genome_id}->{group} = 'permanent';
		}
		else{
		    $column_metadata->{$mg_job->genome_id}->{visible} = 0;
		    $column_metadata->{$mg_job->genome_id}->{group} = 'metagenomes';  
		}
	    }
	}
    }
    else {
    # no rast/user, no access to metagenomes
    }
  
    return $column_metadata;
}


=pod

=back

=cut

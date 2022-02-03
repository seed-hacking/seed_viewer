package SeedViewer::WebPage::Experiment;
use base qw( WebPage );
use warnings;
use FIGMODEL;

1;

=pod
=head1 NAME
Microarray page
=head1 DESCRIPTION
View/Microarray experiments
=head1 METHODS
=over 4
=item * B<init> ()
Initialise the page
=cut

sub init {
  my $self = shift;
  $self->title('Experiment Conditions');
  my $app = $self->application();
  $app->register_component('Table', 'experimentsTable');
  $app->register_component('CompoundTable', 'cpdTable');
}

=item * B<output> ()
=cut
sub output {
	my ($self) = @_;
    my $app = $self->application();
    my $model = $app->data_handle("FIGMODEL");
    my $cgi = $app->cgi();
    my $html = "";
    my $genome = $cgi->param('g');
    my $experiment = $cgi->param('e');
    unless (defined($experiment)) {
        return $self->outputExperimentSelect();
    } 
    my $table = $app->component('cpdTable');
    my $experimentRow = $model->getExperimentDetails($experiment);
    unless(defined($experimentRow)) {
        $app->add_message('warning', "Could not find experiment '$experiment' in database!");
        return $self->outputExperimentSelect();
    }
    $html .= "<h2>Details for microarray experiment \"$experiment\"</h2>";
    $html .= "<table id='experimentDetails' ><tbody>";
    foreach my $key (keys %$experimentRow) {
        my $prettyKey = $key;
        $prettyKey =~ s/_/ /g;                  # turn_this => turn this
        $prettyKey =~ s/ph/pH/g;                # ph        => pH
        $prettyKey =~ s/(cdna|rna|dna)/\U$1/g;  # cdna      => CDNA
        $prettyKey =~ s/^(\w)/\U$1/;            # foo       => Foo
        $prettyKey =~ s/(\d)(\D)/$1 $2/g;       # 230ratio  => 230 ratio
        if ($key eq 'media') {
            next;
        } elsif ($key eq 'name') {
            next;
        } elsif ($key eq 'genome') {
            my $dataGenome = $experimentRow->{$key}->[0];
            warn $dataGenome;
            my $genomeFIG = $model->fig($dataGenome);
            my $genomeName = $model->get_genome_name($dataGenome) || $dataGenome;
            $html .= "<tr><td>$prettyKey</td><td>" . $genomeName . " (<a href='$FIG_Config::cgi_url/seedviewer.cgi?page=Organism&organism=$dataGenome'>$dataGenome</a>)"; 
            my $genomeModels = $model->get_models({ 'genome' => $dataGenome });
            if(@$genomeModels) {
                warn join(',', @$genomeModels);
                my @links;
                foreach my $genomeModel (@$genomeModels) {
                    warn join(' ', @$genomeModels);
                    if (defined($genomeModel) and defined($genomeModel->id())) {
                        push(@links, "<a href='$FIG_Config::cgi_url/seedviewer.cgi?page=ModelView&model=". $genomeModel->id() . "'>". $genomeModel->id() . "</a>");
                    }
                }
                $html .= " with models: " . join(', ', @links);
            }
            $html .= "</td></tr>";
            $html .= "<tr><td>Link to Regulons</td><td><a href='$FIG_Config::cgi_url/ma.cgi?genome=$dataGenome&experiment=$experiment'>$genomeName</a>";
            $html .= "</td></tr>";
        } else {
            $html .= "<tr><td>$prettyKey</td><td>" . $experimentRow->{$key}->[0] . "</td></tr>";
        }
    }
    $html .= "</tbody></table>";
    my $media = $experimentRow->{'media'}->[0];
    $html .= "<h3>Compounds included in experimental media \"$media\"</h3>".$self->outputMediaDetails($media);  
    return $html;
}

sub outputExperimentSelect {
    my ($self) = @_;
    my $app = $self->application();
    my $model = $app->data_handle('FIGMODEL');
    my $cgi = $app->cgi();
    my $html = "";
    my $experimentTable = $model->getExperimentsTable();
    my @selectedExperiments;
    my $genome = $cgi->param('g');
    if (defined($genome)) {
        if ($genome =~ /Seed(\d+)/) { # Table has 83333 not Seed83333.1
            $genome = $1;
        }
        @selectedExperiments = $experimentTable->get_rows_by_key($genome, 'genome');
    } else {   
        for (my $i=0; $i<$experimentTable->size(); $i++) {
            push(@selectedExperiments, $experimentTable->get_row($i));
        }
    }
    my $columns = [ {'name' => 'Experiment Id', 'filter' => 1, sortable => 1 },
                    {'name' => 'Organism', 'filter' => 1, sortable => 1 },
                    {'name' => 'Media Condition', 'filter' => 1, sortable => 1},
                    {'name' => 'Regulon Links', 'filter' => 0, sortable => 0},
                  ];
    my $outputTable = $app->component('experimentsTable');
    my $data = [];
    for(my $i=0; $i<@selectedExperiments; $i++) {
        my $row = [];
        foreach my $column (@$columns) {
            my $item;
            if ($column->{'name'} eq 'Experiment Id') {
                push(@$row, "<a href='$FIG_Config::cgi_url/seedviewer.cgi?page=Experiment&e=".
                    $selectedExperiments[$i]->{'name'}->[0]."'>".$selectedExperiments[$i]->{'name'}->[0]."</a>");
            } elsif ($column->{'name'} eq 'Organism') {
                my $genomeId = $selectedExperiments[$i]->{'genome'}->[0];
                my $genomeName = $model->get_genome_name($genomeId) || $genomeId;
                push(@$row, "$genomeName (<a href='$FIG_Config::cgi_url/seedviewer.cgi?page=Organism&organism=$genomeId'>$genomeId</a>)");
            } elsif ($column->{'name'} eq 'Media Condition') {
                push(@$row, $selectedExperiments[$i]->{'media'}->[0]);
            } elsif ($column->{'name'} eq 'Regulon Links') {
               my $genomeId = $selectedExperiments[$i]->{'genome'}->[0];
               push(@$row, "<a href='$FIG_Config::cgi_url/ma.cgi?genome=$genomeId'>$genomeId</a>");
            } else {
                push(@$row, "");
            }
        }
        push(@$data, $row);
    }
    $outputTable->columns($columns);
    $outputTable->data($data);
    $outputTable->show_top_browse(1);
    $outputTable->show_bottom_browse(1);
    $outputTable->items_per_page(50);
    $html .= "<div style='margin: auto; display: table;'><h3>Select an experiment for more details.</h3>".$outputTable->output() . "</div>";
    return $html;
}

sub outputMediaDetails {
    my ($self, $mediaName) = @_;
    my $app = $self->application();
    my $model = $app->data_handle("FIGMODEL");
    my $mediaFilename = $model->{'Reaction database directory'}->[0] . "Media/" . $mediaName . ".txt";
    if (not -e $mediaFilename) {
        warn "Media file: $mediaFilename does not exist!";
        return;
    }
    my $outputTable = $app->component('cpdTable');
    my $mediaTable = $model->database()->load_table($mediaFilename, ';', ',', 0, ['VarName']) or    
        die "Could not load media file: $filename $!";
    my @cpds;
    for (my $i=0; $i<$mediaTable->size(); $i++) {
        my $row = $mediaTable->get_row($i);
        push(@cpds, $row->{'VarName'}->[0]);
    }
    return $outputTable->output(join(',',@cpds));
}
        
sub require_css {
    return ["$FIG_Config::cgi_url/Html/Experiment.css"];
}
    

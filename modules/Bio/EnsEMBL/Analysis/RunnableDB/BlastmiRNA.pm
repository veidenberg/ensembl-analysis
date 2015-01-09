=head1 LICENSE

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Analysis::RunnableDB::BlastmiRNA - 

=head1 SYNOPSIS

  my $blast = Bio::EnsEMBL::Analysis::RunnableDB::BlastmiRNA->new
     (
      -analysis => $analysis,
      -db       => $db,
      -input_id => 'contig::AL1347153.1.3517:1:3571:1'
     );
  $blast->fetch_input;
  $blast->run;
  my @output =@{$blast->output};

=head1 DESCRIPTION

Modified blast runnable for specific use with miRNA
Use for running BLASTN of genomic sequence vs miRNAs prior to 
miRNA anaysis
Slice size seems best around 200k

=head1 METHODS

=cut

package Bio::EnsEMBL::Analysis::RunnableDB::BlastmiRNA;

use strict;
use warnings;

use Bio::EnsEMBL::Analysis::RunnableDB::Blast;
use Bio::EnsEMBL::Analysis::Runnable::BlastmiRNA;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Analysis::Config::General;
use Bio::EnsEMBL::Analysis::Config::Blast;
use Bio::EnsEMBL::Analysis::RunnableDB::BaseGeneBuild;
use Bio::EnsEMBL::Analysis::Config::Databases qw(DATABASES DNA_DBNAME); 

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Analysis::RunnableDB::Blast  Bio::EnsEMBL::Analysis::RunnableDB::BaseGeneBuild);


=head2 fetch_input

  Arg [1]   : None
  Function  : fetch sequence out of database, instantiate the filter,
            : parser and finally the blast runnable
  Returntype: None
  Exceptions: none
  Example   : $blast->fetch_input;

=cut

sub fetch_input{
  my ($self) = @_;  

  #add dna_db
  my $dna_db = $self->get_dbadaptor($DNA_DBNAME) ; 
  $self->db->dnadb($dna_db); 

  my $slice = $self->fetch_sequence($self->input_id, $self->db,'');
  $self->query($slice);
  my %blast = %{$self->BLAST_PARAMS};
  my $parser = $self->make_parser;
  my $filter;
  if($self->BLAST_FILTER){
    $filter = $self->make_filter;
  }
  my $seq = $self->query;
  my $runnable = Bio::EnsEMBL::Analysis::Runnable::BlastmiRNA->new
    (
     -query    => $seq,
     -program  => $self->analysis->program_file,
     -parser   => $parser,
     -filter   => $filter,
     -database => $self->analysis->db_file,
     -analysis => $self->analysis,
     -params   => \%blast,
    );
  $self->runnable($runnable);
  return 1;
}



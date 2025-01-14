=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Analysis::Hive::Config::PseudoGeneStatic

=head1 SYNOPSIS

use Bio::EnsEMBL::Analysis::Tools::Utilities qw(get_analysis_settings);
use parent ('Bio::EnsEMBL::Analysis::Hive::Config::HiveBaseConfig_conf');

sub pipeline_analyses {
    my ($self) = @_;

    return [
      {
        -logic_name => 'run_uniprot_blast',
        -module     => 'Bio::EnsEMBL::Analysis::Hive::RunnableDB::HiveAssemblyLoading::HiveBlastGenscanPep',
        -parameters => {
                         blast_db_path => $self->o('uniprot_blast_db_path'),
                         blast_exe_path => $self->o('uniprot_blast_exe_path'),
                         commandline_params => '-cpus 3 -hitdist 40',
                         repeat_masking_logic_names => ['repeatmasker_'.$self->o('repeatmasker_library')],
                         prediction_transcript_logic_names => ['genscan'],
                         iid_type => 'feature_id',
                         logic_name => 'uniprot',
                         module => 'HiveBlastGenscanPep',
                         %{get_analysis_settings('Bio::EnsEMBL::Analysis::Hive::Config::BlastStatic','BlastGenscanPep')},
                      },
        -flow_into => {
                        -1 => ['run_uniprot_blast_himem'],
                        -2 => ['run_uniprot_blast_long'],
                      },
        -rc_name    => 'blast',
      },
  ];
}

=head1 DESCRIPTION

This is the config file for all pseudogene analysis. You should use it in your Hive configuration file to
specify the parameters of an analysis. You can either choose an existing config or you can create
a new one based on the default hash.

=head1 METHODS

  _master_config_settings: contains all possible parameters

=cut

package Bio::EnsEMBL::Analysis::Hive::Config::PseudoGeneStatic;

use strict;
use warnings;

use parent ('Bio::EnsEMBL::Analysis::Hive::Config::BaseStatic');

sub _master_config {
  my ($self, $key) = @_;

  my %config = (
      default => {
               # you can set the input- and output database - the names should point to
               # keys in Database.pm
               PS_INPUT_DATABASE  => 'GENEBUILD_DB',
               PS_OUTPUT_DATABASE => 'PSEUDO_DB',

               # configs for the introns in repeats test

               # introns longer than the following are considered "real"
               PS_FRAMESHIFT_INTRON_LENGTH => 75,
               # This is used to set a limit on the allowed number of frameshift introns before something is
               # definitely called a pseudogene
               MAX_FRAMESHIFT_INTRONS  => 2,
               # total length of introns
               PS_MAX_INTRON_LENGTH   => '5000',
               # Types of repeats to run the anaysis with
               PS_REPEAT_TYPES =>  ['LINE','LTR','SINE'],
               # max percent coverage of the introns with the above repeats
               PS_MAX_INTRON_COVERAGE => '80',
               # max allowed exon coverage with the above repeats
               PS_MAX_EXON_COVERAGE   => '99',
               # This is used in a few places. It generally flags things that look a bit dodgy cos they
               # have a frameshift, but unless it only has one intron there are other test needed before
               # classing something with a single frameshift as a pseudogene
               PS_NUM_FRAMESHIFT_INTRONS  => 1,
               # This is used to decided how many real introns are needed before reducing the strictness in
               # terms of something being protein coding as opposed to a pseudogene
               PS_NUM_REAL_INTRONS  => 1,
               # biotype of genes to check
               PS_BIOTYPE  => 'protein_coding',

               # Blessed genes dont get called pseudogenes
               # Biotype is a transcript biotype
               BLESSED_BIOTYPES => { 'ccds_gene' => 1 },

               # configs for the spliced elsewhere tests
               # %ID of a tbalstx of the (presumed) retrotransposed query sequence to its
               # homolog that is spliced elsewhere in the genome. hits falling below
               # this cutoff are ignored (80%) is suggested
               PS_PERCENT_ID_CUTOFF   => 40,
               PS_P_VALUE_CUTOFF   => '1.0e-50',
               PS_RETOTRANSPOSED_COVERAGE   => 80,
               PS_ALIGNED_GENOMIC  => 100,
               # logic name to give to pseudogenes
               PS_PSEUDO_TYPE      => 'pseudogene',
               # if a gene is found to be a pseudogene, its gene biotype will be changed to
               # PS_PSEUDO_TYPE. By default, the biotype of its transcript will also be changed
               # to PS_PSEUDO_TYPE.  If you want to keep the original transcript biotype
               # instead (so you can keep track of what type of models actually got turned into a
               # pseudogene), set KEEP_TRANS_BIOTYPE to 1.

               KEEP_TRANS_BIOTYPE  => 0,

               # logic name to give genes with exons covered by repeats
               # if left blank they will just get deleted (recommended)
               PS_REPEAT_TYPE      => '',

               # analysis logic names to run over genes falling into these categories
               SINGLE_EXON      => 'spliced_elsewhere',
               INDETERMINATE    => '',
               RETROTRANSPOSED  => '',
               # if you dont wish to run further tests on retro transposed genes
               # What type would you like to give them?
               # previously set to 'retrotransposed', we change to 'processed_pseudogene' from e70 onwards.
               RETRO_TYPE       => 'processed_pseudogene',

               SPLICED_ELSEWHERE_LOGIC_NAME => 'spliced_elsewhere',
               PSILC_LOGIC_NAME => 'Psilc',
               # SPLICED ELSEWHERE SPECIFIC CONFIG
               # ratio of the spans of the retrotransposed gene vs its spliced homologue
               # spliced / retrotransposed
               # ie: 1 is the same length genes
               # many retrotransposed genes have a ratio > 10
               # used to make retrotransposition decision
               PS_SPAN_RATIO          => 3,
               # mimimum number of exons for the spliced gene to have
               PS_MIN_EXONS           => 4,
               # path of blast db of multi exon genes
               PS_MULTI_EXON_DIR       => '#output_path#' ,
               # Chunk size
               PS_CHUNK => '50',
               DEBUG => '0',
              },

              pseudogenes => {
                PS_INPUT_DATABASE  => 'GBUILD_DB',
                # biotype of genes to check
                PS_BIOTYPE  => 'protein_coding',
                # path of blast db of multi exon genes
              },

              spliced_elsewhere => {
                PS_INPUT_DATABASE  => 'GBUILD_DB',
                # biotype of genes to check
                PS_BIOTYPE  => 'ensembl_utr',
                # path of blast db of multi exon genes
             },
  );
  return $config{$key};
}

1;


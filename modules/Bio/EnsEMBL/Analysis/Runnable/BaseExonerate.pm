
=pod

=head1 NAME

Bio::EnsEMBL::Analysis::Runnable::ExonerateTranscript

=head1 SYNOPSIS

  Do NOT instantiate this class directly: must be instantiated
  from a subclass (see ExonerateTranscript, for instance).

=head1 DESCRIPTION

This is an abstract superclass to handle the common functionality for 
Exonerate runnables: namely it provides
- a consistent external interface to drive exonerate regardless of
  what features you're finally producing, and
- a common process to stop people duplicating function (eg how to
  arrange command-line arguments, what ryo-string to use etc).

It does NOT provide the parser to convert the exonerate output
into Transcripts or AffyFeatures etc. That is the job of the
subclasses, which MUST implement the parse_results method.

=head1 CONTACT

ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Analysis::Runnable::BaseExonerate;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::Transcript;
use Bio::EnsEMBL::Translation;
use Bio::EnsEMBL::Exon;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::DnaPepAlignFeature;
use Bio::EnsEMBL::FeaturePair;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );


@ISA = qw(Bio::EnsEMBL::Analysis::Runnable);


sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  
  my 
    (
      $query_type, $query_seqs, $query_file, $q_chunk_num, $q_chunk_total,
      $target_file, $verbose
    ) =
    rearrange(
      [
        qw(
          QUERY_TYPE
          QUERY_SEQS
          QUERY_FILE
          QUERY_CHUNK_NUMBER
          QUERY_CHUNK_TOTAL
          TARGET_FILE
          VERBOSE
        )
      ], 
      @args
    );

  $self->_verbose($verbose) if $verbose;
  $self->_verbose(1);

  if (defined($query_seqs)) {
    if(ref($query_seqs) ne "ARRAY"){
      throw("You must supply an array reference with -query_seqs")
    }
    $self->query_seqs($query_seqs);
  } elsif (defined $query_file) {
    throw("The given query file does not exist") if ! -e $query_file;
    $self->query_file($query_file);
    
  }

  if ($query_type){
    $self->query_type($query_type);
  } else{
    # default to DNA for backwards compatibilty
    $self->query_type('dna');
  }

  if (defined $target_file) {
    throw("The given database does not exist") if ! -e $target_file;
    $self->target_file($target_file);
  }

  if (not $self->program) {
    $self->program('/usr/local/ensembl/bin/exonerate-0.8.3');
  }

  #
  # These are what drives how we gather up the output
  my $basic_options = "--showsugar false --showvulgar false --showalignment false --ryo \"RESULT: %S %pi %ql %tl %g %V\\n\" ";
  
  if (defined $q_chunk_num and defined $q_chunk_total) {
    $basic_options .= "--querychunkid $q_chunk_num --querychunktotal $q_chunk_total ";
  }

  if ($self->options){
    $basic_options .= $self->options;
  }
  
  $self->options($basic_options);

  return $self;
}



############################################################
#
# Analysis methods
#
############################################################

=head2 run

Usage   :   $obj->run($workdir, $args)
Function:   Runs exonerate script and puts the results into the file $self->results
            It calls $self->parse_results, and results are stored in $self->output
=cut

sub run {
  my ($self) = @_;

  if ($self->query_seqs) {
    # Write query sequences to file if necessary
    my $query_file = $self->workdir . "/exonerate_q.$$";
    my $seqout = 
      Bio::SeqIO->new(
        '-format' => 'fasta',
        '-file'     => ">$query_file"
      );
      
    foreach my $seq ( @{$self->query_seqs} ) {
      $seqout->write_seq($seq);
    }
    
    # register the file for deletion
    $self->files_to_delete($query_file);
    $self->query_file($query_file);
  }

  # Build exonerate command

  my $command =
    $self->program . " " .$self->options .
    " --querytype "  . $self->query_type .
    " --targettype " . $self->target_type .
    " --query "  . $self->query_file .
    " --target " . $self->target_file;
  
  # Execute command and parse results

  print STDERR "Exonerate command : $command\n" if $self->_verbose;

  my $exo_fh;
  open( $exo_fh, "$command |" ) or throw("Error opening exonerate command: $? $!");
  
  $self->output($self->parse_results( $exo_fh ));
  
  close( $exo_fh ) or throw ("Error closing exonerate command: $? $!");
  $self->delete_files;

  return 1;
}

=head2 new

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::BaseExonerate
  Arg [2]   : pointer to file-handle
  Function  : This method MUST be coded by the base class to return an array-ref of features.
              arguments - is passed a pointer to a filehandle which is the output
              of exonerate.
              Exonerate's basic options - it's always run with - are:
              --showsugar false --showvulgar false --showalignment false --ryo \"RESULT: %S %pi %ql %tl %g %V\\n\"
              so this tells you what the output file will look like: you have
              to code the parser accordingly.
  Returntype: Listref of <things>
  Example   : 
    my ( $self, $fh ) = @_;
    while (<$fh>){
      next unless /^RESULT:/;
      chomp;
      my (
        $tag, $q_id, $q_start, $q_end, $q_strand, 
        $t_id, $t_start, $t_end, $t_strand, $score, 
        $perc_id, $q_length, $t_length, $gene_orientation,
        @vulgar_blocks
      ) = split;
      ...now do something with the match information and / or vulgar blocks
    }
=cut
sub parse_results {
  throw ("This method must be provided by a subclass and not invoked directly! \n"); 
}

############################################################
#
# get/set methods
#
############################################################

sub query_type {
  my ($self, $mytype) = @_;
  if (defined($mytype) ){
    my $type = lc($mytype);
    unless( $type eq 'dna' || $type eq 'protein' ){
      throw("not the right query type: $type");
    }
    $self->{_query_type} = $type;
  }
  return $self->{_query_type};
}

############################################################

sub query_seqs {
  my ($self, $seqs) = @_;
  if ($seqs){
    unless ($seqs->[0]->isa("Bio::PrimarySeqI") || $seqs->[0]->isa("Bio::SeqI")){
      throw("query seq must be a Bio::SeqI or Bio::PrimarySeqI");
    }
    $self->{_query_seqs} = $seqs;
  }
  return $self->{_query_seqs};
}


############################################################

sub query_file {
  my ($self, $file) = @_;
  
  if ($file) {
    $self->{_query_file} = $file;
  }
  return $self->{_query_file};
}

############################################################

sub target_type {
  my ($self) = @_;

  # the target type has to be DNA, because we are making transcripts

  return 'dna';
}

############################################################

sub target_file {
  my ($self, $file) = @_;
  
  if ($file) {
    $self->{_target_file} = $file;
  }
  return $self->{_target_file};
}

############################################################

sub _verbose {
  my ($self, $val) = @_;
  
  if ($val){
    $self->{_verbose} = $val;
  }
  
  return $self->{_verbose};
}


1;


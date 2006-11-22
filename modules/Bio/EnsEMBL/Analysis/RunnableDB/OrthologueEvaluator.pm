
=pod

=head1 NAME

Bio::EnsEMBL::Analysis::RunnableDB::OrthologueAnaysis; 




=head1 SYNOPSIS

my $orthologueanalysis = Bio::EnsEMBL::Analysis::RunnableDB::OrthologueEvaluator->new(
			      -analysis   => $analysis_obj,
			     );

$orthologueanalysis->fetch_input();
$orthologueanalysis->run();
$orthologueanalysis->output();
$orthologueanalysis->write_output(); 


=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Analysis::Runnable::OrthologueEvaluator and is 
used to fetch the input from different databases as well as writing results 
the results to the database.a


=head1 CONTACT

Post general queries to B<ensembl-dev@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a '_'

=cut

package Bio::EnsEMBL::Analysis::RunnableDB::OrthologueEvaluator; 

use strict;
use Bio::SeqIO;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Analysis::RunnableDB;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Analysis::Config::GeneBuild::OrthologueEvaluator; 
use Bio::EnsEMBL::Analysis::Config::GeneBuild::Databases; 
use Bio::EnsEMBL::Analysis::Tools::GeneBuildUtils; 
use Bio::EnsEMBL::Registry; 
use Bio::EnsEMBL::Pipeline::Utils::InputIDFactory;  
use Bio::EnsEMBL::Pipeline::Utils::InputIDFactory;  
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor; 
use Bio::EnsEMBL::Analysis::Config::Exonerate2Genes;  
use Bio::EnsEMBL::Pipeline::DBSQL::RuleAdaptor;
use Bio::EnsEMBL::Pipeline::Rule; 
use vars qw(@ISA); 

@ISA = qw (Bio::EnsEMBL::Analysis::RunnableDB);


sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args); 
  $self->read_and_check_config;  
  $self->verbose(1) ; 
  return $self   ;
}


sub get_initial_geneset {  
  my ( $self, $species_alias,$biotypes) = @_ ; 

  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species_alias,'core') ; 
  my $sa = $dba->get_SliceAdaptor() ;

  print "fetching genes out of ". $dba->dbname . " @ " . $dba->host ." : " . $dba->port . "\n" 
  if $self->verbose;

  my $qy_slice      = $sa->fetch_by_name($self->slice_name) ;

  my @pt_genes ;
  for my $bt ( @$biotypes ) { 
    my $genes_on_slice =  $qy_slice->get_all_Genes_by_type( $bt );
    print scalar(@$genes_on_slice) . " genes of biotype $bt found on slice\n";  
    $self->genes( $genes_on_slice ) ; 
   }
} 


sub upload_input_ids {  
   my ( $self, $input_ids  ) = @_ ; 
 
   my $submit_analysis = "Submit_" . $self->post_logic_name;     

   # otherwise the Registry overrides the adaptor - silly ... 
   #print "db before clear : " . $self->db(); 
   #print "\n" ;  
   #Bio::EnsEMBL::Registry->clear();  
   #print "db after clear : " . $self->db(); 
   #print "\n" ;  
   $self->pipeline_adaptor($self->db) ;  
 
    my  $input_id_type = "file_" . $self->post_logic_name ;  
    my $if = Bio::EnsEMBL::Pipeline::Utils::InputIDFactory->new(  
                 -db => $self->pipeline_adaptor , 
                 -logic_name => $submit_analysis , 
                 -file => 1 , 
                 -input_id_type => $input_id_type, 
               );  
     unless ($if->get_analysis($submit_analysis , $input_id_type,  1)) { 
       throw( "Cant find analysis $submit_analysis in db ") ; 
     }
     # check first if input_id is not already stored ...
      my $a = 
       $self->pipeline_adaptor->get_AnalysisAdaptor->fetch_by_logic_name($submit_analysis) ; 
       my $ia_db = $self->pipeline_adaptor->get_StateInfoContainer->list_input_id_by_Analysis($a) ;    
       my @input_ids_not_stored ;  
     
       my %tmp ; 
       @tmp{@$ia_db} = 1; 
       for my $i ( @$input_ids ) { 
         push @input_ids_not_stored, $i unless (exists $tmp{$i}) ; 
       } 
      print scalar(@$input_ids) - scalar(@input_ids_not_stored) . " input ids already stored in db " . $self->pipeline_adaptor->dbname . "\n" ;  
      $if->input_ids(\@input_ids_not_stored) ;  
      $if->store_input_ids;  
      print scalar(@input_ids_not_stored) . " input-ids uploaded into " . $self->pipeline_adaptor->dbname . "\n" ; 
}


sub chunk_and_write_fasta_sequences {
    my ( $self, $tref, $base_dir , $file_prefix, $file_suffix  ) = @_ ;

    print scalar(@$tref) . " sequences to write \n" ;

    return if scalar(@$tref) == 0 ; 

    unless ($base_dir) {
      my $conf = $$EXONERATE_CONFIG_BY_LOGIC{$self->post_logic_name}{QUERYSEQS};  
      $conf ? $base_dir = $conf : throw ( "There's no output-dir configured in Exonerate2Genes.pm " . 
      "for analysis " . $self->post_logic_name . " check the config\n"); 
    }
  
    $base_dir = $base_dir . "/" unless $base_dir =~m/\/$/;
    #$base_dir = $base_dir . $self->post_logic_name . "/" ;

    `mkdir $base_dir ` unless ( -e $base_dir);
    $file_prefix = $self->slice_name unless $file_prefix ;
    $file_suffix = ".fa" unless $file_suffix ;

    print "writing squences to $base_dir\n" ;

    my @filenames ;

    my $cs = 10  ; # chunksize    
    my $wtf = 0 ;
    my @ltr = @$tref ;
    my ($seq_file , $name ) ;
    my $fcnt = 0 ;

    for ( my $i=0 ; $i<scalar(@ltr) ; $i++ ) {
      my $seq = $ltr[$i] ;
      # create new file if #$cs chunks are already written
      if ($i % $cs == 0 ){

          $seq_file->close() if ($wtf == 1) ;
          $fcnt++;
          my $file_name  = $file_prefix . "_" . $fcnt . $file_suffix ;
          # these filenames are stored as input_ids in refdb  
          push @filenames, $file_name ;
          my $tmp = $base_dir . $file_name ;

          $seq_file = Bio::SeqIO->new(
                                       #-file => ">$base_dir. $file_name" ,
                                       -file => ">$tmp" ,
                                       -format => 'fasta'
                                     );

          $wtf = 1 ;
      }
          $seq_file->write_seq($seq);
    }
    $seq_file->close();
    return \@filenames ;
}


sub genes {
  my ($self, $g) = @_ ;
  push @{$self->{_genes}}, @$g if $g ;
  return $self->{_genes} ;
} 


sub species_1 {
  my ($self, $g) = @_ ;
  $self->{_species_1} = $g if $g ;
  return $self->{_species_1} ;
} 

sub species_2 {
  my ($self, $g) = @_ ;
  $self->{_species_2} = $g if $g ; 
  return $self->{_species_2} ; 
}

sub post_logic_name {  
  my ($self) = @_ ;
  my $post_logic_name = $self->input_id ; 
  $post_logic_name =~s/(^.*?)(\:.*)/$1/ ;  
  return $post_logic_name ; 
}

sub slice_name  {   
  my ($self) = @_ ;  
  my $slice_name = $self->input_id ; 
   $slice_name  =~s/(^.*?\:)(.*)/$2/   ;
 return $slice_name ; 
}

sub run {
  my ($self) = @_; 
}

sub write_output{
  my ($self,$missing_seq) = @_;
}




sub read_and_check_config {
  (my $self) = @_ ;  

  # check if config file exists 

   throw("Your compara-registry-file LOCATION_OF_COMPARA_REGISTRY_FILE does not exist !!".
        "\nCheck your config !")
     unless ( -e $$MAIN_CONFIG{LOCATION_OF_COMPARA_REGISTRY_FILE} ) ; 

    # check compara configuration file and schema-versions of dbs

    Bio::EnsEMBL::Registry->load_all($$MAIN_CONFIG{LOCATION_OF_COMPARA_REGISTRY_FILE});
    my @dba = @{Bio::EnsEMBL::Registry->get_all_DBAdaptors()}; 
   
    my %tmp; 
    for my $a ( @dba ) { 
        push @{$tmp{ $a->get_MetaContainer->get_schema_version }} , $a->dbname  ; 
    }
    if ( keys %tmp > 1 ) { 
       warning("You're using databases with different schemas - this can cause problems ...\n" ) ;  
       for ( keys %tmp ) {
         print "schema $_:\n". join("\n" , @{$tmp{$_}} ) . "\n\n"  ; 
       }
    }  
}


sub pipeline_adaptor{  
    my ($self, $db )= @_ ;    
 
       if ( $db ) { 
         my $pa = Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor->new(
                                                            -host   => $db->host, 
                                                            -dbname => $db->dbname, 
                                                            -user   => $db->username,
                                                            -pass   => $db->password ,
                                                            -port   => $db->port,
                                                            );
         $self->{_PA}=$pa ;  
       } 
    return $self->{_PA} ; 
}



#sub get_one2one_orthologues {  
#    my ($compara, $species_1, $species_2 ) = @_ ;  
#
#    my $ha   = Bio::EnsEMBL::Registry->get_adaptor('compara','compara',"Homology" ) ;   
#    my $gdba = Bio::EnsEMBL::Registry->get_adaptor('compara',"compara","GenomeDB");
#    my $ma   = Bio::EnsEMBL::Registry->get_adaptor('compara',"compara","Member");  
#
#    my $taxon_1= $compara->get_GenomeDBAdaptor->fetch_by_registry_name($species_1)->taxon_id  ;  
#
#    # if you've used an alias in your config we now go back to real species name in compara 
#    my $species_2_name = $compara->get_GenomeDBAdaptor->fetch_by_registry_name($species_2)->name;   
#
#    # ... now we get all objects out of compara which exist for species1 ( taxonid 1 ) 
#    # basicly a list of members of species_1 which have a known orthologue anywhere 
#    
#    my $spec1_memb_ref =  $ma->fetch_all_by_source_taxon('ENSEMBLGENE',$taxon_1);  
#
#    my %one2one_orth ;    
#    # loop trough the list of species_1 members  
#    MEMBER: foreach my $member (@$spec1_memb_ref) {
#
#        my @all_known_homologies_for_member = @{$ha->fetch_all_by_Member($member )} ;  
#        next MEMBER if (scalar(@all_known_homologies_for_member) <1)  ; 
#
#
#        # this is because fetch_by_Member_paired_species does not work 
#        my $hom_ref = filter_homologies( \@all_known_homologies_for_member,$species_2_name ) ;  
#
#        if ( scalar(@$hom_ref) ==  1 ) {   
#
#           HOMOLOGIES :for my $homology ( @$hom_ref ) { 
#             my @all_member_attributes = @{$homology->get_all_Member_Attribute} ;
#             shift @all_member_attributes ;  # first object is source itself so don't process this 
#
#             MA: foreach my $member_attribute (@all_member_attributes) { 
#               my ($new_member, $attribute) = @{$member_attribute};
#               my $species_name_of_orthologue = $new_member->genome_db->name ;  
#               #print $member->stable_id  . "\t" . $new_member->stable_id . "\n" ;         
#               $one2one_orth{$member->stable_id} = $new_member->stable_id ; 
#             }
#          }
#       } else {  
#         # no one2one relation 
#       } 
#   }   
#   return \%one2one_orth ; 
#} 
#
#sub filter_homologies {  
#  my ( $all_homologies , $look_for_this_species) = @_ ;    
#  my @result ;
# 
#  HOMOLOGIES :for my $homology ( @$all_homologies ) { 
#     my @all_member_attributes = @{$homology->get_all_Member_Attribute} ;
#     # first object is source itself so don't process this 
#     shift @all_member_attributes ;
#
#     MA: foreach my $member_attribute (@all_member_attributes) { 
#       my ($new_member, $attribute) = @{$member_attribute};
#       my $species_name_of_orthologue = $new_member->genome_db->name ;    
#       if ( $species_name_of_orthologue =~m/$look_for_this_species/) {  
#         push @result, $homology ; 
#       }
#     } 
#  }  
#  return \@result ; 
#} 
#


# this all goes into the setup script ..... 
#   
#   # check if Exonerate2Genes analysis exists in analysis-table of refdb 
#
#   my %e2g_config = %{$EXONERATE_CONFIG_BY_LOGIC};
#
#   print $EXONERATE_2_GENES_LOGIC_NAME . "\n" ; 
# 
#   unless ( exists $e2g_config{$EXONERATE_2_GENES_LOGIC_NAME} ) { 
# 
#     throw("You have defined a logic_name EXONERATE_2_GENES_LOGIC_NAME ".
#           "\"$EXONERATE_2_GENES_LOGIC_NAME\"\n in our OrthologueEvaluator.pm".
#           " configuration file but there is no configuration for such an analysis in the\n".
#           " Exonerate2Genes-config, so i don't know where to write the genes to.\n".
#           " I suggest to add a configuration for $EXONERATE_2_GENES_LOGIC_NAME to your ".
#           "Exoneate2Genes.pm config\n") ; 
#   }  
#
#   # check if the sequence dump directory in Exonerate2Genes config exists  
# 
#   my $seq_dump_dir = $$EXONERATE_CONFIG_BY_LOGIC{$EXONERATE_2_GENES_LOGIC_NAME}{QUERYSEQS} ; 
#
#   #
#   #
#   # THIS SECTION CREATES ANALYSIS AUTOMATICLY IF IT CAN'T FIND THE ANALYSIS IN THE DB 
#   #
#   #
#
# 
#   if ($$FIND_MISSING_ORTH{AUTOMATE_ORTHOLOGUE_RECOVERY}){ 
#
#       my $analysis = 
#         $self->db->get_AnalysisAdaptor->fetch_by_logic_name($EXONERATE_2_GENES_LOGIC_NAME) ;  
#
#       unless ($analysis) { 
#         #
#         # set up analysis if missing  
#         #
#         warning("Can't find analysis $EXONERATE_2_GENES_LOGIC_NAME in " . $self->db->dbname ." \@ "
#                 . $self->db->host."\nCreating my very own analysis with hard-coded values ".
#                  "out of RunnableDB $self now and a set of rules as well...\n") ;  
#        
#         my $ana = new Bio::EnsEMBL::Pipeline::Analysis ( 
#                      -logic_name => $EXONERATE_2_GENES_LOGIC_NAME, 
#                      -program    => 'exonerate' , 
#                      -program_file => 'exonerate-1.0.0' , 
#                      -module      => 'Exonerate2Genes' ,
#                      -input_id_type => 'oa_filename',
#                      )  ;    
#
#         $self->pipeline_adaptor->get_AnalysisAdaptor->store($ana) ;   
#
#         my $submit_ana = "Submit_".$EXONERATE_2_GENES_LOGIC_NAME ;
# 
#         my $submit = new Bio::EnsEMBL::Pipeline::Analysis ( 
#                      -logic_name => $submit_ana , 
#                      -module      => 'Dummy', 
#                      -input_id_type => 'oa_filename',
#                      )  ; 
#
#         $self->pipeline_adaptor->get_AnalysisAdaptor->store($submit) ;   
#
#         # store rule if does not exist
#         my $ruleAdaptor = $self->pipeline_adaptor->get_RuleAdaptor();  
#
#         my $rule = Bio::EnsEMBL::Pipeline::Rule->new(-goalanalysis => $ana);
#         $rule->add_condition($submit_ana) ; 
#         $rule->goalAnalysis($ana); 
#         $ruleAdaptor->store($rule); 
#      }
#    }


1;

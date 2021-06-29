#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
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
use strict;
use warnings;

use Test::More;

use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Test::MultiTestDB;

use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);

use_ok('Bio::EnsEMBL::Analysis::Hive::RunnableDB::CleanUTRs');

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('pararge_aegeria');
my $iid = 'primary_assembly:ilParAegt1.1:1:1:21295481:1';

my %transcript_hashkey = (
  ENSPAGT00005009094 => ':7555030:7555504:-1:-1:-1:7539772:7539921:-1:-1:1:7532631:7532860:-1:1:0:7530275:7530391:-1:0:0:7529714:7529920:-1:0:0:7524996:7525128:-1:0:1:7523477:7523706:-1:1:0:7522602:7522796:-1:0:0:7519669:7521417:-1:0:-1',
  ENSPAGT00005009105 => ':7555030:7555504:-1:-1:-1:7539772:7539921:-1:-1:1:7532631:7532860:-1:1:0:7530275:7530391:-1:0:0:7529714:7529920:-1:0:0:7524996:7525128:-1:0:1:7523477:7523706:-1:1:0:7522602:7522796:-1:0:0:7519669:7521417:-1:0:-1',
  ENSPAGT00005009363 => ':13645738:13645907:1:-1:-1:13648453:13649543:1:-1:0:13649717:13649939:1:0:1:13650123:13650342:1:1:2:13651022:13652888:1:2:-1',
  ENSPAGT00005009369 => ':13645738:13645907:1:-1:-1:13648453:13649543:1:-1:0:13649717:13649939:1:0:1:13650123:13650342:1:1:2:13651022:13652888:1:2:-1',
  ENSPAGT00005009377 => ':13648250:13648278:1:0:2:13648697:13649543:1:2:0:13649717:13649939:1:0:1:13650123:13650342:1:1:2:13651022:13651310:1:2:0',
  ENSPAGT00005009805 => ':15623672:15623869:-1:-1:-1:15623281:15623537:-1:0:2:15622662:15622840:-1:2:1:15621976:15622088:-1:1:0:15621162:15621323:-1:0:0:15616608:15616828:-1:0:-1',
  ENSPAGT00005009808 => ':15628654:15628936:-1:-1:0:15623281:15623537:-1:0:2:15622662:15622840:-1:2:1:15621976:15622088:-1:1:0:15620429:15621323:-1:0:-1',
  ENSPAGT00005009856 => ':10024083:10025182:-1:-1:1:10023164:10023415:-1:1:1:10022419:10023045:-1:1:1:10010726:10010911:-1:1:-1',
  ENSPAGT00005010431 => ':3633933:3634053:1:-1:0:3634262:3634349:1:0:1:3635169:3635269:1:1:0:3635958:3636155:1:0:-1',
  ENSPAGT00005010435 => ':3625315:3625433:1:-1:-1:3625984:3626065:1:-1:-1:3632765:3632931:1:-1:-1:3633933:3634053:1:-1:0:3634262:3634349:1:0:1:3635169:3635269:1:1:0:3635958:3636155:1:0:-1',
  ENSPAGT00005010440 => ':3625315:3625433:1:-1:-1:3632765:3632931:1:-1:-1:3633933:3634053:1:-1:0:3634262:3634349:1:0:1:3635169:3635269:1:1:0:3635958:3636155:1:0:-1',
  ENSPAGT00005010941 => ':9996681:9999302:-1:-1:-1',
  ENSPAGT00005010944 => ':9996681:9999302:-1:-1:-1',
  ENSPAGT00005010947 => ':9996681:9999302:-1:-1:-1',
  ENSPAGT00005010952 => ':9996681:9999302:-1:-1:-1',
  ENSPAGT00005010958 => ':9996681:9999302:-1:-1:-1',
  ENSPAGT00005010980 => ':3594096:3594216:1:-1:1:3598836:3598950:1:1:2:3599689:3599883:1:2:2:3600616:3600833:1:2:1:3611765:3611946:1:1:0:3613030:3613211:1:0:2:3614089:3614314:1:2:0:3614393:3614551:1:0:0:3614624:3615739:1:0:0:3615822:3617263:1:0:-1',
  ENSPAGT00005010995 => ':3597241:3597481:1:-1:1:3598836:3598950:1:1:2:3599689:3599883:1:2:2:3600616:3600833:1:2:1:3611765:3611946:1:1:0:3613030:3613211:1:0:2:3614089:3614314:1:2:0:3614393:3614551:1:0:0:3614624:3615739:1:0:0:3615822:3617263:1:0:-1',
  ENSPAGT00005011019 => ':3597241:3597481:1:-1:1:3598836:3598950:1:1:2:3599689:3599883:1:2:2:3600616:3600833:1:2:1:3611765:3611946:1:1:0:3613030:3613211:1:0:2:3614089:3614314:1:2:0:3614393:3614551:1:0:0:3614624:3615739:1:0:0:3615822:3616082:1:0:0:3616151:3617263:1:0:-1',
  ENSPAGT00005011035 => ':3597241:3597481:1:-1:1:3598836:3598950:1:1:2:3599689:3599883:1:2:2:3600616:3600833:1:2:1:3611765:3611946:1:1:0:3613030:3613211:1:0:2:3614089:3614314:1:2:0:3614393:3614551:1:0:0:3614624:3614698:1:0:0:3615660:3615739:1:0:-1:3615822:3616082:1:-1:-1:3616151:3617288:1:-1:-1',
  ENSPAGT00005011166 => ':10005635:10006470:-1:0:2:10004907:10004928:-1:2:0',
  ENSPAGT00005011173 => ':10006507:10007158:-1:-1:1:10005321:10006145:-1:1:-1',
  ENSPAGT00005011597 => ':7754744:7754857:-1:-1:-1:7753278:7753492:-1:-1:1:7752773:7752881:-1:1:2:7752432:7752534:-1:2:0:7751395:7751478:-1:0:0:7750811:7751021:-1:0:1:7749658:7749760:-1:1:2:7748906:7748997:-1:2:1:7747315:7748674:-1:1:-1',
  ENSPAGT00005011603 => ':7753278:7753492:-1:-1:1:7752773:7752881:-1:1:2:7752432:7752534:-1:2:0:7751395:7751478:-1:0:0:7750811:7751021:-1:0:1:7749658:7749760:-1:1:2:7748906:7748997:-1:2:1:7747315:7748674:-1:1:-1',
  ENSPAGT00005011612 => ':7753688:7754018:-1:-1:2:7753278:7753492:-1:2:1:7752773:7752881:-1:1:2:7752432:7752534:-1:2:0:7751395:7751478:-1:0:0:7750811:7751021:-1:0:1:7749658:7749760:-1:1:2:7748906:7748997:-1:2:1:7747315:7748674:-1:1:-1',
  ENSPAGT00005011665 => ':7518388:7518490:-1:0:1:7517269:7517542:-1:1:2:7516240:7516421:-1:2:1:7514938:7515035:-1:1:0:7513792:7513959:-1:0:0:7513142:7513260:-1:0:2:7512380:7512472:-1:2:2:7512206:7512248:-1:2:0',
  ENSPAGT00005011677 => ':7518685:7519565:-1:-1:1:7517269:7517542:-1:1:2:7516240:7516421:-1:2:1:7514938:7515035:-1:1:0:7513792:7513959:-1:0:0:7513142:7513260:-1:0:2:7512235:7512472:-1:2:-1',
  ENSPAGT00005011683 => ':7515542:7515703:-1:-1:-1:7514938:7515035:-1:-1:0:7513792:7513959:-1:0:0:7513142:7513260:-1:0:2:7512235:7512472:-1:2:-1',
  ENSPAGT00005012474 => ':10003198:10003204:-1:0:1:10002607:10002749:-1:1:0:10000811:10000973:-1:0:1:10000039:10000106:-1:1:0',
  ENSPAGT00005012947 => ':3625315:3625433:1:-1:0:3625984:3626065:1:0:1:3629744:3629782:1:1:1:3630261:3630361:1:1:0:3632765:3632931:1:0:-1',
  ENSPAGT00005013164 => ':15633807:15633999:-1:-1:2:15633453:15633550:-1:2:1:15632347:15632575:-1:1:2:15631680:15631837:-1:2:1:15630777:15630963:-1:1:2:15628789:15629536:-1:2:-1',
  ENSPAGT00005013176 => ':15633807:15633999:-1:-1:-1:15633453:15633550:-1:-1:-1:15631680:15631837:-1:-1:1:15630777:15630963:-1:1:2:15628789:15629536:-1:2:-1',
  ENSPAGT00005013186 => ':15633807:15633999:-1:-1:2:15633453:15633550:-1:2:1:15632347:15632575:-1:1:2:15631680:15631837:-1:2:1:15630777:15630963:-1:1:2:15629857:15630143:-1:2:-1',
  ENSPAGT00005013386 => ':10016089:10016924:-1:0:2:10015361:10015382:-1:2:0',
  ENSPAGT00005013388 => ':10016961:10017612:-1:-1:1:10015961:10016599:-1:1:-1',
  ENSPAGT00005016129 => ':7760205:7760316:-1:-1:-1:7759786:7760121:-1:-1:1:7758015:7758095:-1:1:1:7757819:7757926:-1:1:1:7756164:7756274:-1:1:1:7754885:7755435:-1:1:-1',
  ENSPAGT00005016139 => ':7760378:7760420:-1:0:1:7759744:7760115:-1:1:1:7758887:7758972:-1:1:0',
  ENSPAGT00005016260 => ':9996786:9999197:1:0:0:9999439:9999486:1:0:0',
  ENSPAGT00005017149 => ':13652489:13653941:1:-1:0:13654536:13654758:1:0:1:13654924:13655143:1:1:2:13655543:13656665:1:2:-1',
);

my %transcript_coding_start = (
  ENSPAGT00005009094 => 7521145,
  ENSPAGT00005009105 => 7521145,
  ENSPAGT00005009363 => 13648692,
  ENSPAGT00005009369 => 13648692,
  ENSPAGT00005009377 => 13648250,
  ENSPAGT00005009805 => 15616727,
  ENSPAGT00005009808 => 15621141,
  ENSPAGT00005009856 => 10010727,
  ENSPAGT00005010431 => 3633997,
  ENSPAGT00005010435 => 3633997,
  ENSPAGT00005010440 => 3633997,
  ENSPAGT00005010941 => 9998455,
  ENSPAGT00005010944 => 9998455,
  ENSPAGT00005010947 => 9998455,
  ENSPAGT00005010952 => 9998455,
  ENSPAGT00005010958 => 9998455,
  ENSPAGT00005010980 => 3594201,
  ENSPAGT00005010995 => 3597442,
  ENSPAGT00005011019 => 3597442,
  ENSPAGT00005011035 => 3597442,
  ENSPAGT00005011166 => 10004907,
  ENSPAGT00005011173 => 10005559,
  ENSPAGT00005011597 => 7748577,
  ENSPAGT00005011603 => 7748577,
  ENSPAGT00005011612 => 7748577,
  ENSPAGT00005011665 => 7512206,
  ENSPAGT00005011677 => 7512307,
  ENSPAGT00005011683 => 7512307,
  ENSPAGT00005012474 => 10000039,
  ENSPAGT00005012947 => 3625389,
  ENSPAGT00005013164 => 15628990,
  ENSPAGT00005013176 => 15628990,
  ENSPAGT00005013186 => 15629858,
  ENSPAGT00005013386 => 10015361,
  ENSPAGT00005013388 => 10016013,
  ENSPAGT00005016129 => 7755326,
  ENSPAGT00005016139 => 7758887,
  ENSPAGT00005016260 => 9996786,
  ENSPAGT00005017149 => 13653117,
);

my %transcript_coding_end = (
  ENSPAGT00005009094 => 7539853,
  ENSPAGT00005009105 => 7539853,
  ENSPAGT00005009363 => 13651310,
  ENSPAGT00005009369 => 13651310,
  ENSPAGT00005009377 => 13651310,
  ENSPAGT00005009805 => 15623537,
  ENSPAGT00005009808 => 15628680,
  ENSPAGT00005009856 => 10024956,
  ENSPAGT00005010431 => 3636122,
  ENSPAGT00005010435 => 3636122,
  ENSPAGT00005010440 => 3636122,
  ENSPAGT00005010941 => 9998958,
  ENSPAGT00005010944 => 9998958,
  ENSPAGT00005010947 => 9998958,
  ENSPAGT00005010952 => 9998958,
  ENSPAGT00005010958 => 9998958,
  ENSPAGT00005010980 => 3616130,
  ENSPAGT00005010995 => 3616130,
  ENSPAGT00005011019 => 3617014,
  ENSPAGT00005011035 => 3615683,
  ENSPAGT00005011166 => 10006470,
  ENSPAGT00005011173 => 10006522,
  ENSPAGT00005011597 => 7753425,
  ENSPAGT00005011603 => 7753425,
  ENSPAGT00005011612 => 7753716,
  ENSPAGT00005011665 => 7518490,
  ENSPAGT00005011677 => 7518772,
  ENSPAGT00005011683 => 7514994,
  ENSPAGT00005012474 => 10003204,
  ENSPAGT00005012947 => 3632893,
  ENSPAGT00005013164 => 15633874,
  ENSPAGT00005013176 => 15631818,
  ENSPAGT00005013186 => 15633874,
  ENSPAGT00005013386 => 10016924,
  ENSPAGT00005013388 => 10016976,
  ENSPAGT00005016129 => 7760074,
  ENSPAGT00005016139 => 7760420,
  ENSPAGT00005016260 => 9999486,
  ENSPAGT00005017149 => 13655828,
);

my %transcripts_per_genes = (
  ENSPAGG00005004637 => 1,
  ENSPAGG00005004783 => 2,
  ENSPAGG00005005020 => 2,
  ENSPAGG00005005053 => 1,
  ENSPAGG00005005359 => 1,
  ENSPAGG00005005629 => 1,
  ENSPAGG00005005636 => 4,
  ENSPAGG00005005744 => 2,
  ENSPAGG00005005963 => 3,
  ENSPAGG00005006005 => 3,
  ENSPAGG00005006439 => 1,
  ENSPAGG00005006688 => 1,
  ENSPAGG00005006805 => 3,
  ENSPAGG00005006947 => 2,
  ENSPAGG00005008351 => 2,
  ENSPAGG00005008405 => 1,
  ENSPAGG00005008847 => 1,
);

my $db = $multi->get_DBAdaptor('core');
my %target_db = (
  -dbname => $db->dbc->dbname,
  -host   => $db->dbc->host,
  -port   => $db->dbc->port,
  -user   => $db->dbc->user,
  -pass   => $db->dbc->pass,
  -driver => $db->dbc->driver,
);

my $initial_gene_count = scalar(@{$db->get_GeneAdaptor->fetch_all});
standaloneJob(
	'Bio::EnsEMBL::Analysis::Hive::RunnableDB::CleanUTRs', # module
	{ # input param hash
    iid => $iid,
    source_db => \%target_db,
    suffix => 'test',
	},
  undef,
#  {
#    debug => 1,
#  },

);


my $genes = $db->get_GeneAdaptor->fetch_all;

cmp_ok(scalar(@$genes)/2, '==', $initial_gene_count, 'Checking we stored all the genes');
foreach my $gene (@$genes) {
  if ($gene->biotype eq 'protein_coding_test') {
    my $transcripts = $gene->get_all_Transcripts;
    cmp_ok(scalar(@$transcripts), '==', $transcripts_per_genes{$gene->stable_id}, 'Checking the number of transcripts in '.$gene->stable_id);
    foreach my $transcript (@$transcripts) {
      my $stable_id = $transcript->stable_id;
      cmp_ok($transcript->coding_region_start, '==', $transcript_coding_start{$stable_id}, "Checking the genomic coding start $stable_id");
      cmp_ok($transcript->coding_region_end, '==', $transcript_coding_end{$stable_id}, "Checking the genomic coding end $stable_id");
      my $id;
      foreach my $exon (@{$transcript->get_all_Exons}) {
        $id .= ':'.join(':', $exon->start, $exon->end, $exon->strand, $exon->phase, $exon->end_phase);
      }
      cmp_ok($id, 'eq', $transcript_hashkey{$stable_id}, "Checking transcript structure for $stable_id");
    }
  }
}

done_testing();

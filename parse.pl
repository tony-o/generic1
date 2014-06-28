#!/usr/bin/env perl
use lib 'lib';
use Parse qw<parse>;
use Parallel::ForkManager;
use Data::Dumper;
use sapnwrfc;
use v5.18;

my ($conn, $rfc, $structure, @structure);

SAPNW::Rfc->load_config;
$conn = SAPNW::Rfc->rfc_connect;
my $describer = $conn->function_lookup('CCMSBI_GET_ODS_STRUC');
my $rc        = $describer->create_function_call;
$rc->ODSNAME('ZRPA_O10');
eval {
  $rc->invoke;
};
#build array struct
map { push @structure, $_; } @{$rc->FIELDS};
say 'Fields: ' . scalar(@structure);

$rfc = $conn->function_lookup('RSDRI_ODSO_INSERT_RFC');

my $pm = Parallel::ForkManager->new($ARGV[0] || 40);
opendir DIR, './in';
while(my $file = readdir(DIR)){
  next if $file eq '.' || $file eq '..';
  my $pid = $pm->start and next;
  parse $rfc, "in/$file", @structure;
  $pm->finish;
}

$pm->wait_all_children; 

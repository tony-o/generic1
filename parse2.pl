#!/usr/bin/env perl
use lib 'lib';
use Parse2 qw<parse>;
use Parallel::ForkManager;
use SAP::Rfc;
use v5.18;

my ($rfc, $structure);

try {
  $rfc = SAP::Rfc->new(
    ASHOST => 'mosapwinbis',
    USER   => 'tonyo',
    PASS   => 'redrose',
    LANG   => 'EN',
    CLIENT => '100',
    SYSNR  => '00',
#    TRACE  => '0',
  );
  my $tmp = $rfc->discover('CCMSBI_GET_ODS_STRUC');
  $tmp->ODSNAME = 'ZRPA_O10';
  $rfc->callrfc($tmp);
  say 'rows: #' . $tmp->tab('FIELDS')->rowCount;
  say join("\n", @{$tmp->FIELDS});

};
my $pm = Parallel::ForkManager->new(10);
opendir DIR, './in';
while(my $file = readdir(DIR)){
  next if $file eq '.' || $file eq '..';
  my $pid = $pm->start and next;
  say "starting $file";
  parse $rfc, "in/$file";
  say "ending $file";
  $pm->finish;
}

$pm->wait_all_children; 

#!/usr/bin/env perl
use lib 'lib';
use Parse qw<parse>;
use Parallel::ForkManager;
use v5.18;

my $pm = Parallel::ForkManager->new(150);
opendir DIR, './in';
while(my $file = readdir(DIR)){
  next if $file eq '.' || $file eq '..';
  my $pid = $pm->start and next;
  say "starting $file";
  parse $file;
  say "ending $file";
  $pm->finish;
}

$pm->wait_all_children; 

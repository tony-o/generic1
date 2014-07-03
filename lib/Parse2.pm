#!/usr/bin/env perl

use lib 'lib';
use XML::LibXML::Reader;
use Try::Tiny;
use v5.18;

sub parse {
  my ($file) = @_;
  my $parser = XML::LibXML->new;
  my $dom    = $parser->parse_file($file);
   
  my $tender = 0;
  my $sale = 0;
  my $loyal = 0;
  my $tax = 0;
  for my $transaction ($dom->getElementsByTagName('Transaction')) {
    next if scalar(@{$transaction->getElementsByTagName('RetailTransaction')}) == 0 || scalar(@{$transaction->getElementsByTagName('RetailTransaction')->[0]->getElementsByTagName('LineItem')}) == 0;
    my $template = {
      BusinessDayDate     => $transaction->getElementsByTagName('BusinessDayDate')->[0]->textContent
      ,DocumentCurrency   => 'USD'
      ,RetailStoreID      => $transaction->getElementsByTagName('RetailStoreID')->[0]->textContent
      ,OperatorID         => $transaction->getElementsByTagName('OperatorID')->[0]->textContent
      ,OperatorName       => $transaction->getElementsByTagName('OperatorID')->[0]->getElementsByTagName('OperatorName')
      ,POSNumber          => $transaction->getElementsByTagName('WorkstationID')->[0]->textContent
      ,SequenceNumber     => ''
      ,EndDateTime        => substr($transaction->getElementsByTagName('EndDateTime')->[0]->textContent, index($transaction->getElementsByTagName('EndDateTime')->[0]->textContent, 'T') + 1)
      ,LoyaltyID          => ''
      ,MembershipID       => ''

      # LINE ITEM DATA #
      ,Material           => ''
      ,Quantity           => ''
      ,Price              => ''
      ,Discount           => ''
      ,TenderID           => ''
      ,QuantityType       => 'EA'
      ,PromotionID        => ''
      # PAYMENT DATA #
      ,EntryMethod        => ''
      ,PaymentMethod      => ''
      # PROMOTIONAL DATA #
      ,PromotionID        => ''
      ,RewardLevel        => ''
      ,RewardCategory     => ''
      ,PaymentDirection   => ''
    };
    try {
      for my $row (@{$transaction->getElementsByTagName('RetailTransaction')->[0]->getElementsByTagName('LineItem')}) {
        if (scalar @{$row->getElementsByTagName('acs:LoyaltyMembership')} > 0) {
          $template->{LoyaltyID}    = $row->getElementsByTagName('acs:LoyaltyMembership')->[0]->getElementsByTagName('acs:LoyaltyID')->[0]->textContent;
          $template->{MembershipID} = $row->getElementsByTagName('acs:LoyaltyMembership')->[0]->getElementsByTagName('acs:MembershipID')->[0]->textContent;
        }
      }
    };
    for my $line (@{$transaction->getElementsByTagName('RetailTransaction')->[0]->getElementsByTagName('LineItem')}) {
      if (scalar(@{$line->getElementsByTagName('Tender')}) > 0) {
        my $cp = {%$template};
        $cp->{SequenceNumber} = $line->getElementsByTagName('SequenceNumber')->[0]->textContent;
        $cp->{Price} = $line->getElementsByTagName('SequenceNumber')->[0]->textContent;
        $cp->{Material} = $line->getElementsByTagName('SequenceNumber')->[0]->textContent;
        $cp->{TenderID} = $line->getElementsByTagName('SequenceNumber')->[0]->textContent;
        $cp->{PaymentDirection} = $cp->{PRICE} > 0 ? 'O' : 'I';
        $tender++;
      }
      if (scalar(@{$line->getElementsByTagName('Sale')}) > 0) {
        my $cp                = {%$template};
        $cp->{SequenceNumber} = $line->getElementsByTagName('SequenceNumber')->[0]->textContent;
        $cp->{Material}       = $line->getElementsByTagName('Sale')->[0]->getElementsByTagName('ItemID')->[0]->textContent || '';
        $cp->{Quantity}       = $line->getElementsByTagName('Sale')->[0]->getElementsByTagName('Quantity')->[0]->textContent;
        $cp->{Price}          = $line->getElementsByTagName('Sale')->[0]->getElementsByTagName('ExtendedAmount')->[0]->textContent;
        $cp->{Discount}       = $line->getElementsByTagName('Sale')->[0]->getElementsByTagName('ExtendedDiscountAmount')->[0]->textContent;
        $cp->{EntryMethod}    = $line->getElementsByTagName('EntryMethod')->[0]->textContent if scalar(@{$line->getElementsByTagName('EntryMethod')}) > 0;
        $sale++;
      }
      if($line->getElementsByTagName('Tax')->[0]){
        my $cp                = {%$template};
        $cp->{SequenceNumber} = $line->getElementsByTagName('SequenceNumber')->[0]->textContent;
        $cp->{TaxableAmount}  = $line->getElementsByTagName('Tax')->[0]->getElementsByTagName('TaxableAmount')->[0]->textContent;
        $cp->{Price}          = $line->getElementsByTagName('Tax')->[0]->getElementsByTagName('Amount')->[0]->textContent;
        $cp->{Material}       = 'TAX';
        $cp->{EntryMethod}    = $line->getElementsByTagName('EntryMethod')->[0] || '';
        $tax++;
      }
      if($line->getElementsByTagName('LoyaltyReward')->[0] && ($line->getElementsByTagName('LoyaltyReward')->[0]->{'acs:RewardType'} eq 'PercentOff' || $line->getElementsByTagName('LoyaltyReward')->[0]->{'acs:RewardType'} eq 'AmountOff')){
        my $cp                = {%$template};
        $cp->{SequenceNumber} = $line->getElementsByTagName('SequenceNumber')->[0]->textContent;
        $cp->{Material}       = $line->getElementsByTagName('LoyaltyReward')->[0]->getElementsByTagName('acs:RewardBasis')->[0]->getElementsByTagName('acs:ItemID')->[0]->textContent || '';
        $cp->{Discount}       = $line->getElementsByTagName('LoyaltyReward')->[0]->getElementsByTagName('acs:ExtendedRewardAmount')->[0]->textContent;
        $cp->{RewardID}       = $line->getElementsByTagName('LoyaltyReward')->[0]->getElementsByTagName('PromotionID')->[0]->textContent;
        $cp->{RewardLevel}    = $line->getElementsByTagName('LoyaltyReward')->[0]->getElementsByTagName('acs:RewardLevel')->[0]->textContent;
        $cp->{RewardCategory} = $line->getElementsByTagName('LoyaltyReward')->[0]->getElementsByTagName('acs:RewardCategory')->[0]->textContent;
        $cp->{EntryMethod}    = $line->getElementsByTagName('EntryMethod')->[0] || '';
        $loyal++;
      }
    }
  }
}

420;

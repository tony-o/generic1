#!/usr/bin/perl -w 
use XML::Hash;
use Try::Tiny;
use Data::Dumper;
use Cwd qw(realpath);
use Digest::MD5 qw(md5_hex);

my $csvrows = {
   1   => 'BusinessDayDate'
  ,2   => 'DocumentCurrency'
  ,3   => 'RetailStoreID'
  ,4   => 'OperatorID'
  ,5   => 'OperatorName'
  ,6   => 'POSNumber'
  ,7   => 'SequenceNumber'
  ,8   => 'EndDateTime'
  ,9   => 'LoyaltyID'
  ,10  => 'MembershipID'
  ,11  => 'Material'
  ,12  => 'Quantity'
  ,13  => 'Price'
  ,14  => 'Discount'
  ,15  => 'TenderID'
  ,16  => 'QuantityType'
  ,17  => 'PromotionID'
  ,18  => 'EntryMethod'
  ,19  => 'PaymentMethod'
  ,20  => 'PromotionID'
  ,21  => 'RewardLevel'
  ,22  => 'RewardCategory'
  ,23  => 'PaymentDirection'
};

sub parse {
  my ($file) = @_;

  my $parser = XML::Hash->new();
  my (@output, $xml, $rows, $row, $transaction, $csvrows, $mydir);

  $mydir = substr(realpath($0), 0, rindex(realpath($0), '/')) . '/';
#  open LOAD, '>' . $mydir . "/out/$file.csv";


  sub dumprow{
    return;
    my $rowref = shift;
    local *OFILE = shift;
    my $count = 0;
    while($count++ <= scalar(keys %{$csvrows})){
      next unless defined $csvrows->{$count};
      if($rowref == 1){
        print OFILE $csvrows->{$count} . ', ';
        next;
      }
      if(defined $csvrows->{$count}){
        print LOAD ((defined $rowref->{$csvrows->{$count}} ? '"' . $rowref->{$csvrows->{$count}} . '"' : '') . ', ');
      }
    }
    print LOAD "\n" unless $rowref == 1;
    return;
  };

  open FILE, $mydir . '/in/' . $file or die "Couldn't find /in/$file \n";
  $xml = $parser->fromXMLStringtoHash(<FILE>)->{POSLog}->{Transaction};
  close FILE;

  dumprow(1, *OFILE);
  try{
    foreach $transaction (@{$xml}){
      if(!defined $transaction->{RetailTransaction} || !defined $transaction->{RetailTransaction}->{LineItem}){
        next;
      }
      try{
        my $template = {
          BusinessDayDate     => $transaction->{BusinessDayDate}->{text}
          ,DocumentCurrency   => 'USD'
          ,RetailStoreID      => $transaction->{RetailStoreID}->{text}
          ,OperatorID         => $transaction->{OperatorID}->{text}
          ,OperatorName       => $transaction->{OperatorID}->{OperatorName}
          ,POSNumber          => $transaction->{WorkstationID}->{text}
          ,SequenceNumber     => ''
          ,EndDateTime        => substr($transaction->{EndDateTime}->{text}, index($transaction->{EndDateTime}->{text}, 'T') + 1)
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

        #UPDATE THE STATIC VALS
        foreach $row (@{$transaction->{RetailTransaction}->{LineItem}}){
          if($row->{'acs:LoyaltyMembership'}){
            $template->{LoyaltyID} = $row->{'acs:LoyaltyMembership'}->{'acs:LoyaltyID'}->{text};
            $template->{MembershipID} = $row->{'acs:LoyaltyMembership'}->{'acs:MembershipID'}->{text};
          }
        }
        foreach $row (@{$transaction->{RetailTransaction}->{LineItem}}){
          if($row->{Tender}){
            my $cp                = {%$template};
            $cp->{SequenceNumber} = $row->{SequenceNumber}->{text};
            $cp->{Price}          = $row->{Tender}->{Amount}->{text} * -1;
            $cp->{Material}       = $row->{Tender}->{TenderType};
            $cp->{TenderID}       = $row->{Tender}->{TenderID}->{text};
            $cp->{PaymentDirection} = 'I';
            if($cp->{Price} > 0){
              $cp->{PaymentDirection} = 'O';
            }
            dumprow($cp, *OFILE);
          }
          if($row->{Sale}){
            my $cp                = {%$template};
            $cp->{SequenceNumber} = $row->{SequenceNumber}->{text};
            $cp->{Material}       = $row->{Sale}->{ItemID}->{text} || '';
            $cp->{Quantity}       = $row->{Sale}->{Quanity};
            $cp->{Price}          = $row->{Sale}->{ExtendedAmount}->{text};
            $cp->{Discount}       = $row->{Sale}->{ExtendedDiscountAmount}->{text};
            $cp->{EntryMethod}    = $row->{EntryMethod};
            dumprow($cp, *OFILE);
          }
          if($row->{Tax}){
            my $cp                = {%$template};
            $cp->{SequenceNumber} = $row->{SequenceNumber}->{text};
            $cp->{TaxableAmount}  = $row->{Tax}->{TaxableAmount}->{text};
            $cp->{Price}          = $row->{Tax}->{Amount}->{text};
            $cp->{Material}       = 'TAX';
            $cp->{EntryMethod}    = $row->{EntryMethod} || '';
            dumprow($cp, *OFILE);
          }
          if($row->{LoyaltyReward} && ($row->{LoyaltyReward}->{'acs:RewardType'} eq 'PercentOff' || $row->{LoyaltyReward}->{'acs:RewardType'} eq 'AmountOff')){
            my $cp                = {%$template};
            $cp->{SequenceNumber} = $row->{SequenceNumber}->{text};
            $cp->{Material}       = $row->{LoyaltyReward}->{'acs:RewardBasis'}->{'acs:ItemID'} || '';
            $cp->{Discount}       = $row->{LoyaltyReward}->{'acs:ExtendedRewardAmount'}->{text};
            $cp->{RewardID}       = $row->{LoyaltyReward}->{PromotionID};
            $cp->{RewardLevel}    = $row->{LoyaltyReward}->{'acs:RewardLevel'};
            $cp->{RewardCategory} = $row->{LoyaltyReward}->{'acs:RewardCategory'};
            $cp->{EntryMethod}    = $row->{EntryMethod} || '';
            dumprow($cp, *OFILE);
          }
        }
      }catch{ 

      }
    }
  }catch{

  };
#  close LOAD;
}

420;

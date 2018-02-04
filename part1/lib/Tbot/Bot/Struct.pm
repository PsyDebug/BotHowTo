package Tbot::Bot::Struct;
use Tbot::Bot::Data;

my $api=Tbot::Bot::Data->new();

sub new { bless {}, shift }

sub percentTop(){
    my ($class,$self,$coin,$top)=@_;
    my %value=%{$api->returnTicker($self)};
    my %pairs;
        for my $pair (keys %value){
            my $percent=$value{$pair}{'percentChange'}*100;
            $pairs{$pair}=$percent;
        }
    my $res="";
    my $i=0;
        foreach my $pc (sort { $pairs{$b} <=> $pairs{$a} } keys %pairs){
                    if($pc=~/$coin\_/ and $i<$top){
                        my $proc=sprintf("%.2f",$pairs{$pc});
                        $res.="$pc  $proc  $value{$pc}{'last'}\n";
                        $i++;
                    }
        }
    return $res;
}

sub volumeTop(){
    my ($class,$self,$coin,$top)=@_;
    my %value=%{$api->returnTicker($self)};
    my %pairs;
        for my $pair (keys %value){
            my $volume=$value{$pair}{'baseVolume'};
            $pairs{$pair}=$volume;
        }
    my $res="";
    my $i=0;
        foreach my $pc (sort { $pairs{$b} <=> $pairs{$a} } keys %pairs){
                    if($pc=~/$coin\_/ and $i<$top){
                        $res.="$pc  $pairs{$pc}  $value{$pc}{'last'}\n";
                        $i++;
                    }
        }
    return $res;
}


1;

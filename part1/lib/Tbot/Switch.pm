package Tbot::Switch;

use strict;
use Tbot::Bot::Struct;
use Tbot::Bot::Sender;
use Data::Dumper;

my $sender=Tbot::Bot::Sender->new();
my $struct=Tbot::Bot::Struct->new();

sub new { bless {}, shift }

sub start {
    my ($class,$self,$id)=@_;
    $sender->send_msg($self,$id,"Hello!");
}

sub percent {
    my ($class,$self,$id)=@_;
    my $res=$struct->percentTop($self,"BTC",10);
    $sender->send_msg($self,$id,$res);
}

sub volume {
    my ($class,$self,$id)=@_;
    my $res=$struct->volumeTop($self,"BTC",10);
    $sender->send_msg($self,$id,$res);
}


sub AUTOLOAD {
    my ($class,$self,$id)=@_;
    $sender->send_msg($self,$id,"unknown command");
}

1;

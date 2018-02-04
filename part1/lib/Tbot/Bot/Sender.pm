package Tbot::Bot::Sender;
use Data::Dumper;


my $api_url="https://api.telegram.org/";

sub new { bless {}, shift }


sub send_msg {
    my ($class,$self,$id,$text)=@_;
    $text=$text || "try later";
    my $url=$api_url.$self->confapp->{config}->{token}."/sendMessage?chat_id=$id&text=$text";
    my $req=$self->ua->get($url);
    if (my $err=$req->error) {$self->loger->error("[send_msg] $url", "$err->{code} response: $err->{message}");}
    else {$self->loger->debug("[send_msg] $url", $req->res->body);}

}

1;

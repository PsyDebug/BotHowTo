package Tbot::Controller::Callback;
use Mojo::Base 'Mojolicious::Controller';

sub index {
    my $self = shift;
    my $json = $self->req->body;
    my $dath  = $self->mjson->($json);
    my %getmsg;
    $self->loger->debug("[Callback]", $json);
    $getmsg{'text'}=$dath->{'message'}->{'text'};
    $getmsg{'id'}=$dath->{'message'}->{'from'}->{'id'};
    $getmsg{'text'}=~s/[\\\/\`\"\&\@]//sg;
    $self->loger->info("[Callback] text : $getmsg{'text'} id: $getmsg{'id'}");
    $self->bot_input->${\$getmsg{'text'}}($self,$getmsg{'id'});
    $self->render(text => "You can do it!", status => 200);
}

1;

package Tbot::Bot::Data;

my $apiUrl='https://poloniex.com/public';

sub new { bless {}, shift }

#===METHODS===

sub returnTicker() {
    my ($class,$self) = @_;
    my $url=$apiUrl.'?command='.'returnTicker';
    my $value=$self->ua->get($url)->res->json;
    return $value;
}

1;

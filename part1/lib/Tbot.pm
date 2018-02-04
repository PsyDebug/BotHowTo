package Tbot;
use Mojo::Base 'Mojolicious';
use Tbot::Configure;
use Data::Dumper;
use Tbot::Switch;
use JSON::XS;

has agent => sub {Mojo::UserAgent->new};

has mjson => sub {
    return sub {decode_json shift};
};

has botinput => sub {Tbot::Switch->new};

has conf => sub {
		my $config = Tbot::Configure->new({});
		my $confapp={};
		$confapp->{config} = $config->config();
		return $confapp;
};

has loger => sub {Mojo::Log->new(path => 'log/tbot.log', level => 'debug')};

sub startup {
    my $self = shift;
    $self->config(hypnotoad => {listen => ['http://*:3000'],pid_file => 'hypno.pid'});
    $self->helper(mjson => sub { $self->app->mjson});
    $self->helper(confapp => sub { $self->app->conf });
    $self->helper(ua => sub { $self->app->agent });
    $self->helper(loger => sub { $self->app->loger});
    $self->helper(bot_input => sub { $self->app->botinput});
    my $r = $self->routes;
    $r->post('/callback/'.$self->confapp->{config}->{callback_url})->to('callback#index');
}

1;

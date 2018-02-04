package Tbot::Configure;

use utf8;
use strict;
use File::Basename;

my $dirname = dirname(__FILE__);
my $conf_filename = $dirname.'/../../etc/telegram.conf';

sub new {
    my ($class, $options) = @_;
    my $self = bless $options => $class;
    return $self;
}

sub config {
    my $self = shift;
    my $file = shift || $conf_filename;
    open CONF, $file or die "Can't open file $file: $!";
    my $conf = {};
    while ( my $line = <CONF> ) {
 	    if ($line =~ /^([A-z]*)\s*(.*)$/) {
   	        $conf->{ $1 } = $2 if ($1);
   	  	}
   	}
    return $conf;
}

1;

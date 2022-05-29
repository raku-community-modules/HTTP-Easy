# HTTP::Easy::PSGI
# A PSGI application HTTP Server

use HTTP::Easy;
use HTTP::Status;
use PSGI;

unit class HTTP::Easy::PSGI does HTTP::Easy;

has $.p6sgi                = True;
has $.psgi-classic = False;
has $.errors             = $*ERR;
has $!app;

method app($app) {
    $!app = $app;
}

method handler() {
    ## First, let's add any necessary PSGI variables.
    populate-psgi-env(
      %.env, 
      :input($.body), 
      :errors($.errors),
      :errors-buffered,
      :p6sgi($.p6sgi),
      :psgi-classic($.psgi-classic),
    );

    my $result;
    if $!app ~~ Callable {
        $result = $!app(%.env);
    }
    elsif $!app.can('handle') {
        $result = $!app.handle(%.env);
    }
    else {
        die "Invalid {self.WHAT} application.";
    }
    my $protocol := $.http-protocol;
    encode-psgi-response($result, :$protocol, :nph);
}

method handle($app) {
    self.app($app);
    self.run
}

# vim: expandtab shiftwidth=4

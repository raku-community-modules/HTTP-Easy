## HTTP::Easy::PSGI
## A PSGI application HTTP Server

use HTTP::Easy;
use HTTP::Status;
use PSGI;

unit class HTTP::Easy::PSGI:ver<3.0.0>:auth<http://supernovus.github.com/>
does HTTP::Easy;

has $.psgi-classic = False;
has $.errors = $*ERR;
has $!app;

method app ($app)
{
  $!app = $app;
}

method handler
{
  ## First, let's add any necessary PSGI variables.
  populate-psgi-env(
    %.env, 
    :input($.body), 
    :errors($.errors),
    :errors-buffered,
    :psgi-classic($.psgi-classic),
  );

  my $result;
  if $!app ~~ Callable
  {
    $result = $!app(%.env);
  }
  elsif $!app.can('handle')
  {
    $result = $!app.handle(%.env);
  }
  else
  {
    die "Invalid {self.WHAT} application.";
  }
  my $protocol = $.http-protocol;
  my $output = encode-psgi-response($result, :$protocol, :nph);
  return $output;
}

method handle ($app)
{
  self.app($app);
  return self.run;
}


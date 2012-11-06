## HTTP::Easy::PSGI
## A PSGI application HTTP Server

use HTTP::Easy;

class HTTP::Easy::PSGI:ver<2.1.3>:auth<http://supernovus.github.com/> 
does HTTP::Easy;

use HTTP::Status;

constant $CRLF = "\x0D\x0A";

has $!app;

method app ($app) 
{
  $!app = $app;
}

method handler 
{
  ## First, let's add any necessary PSGI variables.
  %.env<psgi.version>      = [1,0];
  %.env<psgi.url_scheme>   = 'http'; ## TODO: detect this.
  %.env<psgi.multithread>  = False;
  %.env<psgi.multiprocess> = False;
  %.env<psgi.input>        = $.body;
  %.env<psgi.errors>       = $*ERR; ## TODO: allow override on this.
  %.env<psgi.run_once>     = False;
  %.env<psgi.nonblocking>  = False; ## Allow when NBIO.
  %.env<psgi.streaming>    = False; ## Eventually?
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
  my $message = get_http_status_msg($result[0]);
  my $output = $.http-protocol ~ ' ' ~ $result[0] ~ " $message$CRLF";
  for @($result[1]) -> $header 
  {
    $output ~= $header.key ~ ': ' ~ $header.value ~ $CRLF;
  }
  my @body = $result[2];
  my $body;
  for @body -> $segment
  {
    if ! $body.defined
    {
      $body = $segment;
    }
    elsif $body ~~ Buf
    {
      if $segment ~~ Buf
      {
        $body ~= $segment;
      }
      else
      {
        $body ~= $segment.Str.encode;
      }
    }
    else
    {
      $body ~= $segment;
    }
  }
  if $body ~~ Buf
  {
    $output = ($output~$CRLF).encode ~ $body;
  }
  else
  {
    $output ~= $CRLF ~ $body;
  }
  return $output;
}

method handle ($app) 
{
  self.app($app);
  return self.run;
}


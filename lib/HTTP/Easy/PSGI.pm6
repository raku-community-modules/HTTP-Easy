## HTTP::Easy::PSGI
## A PSGI application HTTP Server

use HTTP::Easy;
use HTTP::Status;

class HTTP::Easy::PSGI:ver<2.1.3>:auth<http://supernovus.github.com/> 
does HTTP::Easy;

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
  my $protocol = $.http-protocol;
  my $output = encode-psgi-response($result, :$protocol, :nph);
  return $output;
}

method handle ($app) 
{
  self.app($app);
  return self.run;
}

## Encode a PSGI-compliant response.
## The Code must be a Str or Int representing the numeric HTTP status code.
## Headers can be an Array of Pairs, or a Hash.
## Body can be an Array, a Str or a Buf.
multi sub encode-psgi-response (
  $code, $headers, $body,                      ## Required parameters.
  Bool :$nph, :$protocol=DEFAULT_PROTOCOL      ## Optional parameters.
) is export {
  my $output;
  my $message = get_http_status_msg($code);
  if $nph {
    $output = "$protocol $code $message" ~ CRLF;
  }
  else {
    $output = "Status: $code $message" ~ CRLF;
  }
  my @headers;
  if $headers ~~ Array {
    @headers = @$headers;
  }
  elsif $headers ~~ Hash {
    @headers = $headers.pairs;
  }
  for @headers -> $header {
    if $header !~~ Pair { warn "invalid PSGI header found"; next; }
    $output ~= $header.key ~ ': ' ~ $header.value ~ CRLF;
  }
  $output ~= CRLF; ## Finished with headers.
  my @body;
  if $body ~~ Array {
    @body = @$body;
  }
  else {
    @body = $body;
  }
  for @body -> $segment {
    if $segment ~~ Buf {
      if $output ~~ Buf {
        $output ~= $segment;
      }
      else {
        $output = $output.encode ~ $segment;
      }
    }
    else {
      if $output ~~ Buf {
        $output ~= $segment.Str.encode;
      }
      else {
        $output ~= $segment.Str;
      }
    }
  }
  return $output;
}

## A version that takes the traditional Array of three elements,
## and uses them as the positional parameters for the above version.
multi sub encode-psgi-response (
  @response,
  Bool :$nph, :$protocol=DEFAULT_PROTOCOL
) is export {
  encode-psgi-response(|@response, :$nph, :$protocol);
}


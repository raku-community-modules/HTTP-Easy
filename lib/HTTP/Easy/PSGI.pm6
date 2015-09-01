## HTTP::Easy::PSGI
## A PSGI application HTTP Server

use HTTP::Easy;
use HTTP::Status;

unit class HTTP::Easy::PSGI:ver<3.0.0>:auth<http://supernovus.github.com/>
does HTTP::Easy;

has $!app;

method app ($app)
{
  $!app = $app;
}

method handler
{
  ## First, let's add any necessary PSGI variables.
  %.env<p6sgi.version>         = Version.new('0.4.Draft');
  %.env<p6sgi.url-scheme>      = 'http'; ## TODO: detect this.
  %.env<p6sgi.multithread>     = False;
  %.env<p6sgi.multiprocess>    = False;
  %.env<p6sgi.input>           = $.body;
  %.env<p6sgi.input.buffered>  = False;
  %.env<p6sgi.errors>          = $*ERR; ## TODO: allow override on this.
  %.env<p6sgi.errors.buffered> = True;
  %.env<p6sgi.run-once>        = False;
  %.env<p6sgi.nonblocking>     = False; ## Allow when NBIO.
  %.env<p6sgi.encoding>        = 'UTF-8';
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
  Int(Any) $code, $headers, Supply(Any) $body, ## Required parameters.
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
  $body.tap(-> $segment {
    if $segment ~~ Buf {
      if $output ~~ Buf {
        $output ~= $segment;
      }
      else {
        $output = $output.encode('UTF-8') ~ $segment;
      }
    }
    else {
      if $output ~~ Buf {
        $output ~= $segment.Str.encode('UTF-8');
      }
      else {
        $output ~= $segment.Str;
      }
    }
  });
  $body.wait;
  return $output;
}

multi sub encode-psgi-response (
  Promise(Any) $p,
  Bool :$nph, :$protocol=DEFAULT_PROTOCOL
) is export {
  encode-psgi-response($p.result, :$nph, :$protocol);
}

## A version that takes the traditional Array of three elements,
## and uses them as the positional parameters for the above version.
multi sub encode-psgi-response (
  @response,
  Bool :$nph, :$protocol=DEFAULT_PROTOCOL
) is export {
  encode-psgi-response(|@response, :$nph, :$protocol);
}

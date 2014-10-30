## A simple HTTP Daemon role. Inspired by HTTP::Server::Simple
## See HTTP::Easy::PSGI as the default daemon class implementation.

role HTTP::Easy:ver<2.1.3>:auth<http://supernovus.github.com/>;

use HTTP::Status;

has Int $.port   = 8080;
has Str $.host   = 'localhost';
has Bool $.debug = False;
has $!listener;
has $.connection;          ## To be populated by accept().
has %.env;                 ## The environment, generated by run().
has $.http-protocol;       ## The HTTP version being used.
has $.body;                ## Any request body, populated by run().

## If set to true, we will read the body even if there is no CONTENT_LENGTH.
has Bool $.always-get-body = False;

constant CRLF = "\x0D\x0A\x0D\x0A";
constant DEFAULT_PROTOCOL = 'HTTP/1.0';

## We're using DateTime.new(time) instead of DateTime.now()
## Because the current DateTime messes up the user's local timezone
## if they are in a negative offset, which totally screws up the reported
## time, so we are forcing UTC instead.
sub message ($message) 
{
  my $timestamp = DateTime.new(time).Str;
  note "[$timestamp] $message";
}

method connect (:$port=$.port, :$host=$.host)
{
  $!listener = IO::Socket::INET.new(
    :localhost($host),
    :localport($port),
    :listen(1),
    :input-line-separator(CRLF)
  );
}

method run 
{
  if %*ENV<HTTP_EASY_DEBUG> :exists
  {
    $!debug = ?%*ENV<HTTP_EASY_DEBUG>;
  }
  if ! $!listener { self.connect; }
  message('Started HTTP server.');
  self.pre-connection;
  while $!connection = $!listener.accept 
  {
    if $.debug { message("Client connection received."); }
    self.on-connection;

    my $first-chunk;
    my $msg-body-pos;

    while my $t = $!connection.recv( :bin ) {
        if $first-chunk.defined {
            $first-chunk = $first-chunk ~ $t;
        } else {
            # overwhelmingly often (for simple GET requests, for example) we'll
            # get all data in one run through this loop.
            $first-chunk = $t;
        }

        # Find the header/body separator in the chunk, which means we can parse
        # the header seperately and are able to figure out the
        # correct encoding of the body.

        my int $look_position = 0;
        my int $end_of_buffer = $first-chunk.elems;

        while $look_position < $end_of_buffer - 3 {
            if $first-chunk.at_pos($look_position) == 13 && $first-chunk.at_pos($look_position + 1) == 10
               && $first-chunk.at_pos($look_position + 2) == 13 && $first-chunk.at_pos($look_position + 3) == 10 {
                $msg-body-pos = $look_position + 2;
                last;
            } else {
                $look_position = $look_position + 1;
            }
        }

        last if $msg-body-pos;
    }
    $!body = $first-chunk.subbuf($msg-body-pos + 2);

    my $preamble = $first-chunk.decode('ascii').substr(0, $msg-body-pos);
    if $.debug 
    { 
      message("Read preamble:\n$preamble\n--- End of preamble.");
    }
    ## End of work around.
    my @headers = $preamble.split("\r\n");
    my $request = @headers.shift;
    unless defined $request
    {
      if $.debug { message("Client connection lost."); }
      $!connection.close;
      next;
    }
    message($request);
    
    if $.debug { message("Finished parsing headers: "~@headers.perl); }
    my ($method, $uri, $protocol) = $request.split(/\s/);
    if (!$protocol) { $protocol = DEFAULT_PROTOCOL; }
    unless $method eq 'GET' | 'POST' | 'HEAD' | 'PUT' | 'DELETE'
    { 
      $!connection.send(self.unhandled-method);
      $!connection.close;
      next;
    }
    $!http-protocol = $protocol;
    %!env = (); ## Delete the previous hash.
    my ($path, $query) = $uri.split('?', 2);
    $query //= '';
    ## First, let's add our "known" headers.
    %.env<SERVER_PROTOCOL> = $protocol;
    %.env<REQUEST_METHOD> = $method;
    %.env<QUERY_STRING> = $query;
    %.env<PATH_INFO> = $path;
    %.env<REQUEST_URI> = $uri;
    %.env<SERVER_NAME> = $.host;
    %.env<SERVER_PORT> = $.port;
    ## Next, let's add HTTP request headers.
    for @headers -> $header
    {
      my ($key, $value) = $header.split(': ');
      if defined $key and defined $value {
        $key ~~ s:g/\-/_/;
        $key .= uc;
        $key = 'HTTP_' ~ $key unless $key eq any(<CONTENT_LENGTH CONTENT_TYPE>);
        if %!env{$key} :exists {
          %!env{$key} ~= ", $value";
        }
        else {
          %!env{$key} = $value;
        }
      }
    }

    if %.env<CONTENT_LENGTH> :exists
    { ## Use CONTENT_LENGTH to determine the length of data to read.
      if %.env<CONTENT_LENGTH>
      {
        while %.env<CONTENT_LENGTH> > $!body.bytes {
          $!body ~= $!connection.recv(%.env<CONTENT_LENGTH> - $!body.bytes, :bin);
        }
#       if $.debug { message("Got body: "~$!body.decode); }
      }
    }
    elsif $.always-get-body
    {
      ## No content length. Keep reading until no data is sent.
      while my $read = $!connection.recv(:bin)
      {
        $!body ~= $read;
      }
    }

    ## Call the handler. 
    ##
    ## If it returns a defined value, it is assumed to be a valid HTTP 
    ## response, in the form of a Str(ing), a Buf, or an object that
    ## can be stringified.
    ##
    ## If it returns an undefined value, we assume the handler
    ## sent the response to the client directly, and end the session.
    my $res = self.handler;
    if $res.defined 
    {
      if $res ~~ Buf
      {
        $!connection.write($res);
      }
      else
      {
        $!connection.send($res.Str);
      }
    }
    $!connection.close;
    self.closed-connection;
  }
  self.finish-connection;
}

## Stub methods. Replace with your own.
method pre-connection      {}; ## Runs prior to waiting for connection.
method on-connection       {}; ## Runs at the beginning of each connection.
method closed-connection   {}; ## Runs after closing each connection.
method finished-connection {}; ## Runs when the wait loop is ended.

## The handler method, this MUST be defined in your class.
method handler {...};

## Feel free to override this in your class.
method unhandled-method
{
  my $status  = 501;
  my $message = get_http_status_msg($status);
  return "$.http-protocol $status $message";
}


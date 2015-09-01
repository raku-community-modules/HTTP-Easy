#!/usr/bin/env perl6

BEGIN { @*INC.unshift: './lib'; }

use HTTP::Easy::PSGI;

my $app = sub (%env) {
  my $name = %env<QUERY_STRING> || "World";
  start {
      [ 200, [ 'Content-Type' => 'text/plain' ], [ "Hello $name" ] ];
  }
}

## Add :debug for more detailed output to STDERR.
my $server = HTTP::Easy::PSGI.new(); # :debug
$server.app($app);
$server.run;

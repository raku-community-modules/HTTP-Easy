#!/usr/bin/env perl6

BEGIN { @*INC.unshift: './lib'; }

use HTTP::Easy::PSGI;

my $app = sub (%env) {
  return [ 200, [ 'Content-Type' => 'text/plain' ], [ "Hello World" ] ];
}

## We are using :debug for more detailed output to STDERR.
my $server = HTTP::Easy::PSGI.new(:debug);
$server.app($app);
$server.run;

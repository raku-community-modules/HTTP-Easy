#!/usr/bin/env perl6

BEGIN { @*INC.unshift: './lib'; }

use HTTP::Easy::PSGI;

my $app = sub (%env) {
  return [ 200, [ 'Content-Type' => 'text/plain' ], [ "Hello World" ] ];
}

my $server = HTTP::Easy::PSGI.new;
$server.app($app);
$server.run;

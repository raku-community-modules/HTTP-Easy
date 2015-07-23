use v6;

BEGIN { @*INC.push('lib') };

use Test;

plan 2;

use HTTP::Easy;
ok 1, "'use HTTP::Easy' worked!";

use HTTP::Easy::PSGI;
ok 1, "'use HTTP::Easy::PSGI' worked!";
[![Actions Status](https://github.com/raku-community-modules/HTTP-Easy/actions/workflows/test.yml/badge.svg)](https://github.com/raku-community-modules/HTTP-Easy/actions)

NAME
====

HTTP::Easy - HTTP servers made easy, including PSGI

SYNOPSIS
========

```raku
use HTTP::Easy;
```

DESCRIPTION
===========

Raku libraries to make HTTP servers easily. 

This was inspired by `HTTP::Server::Simple`, but has a very different internal API, and extended functionality. It's been designed to work well with the `Web::App` and `SCGI` libraries.

HTTP::Easy
----------

A role to build HTTP daemon classes with. This provides the framework for parsing HTTP connections.

HTTP::Easy::PSGI
----------------

A class consuming the `HTTP::Easy` role. This builds a PSGI environment, and passes it onto a handler. The handler must return a `PSGI` response:

```raku
[ $status, @headers, @body ]
```

This can be used as an engine in the `Web::App` library.

Example
-------

```raku
use HTTP::Easy::PSGI;
my $http = HTTP::Easy::PSGI.new(:port(8080));

my $app = sub (%env) {
    my $name = %env<QUERY_STRING> || "World";
    [ 200, [ 'Content-Type' => 'text/plain' ], [ "Hello $name" ] ]
}

$http.handle($app);
```

TODO
====

Implement HTTP/1.1 features such as Transfer-Encoding, etc.

AUTHOR
======

Timothy Totten

COPYRIGHT AND LICENSE
=====================

Copyright 2011 - 2017 Timothy Totten

Copyright 2018 - 2022 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.


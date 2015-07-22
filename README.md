# HTTP::Easy

[![Build Status](https://travis-ci.org/supernovus/perl6-http-easy.svg?branch=master)](https://travis-ci.org/supernovus/perl6-http-easy)

## Introduction

Perl 6 libraries to make HTTP servers easily. 

This was inspired by HTTP::Server::Simple, but has a very different internal
API, and extended functionality. It's been designed to work well with my
own Web::App and SCGI libraries. Also see my HTTP::Client library if you
are looking for an HTTP client rather than an HTTP server.

## HTTP::Easy

A role to build HTTP daemon classes with.
This provides the framework for parsing HTTP connections.

## HTTP::Easy::PSGI

A class implementing HTTP::Easy. This builds a PSGI environment, and passes 
it onto a handler. The handler must return a PSGI response:

```perl
  [ $status, @headers, @body ]
```

This can be used as an engine in the [Web::App](https://github.com/supernovus/perl6-web/) library.

## Example

```perl

  use HTTP::Easy::PSGI;
  my $http = HTTP::Easy::PSGI.new(:port(8080));
  
  my $app = sub (%env)
  {
    my $name = %env<QUERY_STRING> || "World";
    return [ 200, [ 'Content-Type' => 'text/plain' ], [ "Hello $name" ] ];
  }

  $http.handle($app);

```

## Requirements

 * HTTP::Status

## TODO

 * Implement HTTP/1.1 features such as Transfer-Encoding, etc.

## Author

Timothy Totten, supernovus on #perl6, https://github.com/supernovus/

## License

Artistic License 2.0


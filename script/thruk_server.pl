#!/usr/bin/env perl

use strict;
use warnings;

###################################################
# create connection pool
# has to be done really early to save memory
use lib 'lib';
BEGIN {
    $ENV{'THRUK_SRC'} = 'DebugServer';
    # won't work with automatical restarts
    if(!grep {/^\-r/} @ARGV) {
        require Thruk::Backend::Pool;
        Thruk::Backend::Pool::init_backend_thread_pool()
    } else {
        @ARGV = grep {!/^\-r/} @ARGV;
        push @ARGV, '-w', 'lib';
        for my $plugin (glob('plugins/plugins-enabled/*/lib')) {
            push @ARGV, '-w', $plugin;
        }
        push @ARGV, '-w', 'script/';
        push @ARGV, '-w', 'thruk_local.conf';
        push @ARGV, '-w', 'thruk.conf';
        exec("morbo", $0, @ARGV) or die("cannot run $0 with morbo: $!");
        exit;
    }
}

###################################################
require Mojolicious::Commands;
Mojolicious::Commands->start_app('Thruk', 'daemon');

=head1 NAME

thruk_server.pl - Thruk Development Server

=head1 SYNOPSIS

thruk_server.pl [options]

   -d --debug           force debug mode
   -? --help            display this help and exits
   -r --restart         restart when files get modified
   --follow_symlinks    follow symlinks in search directories

=head1 DESCRIPTION

Run a Thruk Testserver.

=head1 AUTHORS

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

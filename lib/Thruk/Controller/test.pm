package Thruk::Controller::test;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

=head1 NAME

Thruk::Controller::test - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################
sub index {
    my ( $c ) = @_;

    Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_DEFAULTS);

    if(   (!defined $ENV{'THRUK_SRC'} or ($ENV{'THRUK_SRC'} ne 'TEST_LEAK' and $ENV{'THRUK_SRC'} ne 'TEST'))
       and !$c->config->{'thruk_debug'}) {
        die("test.cgi is disabled unless in test mode!");
    }

    $c->stash->{'_template'} = 'main.tt';

    my $action = $c->{'request'}->{'parameters'}->{'action'} || '';

    if($action eq 'leak') {
        my $leak = Thruk::Backend::Manager->new();
        $leak->{'test'} = $leak;
        $c->stash->{ctx} = $c;
    }

    return 1;
}

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

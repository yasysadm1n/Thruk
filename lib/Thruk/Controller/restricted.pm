package Thruk::Controller::restricted;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

=head1 NAME

Thruk::Controller::restricted - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 index

=cut
sub index {
    my ( $c ) = @_;

    $c->res->headers->content_type('text/plain');
    $c->stash->{'_template'} = 'passthrough.tt';
    $c->stash->{'_text'}     = 'FAIL';

    unless ($c->user_exists) {
        return 1 unless ($c->authenticate( {} ));
    }
    $c->stash->{'_text'} = 'OK: '.$c->user() if $c->user_exists;

    return 1;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

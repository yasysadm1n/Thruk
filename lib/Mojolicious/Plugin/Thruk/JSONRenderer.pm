package Mojolicious::Plugin::Thruk::JSONRenderer;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Plugin';
use Carp qw/confess/;
use JSON::XS ();

=head1 METHODS

=head2 register

    register this renderer

=cut
sub register {
    my($self, $app) = @_;
    my $encoder = JSON::XS->new
                          ->ascii
                          ->pretty
                          ->allow_blessed
                          ->allow_nonref;
    $app->renderer->add_handler('json' => sub {
        #my($renderer, $controller, $output, $options) = @_;
        if(!$_[3]->{'json'}) {
            $app->renderer->default_handler('ep');
            confess("no json data set!");
        }
        ${$_[2]} = $encoder->encode($_[3]->{'json'});
        return $_[2];
    });

    $app->helper(
        'render_json' => sub {
            shift->render( 'handler' => 'json', @_ );
        }
    );

    return;
}

1;
__END__

=head1 SYNOPSIS

    # Mojolicious
    $self->plugin('JSONRenderer', {}, );
    $self->render_json(json => ...);

=head1 DESCRIPTION

This module is a Mojolicious plugin for easy use of L<JSON::XS> data. It
adds a "json" handler and provides a "render_json" helper method.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Plugin>, L<JSON::XS>.

=cut

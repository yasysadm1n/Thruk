package Mojolicious::Plugin::Thruk::GDRenderer;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Plugin';
use Carp qw/confess/;

=head1 METHODS

=head2 register

    register this renderer

=cut
sub register {
    my($self, $app) = @_;
# TODO: implement
    #my $encoder = JSON::XS->new
    #                      ->ascii
    #                      ->pretty
    #                      ->allow_blessed
    #                      ->allow_nonref;
    $app->renderer->add_handler('gd' => sub {
        #my($renderer, $controller, $output, $options) = @_;
        #if(!$_[3]->{'json'}) {
        #    $app->renderer->default_handler('ep');
        #    confess("no json data set!");
        #}
        #${$_[2]} = $encoder->encode($_[3]->{'json'});
        return $_[2];
    });

    $app->helper(
        'render_gd' => sub {
            shift->render( 'handler' => 'gd', @_ );
        }
    );

    return;
}

1;
__END__

=head1 SYNOPSIS

    # Mojolicious
    $self->plugin('GDRenderer', {}, );
    $self->render_gd(gd => ...);

=head1 DESCRIPTION

This module is a Mojolicious plugin for easy use of L<GD> data. It
adds a "gd" handler and provides a "render_gd" helper method.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Plugin>, L<GD>.

=cut
